import Foundation
import AVFoundation
import Accelerate

class AudioProcessingService {
    struct Beat {
        let timestamp: Double
        let intensity: Double
    }
    
    enum AudioProcessingError: Error {
        case invalidAudio
        case processingError(String)
    }
    
    func analyzeAudio(url: URL) async throws -> (beats: [Beat], mood: VideoMood) {
        let asset = AVAsset(url: url)
        guard let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioProcessingError.invalidAudio
        }
        
        // Extract audio samples
        let samples = try await extractAudioSamples(from: audioTrack)
        
        // Detect beats
        let beats = try detectBeats(in: samples)
        
        // Analyze mood
        let mood = try analyzeMood(samples: samples, beats: beats)
        
        return (beats: beats, mood: mood)
    }
    
    private func extractAudioSamples(from track: AVAssetTrack) async throws -> [Float] {
        let reader = try AVAssetReader(asset: track.asset!)
        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        
        reader.add(output)
        reader.startReading()
        
        var samples = [Float]()
        while let buffer = output.copyNextSampleBuffer() {
            var bufferList = AudioBufferList()
            var blockBuffer: CMBlockBuffer?
            
            let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                buffer,
                bufferListSizeNeededOut: nil,
                bufferListOut: &bufferList,
                bufferListSize: MemoryLayout<AudioBufferList>.size,
                blockBufferAllocator: nil,
                blockBufferMemoryAllocator: nil,
                flags: 0,
                blockBufferOut: &blockBuffer
            )
            
            guard status == noErr else {
                throw AudioProcessingError.processingError("Failed to get audio buffer: \(status)")
            }
            
            let numSamples = CMSampleBufferGetNumSamples(buffer)
            let ptr = UnsafeBufferPointer<Float>(
                start: bufferList.mBuffers.mData?.assumingMemoryBound(to: Float.self),
                count: numSamples
            )
            samples.append(contentsOf: ptr)
        }
        
        return samples
    }
    
    // Made public so it can be called from VideoEditingService
    public func detectBeats(in samples: [Float]) throws -> [Beat] {
        var beats = [Beat]()
        let windowSize = 1024
        let hopSize = 512
        
        // Calculate energy in each window
        for i in stride(from: 0, to: samples.count - windowSize, by: hopSize) {
            let window = Array(samples[i..<i+windowSize])
            var energy: Float = 0
            vDSP_measqv(window, 1, &energy, vDSP_Length(windowSize))
            
            // Detect sudden increases in energy (beats)
            if energy > 0.1 { // Threshold can be adjusted
                let timestamp = Double(i) / 44100.0 // Assuming 44.1kHz sample rate
                let intensity = Double(energy)
                beats.append(Beat(timestamp: timestamp, intensity: intensity))
            }
        }
        
        return beats
    }
    
    private func analyzeMood(samples: [Float], beats: [Beat]) throws -> VideoMood {
        // Calculate various audio features
        let energy = calculateEnergy(samples)
        let tempo = Double(beats.count) / (Double(samples.count) / 44100.0) // beats per second
        let rhythmRegularity = calculateRhythmRegularity(beats)
        
        // Determine mood based on audio features
        if energy > 0.8 && tempo > 120 {
            return .energetic
        } else if energy < 0.3 && rhythmRegularity < 0.5 {
            return .emotional
        } else if energy > 0.6 && rhythmRegularity > 0.8 {
            return .tense
        } else if energy < 0.4 && rhythmRegularity > 0.7 {
            return .calm
        } else {
            return .neutral
        }
    }
    
    private func calculateEnergy(_ samples: [Float]) -> Double {
        var energy: Float = 0
        vDSP_measqv(samples, 1, &energy, vDSP_Length(samples.count))
        return Double(energy) / Double(samples.count)
    }
    
    private func calculateRhythmRegularity(_ beats: [Beat]) -> Double {
        guard beats.count > 1 else { return 0.0 }
        
        // Calculate intervals between beats
        let intervals = zip(beats, beats.dropFirst()).map { $1.timestamp - $0.timestamp }
        
        // Calculate standard deviation of intervals
        let mean = intervals.reduce(0.0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(intervals.count)
        let stdDev = sqrt(variance)
        
        // Convert to regularity score (0-1)
        let maxStdDev = 0.5 // Maximum expected standard deviation
        return 1.0 - min(stdDev / maxStdDev, 1.0)
    }
} 