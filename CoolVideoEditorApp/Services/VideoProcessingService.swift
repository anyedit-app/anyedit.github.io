@preconcurrency import AVFoundation
import CoreImage
import CoreML
import Vision

@preconcurrency import Foundation

@globalActor actor VideoProcessingActor {
    static let shared = VideoProcessingActor()
}

@VideoProcessingActor
class VideoProcessingService: @unchecked Sendable {
    func processVideo(
        inputURL: URL,
        outputURL: URL,
        effect: any AIEffect,
        aiEngine: AIEngineService,
        progressUpdate: @escaping (Double) -> Void
    ) async throws {
        let asset = AVAsset(url: inputURL)
        let duration = try await asset.load(.duration)
        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Configure video input/output
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first!
        let videoReaderOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        reader.add(videoReaderOutput)
        
        let videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: try await videoTrack.load(.naturalSize).width,
                AVVideoHeightKey: try await videoTrack.load(.naturalSize).height
            ]
        )
        writer.add(videoWriterInput)
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(try await videoTrack.load(.naturalSize).width),
                kCVPixelBufferHeightKey as String: Int(try await videoTrack.load(.naturalSize).height)
            ]
        )
        
        // Start reading/writing
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        while let sampleBuffer = videoReaderOutput.copyNextSampleBuffer() {
            if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                let ciImage = CIImage(cvPixelBuffer: imageBuffer)
                
                // Process frame with AI effect
                let processedImage = try await effect.process(image: ciImage)
                
                // Convert back to pixel buffer
                let processedBuffer = try await aiEngine.convertToPixelBuffer(processedImage)
                let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                while !videoWriterInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                
                pixelBufferAdaptor.append(processedBuffer, withPresentationTime: presentationTime)
                
                let progress = CMTimeGetSeconds(presentationTime) / CMTimeGetSeconds(duration)
                progressUpdate(progress)
            }
        }
        
        // Finish writing
        videoWriterInput.markAsFinished()
        await writer.finishWriting()
        reader.cancelReading()
    }
}

// Helper actor to manage processed frames count
actor ProcessedFramesActor {
    private var processedFrames: Double = 0
    
    func increment() {
        processedFrames += 1
    }
    
    func getProgress(totalFrames: Double) -> Double {
        return processedFrames / totalFrames
    }
} 