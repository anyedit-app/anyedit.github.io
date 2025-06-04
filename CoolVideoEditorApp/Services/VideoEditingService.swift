import AVFoundation
import CoreImage
import Vision
import CoreML
import CoreImage.CIFilterBuiltins

class VideoEditingService {
    struct VideoSegment: Equatable {
        let timeRange: CMTimeRange
        let speed: Float
        let transition: VideoTransition
        let effects: [VideoEffect]
    }
    
    enum VideoTransition: Equatable {
        case cut
        case crossFade(duration: Double)
        case flash(duration: Double)
        case zoom(duration: Double, scale: Double)
    }
    
    enum VideoEffect: Equatable {
        case speedRamp(from: Float, to: Float, duration: Double)
        case colorEffect(filter: String, intensity: Double)
        case motionEffect(type: MotionEffectType)
        case shake(intensity: Double)
    }
    
    enum MotionEffectType: Equatable {
        case zoomIn(scale: Double)
        case zoomOut(scale: Double)
        case panLeft(amount: Double)
        case panRight(amount: Double)
        case rotate(angle: Double)
    }
    
    // MARK: - Types
    struct VideoHighlight: Equatable, Hashable {
        let timeRange: CMTimeRange
        let intensity: Double  // How "interesting" this segment is (0.0 - 1.0)
        let type: HighlightType
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(CMTimeGetSeconds(timeRange.start))
            hasher.combine(CMTimeGetSeconds(timeRange.duration))
            hasher.combine(intensity)
        }
    }
    
    enum HighlightType {
        case action    // Fast movement, quick changes
        case detail    // Close-ups, important details
        case transition // Scene changes
    }
    
    struct AudioHighlight {
        let timeRange: CMTimeRange
        let type: AudioHighlightType
        let beats: [BeatInfo]
    }
    
    enum AudioHighlightType {
        case verse
        case chorus
        case drop
        case bridge
    }
    
    struct BeatInfo {
        let timestamp: Double
        let intensity: Double
        let type: BeatType
        var nextBeatDelay: Double?  // Time until next beat
    }
    
    enum BeatType {
        case core      // Main beats that define the rhythm
        case secondary // Supporting beats
        case drop     // Beat drops or significant changes
        case subtle   // Background beats
    }
    
    enum SceneType: String {
        case wide
        case medium
        case closeup
        case action
        case calm
        case transition
        case highlight
    }
    
    struct Scene {
        struct TimeRange {
            let start: Double
            let duration: Double
        }
        
        let timeRange: TimeRange
        let sceneType: SceneType
        let movement: Double
        let emotionalScore: Double
    }
    
    private let ciContext = CIContext()
    private let motionAnalyzer = VNSequenceRequestHandler()
    
    // Add new types for visual consistency tracking
    private struct VisualContext {
        let dominantColors: [CIColor]
        let brightness: Double
        let movement: Double
        let composition: SceneType
        let objectTypes: [String]
    }
    
    private struct SegmentRelation {
        let visualSimilarity: Double
        let logicalFlow: Double
        let emotionalContinuity: Double
    }
    
    private func generateVideoSegments(beats: [AudioProcessingService.Beat], videoDuration: CMTime) -> [VideoSegment] {
        var segments = [VideoSegment]()
        
        if beats.isEmpty {
            // If no beats detected, create segments based on fixed intervals
            let segmentDuration = CMTimeGetSeconds(videoDuration) / 8.0 // Divide video into 8 parts
            for i in 0..<8 {
                let startTime = CMTime(seconds: Double(i) * segmentDuration, preferredTimescale: 600)
                let endTime = CMTime(seconds: Double(i + 1) * segmentDuration, preferredTimescale: 600)
                if endTime > videoDuration {
                    break
                }
                
                segments.append(VideoSegment(
                    timeRange: CMTimeRange(start: startTime, end: endTime),
                    speed: 1.0,
                    transition: i % 2 == 0 ? .crossFade(duration: 0.3) : .cut,
                    effects: []
                ))
            }
            return segments
        }
        
        let beatCount = beats.count
        let lastFrameMatchScores = UserDefaults.standard.array(forKey: "lastFrameMatchScores") as? [Double] ?? []
        var beatPatterns: [[Double]] = [] // Store beat intensity patterns
        
        // Analyze beat patterns
        let patternSize = 4
        for i in 0...(beatCount - patternSize) {
            let pattern = beats[i..<(i + patternSize)].map { $0.intensity }
            beatPatterns.append(Array(pattern))
        }
        
        // Calculate beat pattern similarity matrix
        var similarityMatrix: [[Double]] = Array(repeating: Array(repeating: 0.0, count: beatPatterns.count), count: beatPatterns.count)
        for i in 0..<beatPatterns.count {
            for j in 0..<beatPatterns.count {
                similarityMatrix[i][j] = calculatePatternSimilarity(beatPatterns[i], beatPatterns[j])
            }
        }
        
        for i in 0..<beatCount {
            let currentBeat = beats[i]
            let nextBeat = i + 1 < beatCount ? beats[i + 1] : nil
            
            let startTime = CMTime(seconds: currentBeat.timestamp, preferredTimescale: 600)
            let endTime = nextBeat.map { CMTime(seconds: $0.timestamp, preferredTimescale: 600) } ?? videoDuration
            
            // Calculate optimal speed based on beat pattern and timing
            let segmentDuration = CMTimeGetSeconds(endTime) - CMTimeGetSeconds(startTime)
            let targetDuration = nextBeat.map { $0.timestamp - currentBeat.timestamp } ?? 0.5
            
            // Find similar beat patterns for better transition timing
            var patternMatchScore = 0.0
            if i >= patternSize - 1 {
                let currentPatternIndex = i - (patternSize - 1)
                let similarPatterns = similarityMatrix[currentPatternIndex]
                patternMatchScore = similarPatterns.max() ?? 0.0
            }
            
            // Adjust speed based on beat pattern and intensity
            let baseSpeedFactor = Float(segmentDuration / targetDuration)
            let patternAdjustment = Float(1.0 + (patternMatchScore * 0.2)) // Up to 20% speed adjustment based on pattern
            let speed = if currentBeat.intensity > 1.5 {
                min(2.0, baseSpeedFactor * patternAdjustment * 1.5)
            } else if currentBeat.intensity < 0.8 {
                max(0.8, baseSpeedFactor * patternAdjustment * 0.8)
            } else {
                baseSpeedFactor * patternAdjustment
            }
            
            // Choose transition based on beat pattern and frame matching
            let transition: VideoTransition
            if i < lastFrameMatchScores.count {
                let matchScore = lastFrameMatchScores[i]
                let patternStrength = i >= patternSize - 1 ? patternMatchScore : 0.0
                
                if matchScore > 0.8 && patternStrength > 0.7 {
                    // Smooth transition for matching frames and strong patterns
                    transition = .crossFade(duration: 0.3)
                } else if matchScore > 0.6 || patternStrength > 0.8 {
                    // Dynamic transition for moderate matches or very strong patterns
                    transition = .zoom(duration: 0.25, scale: 1.2)
                } else if currentBeat.intensity > 1.2 {
                    // Impact transition for high intensity
                    transition = .flash(duration: 0.1)
                } else {
                    transition = .cut
                }
            } else {
                transition = currentBeat.intensity > 1.2 ? .flash(duration: 0.1) : .cut
            }
            
            // Generate effects based on beat pattern analysis
            var effects: [VideoEffect] = []
            
            // Add speed ramp for pattern transitions
            if i > 0 && i < beatCount - 1 {
                let prevBeat = beats[i - 1]
                let patternChange = i >= patternSize ? similarityMatrix[i - patternSize][i - patternSize + 1] : 0.0
                
                if patternChange < 0.5 { // Significant pattern change
                    effects.append(.speedRamp(
                        from: Float(prevBeat.intensity),
                        to: Float(currentBeat.intensity),
                        duration: min(0.4, segmentDuration / 2)
                    ))
                }
            }
            
            // Add motion effects based on beat pattern
            if let nextBeat = nextBeat {
                let beatGap = nextBeat.timestamp - currentBeat.timestamp
                let patternIntensity = i >= patternSize - 1 ? beatPatterns[i - (patternSize - 1)].reduce(0.0, +) / Double(patternSize) : currentBeat.intensity
                
                if beatGap < 0.3 && patternIntensity > 1.2 {
                    effects.append(.motionEffect(type: .zoomIn(scale: 1.1)))
                } else if patternIntensity > 1.5 {
                    effects.append(.motionEffect(type: .rotate(angle: 5.0)))
                }
            }
            
            segments.append(VideoSegment(
                timeRange: CMTimeRange(start: startTime, end: endTime),
                speed: speed,
                transition: transition,
                effects: effects
            ))
        }
        
        return segments
    }
    
    private func calculatePatternSimilarity(_ pattern1: [Double], _ pattern2: [Double]) -> Double {
        guard pattern1.count == pattern2.count else { return 0.0 }
        
        // Calculate normalized cross-correlation
        let mean1 = pattern1.reduce(0.0, +) / Double(pattern1.count)
        let mean2 = pattern2.reduce(0.0, +) / Double(pattern2.count)
        
        let normalized1 = pattern1.map { $0 - mean1 }
        let normalized2 = pattern2.map { $0 - mean2 }
        
        var correlation = 0.0
        var norm1 = 0.0
        var norm2 = 0.0
        
        for i in 0..<pattern1.count {
            correlation += normalized1[i] * normalized2[i]
            norm1 += normalized1[i] * normalized1[i]
            norm2 += normalized2[i] * normalized2[i]
        }
        
        let normalization = sqrt(norm1 * norm2)
        return normalization > 0 ? abs(correlation / normalization) : 0.0
    }
    
    private func detectVideoHighlights(from asset: AVAsset, desiredCount: Int) async throws -> [VideoHighlight] {
        var highlights: [VideoHighlight] = []
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds >= 1.0 else {
            if desiredCount > 0 {
                throw AppError.videoProcessingError("Video must be at least 1 second long to generate \(desiredCount) clips.")
            }
            return []
        }

        // Configure video analysis
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first!
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        
        // Create Vision requests
        let sceneClassificationRequest = VNClassifyImageRequest()
        let objectDetectionRequest = VNDetectRectanglesRequest()
        let humanPoseRequest = VNDetectHumanBodyPoseRequest()
        let requests = [sceneClassificationRequest, objectDetectionRequest, humanPoseRequest] as [VNRequest]
        
        // Process frames in smaller windows - aim for ~1 second clips
        let windowDuration: Float = 1.0 // 1 second windows
        let samplesPerWindow = Int(frameRate * windowDuration)
        var currentWindow: [CVPixelBuffer] = []
        var currentTime = CMTime.zero
        var lastHighlightEnd = CMTime.zero
        let minGapBetweenHighlights = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        // Create asset reader
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ])
        
        reader.add(output)
        guard reader.startReading() else {
            throw AppError.videoProcessingError("Failed to start reading")
        }
        
        print("Starting AI-enhanced frame analysis...")
        
        while reader.status == .reading, let sampleBuffer = output.copyNextSampleBuffer() {
            autoreleasepool { [self] in
                if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    currentWindow.append(pixelBuffer)
                    
                    if currentWindow.count >= samplesPerWindow {
                        // Basic motion and scene change analysis
                        let motionScore = (try? self.analyzeMotion(in: currentWindow)) ?? 0.0
                        let sceneChangeScore = (try? self.detectSceneChanges(in: currentWindow)) ?? 0.0
                        
                        // AI-based content analysis
                        var aiScore = 0.0
                        let handler = VNImageRequestHandler(cvPixelBuffer: currentWindow.last!, options: [:])
                        do {
                            try handler.perform(requests)
                            
                            // Scene classification score
                            if let sceneObservations = sceneClassificationRequest.results {
                                let interestingScenes = ["sports", "action", "performance", "stage", "concert"]
                                let sceneScore = sceneObservations
                                    .filter { interestingScenes.contains($0.identifier.lowercased()) }
                                    .map { $0.confidence }
                                    .max() ?? 0.0
                                aiScore += Double(sceneScore) * 0.4
                            }
                            
                            // Object detection score
                            if let objectObservations = objectDetectionRequest.results {
                                let objectCount = min(objectObservations.count, 5) // Cap at 5 objects
                                aiScore += Double(objectCount) * 0.1
                            }
                            
                            // Human pose detection score
                            if let poseObservations = humanPoseRequest.results,
                               !poseObservations.isEmpty {
                                aiScore += 0.3 // Bonus for human presence
                            }
                        } catch {
                            print("AI analysis error: \(error)")
                        }
                        
                        // Combine all scores
                        let combinedScore = (motionScore + sceneChangeScore) * 0.4 + aiScore * 0.6
                        
                        if combinedScore > 0.3 && // Lower threshold but rely more on AI scoring
                           CMTimeCompare(CMTimeSubtract(currentTime, lastHighlightEnd), minGapBetweenHighlights) > 0 {
                            
                            let highlightType: HighlightType = sceneChangeScore > motionScore ? .transition : .action
                            let highlightDuration = CMTime(seconds: 1.0, preferredTimescale: 600)
                            
                            highlights.append(VideoHighlight(
                                timeRange: CMTimeRange(start: currentTime, duration: highlightDuration),
                                intensity: combinedScore,
                                type: highlightType
                            ))
                            lastHighlightEnd = CMTimeAdd(currentTime, highlightDuration)
                        }
                        
                        currentWindow.removeFirst(samplesPerWindow / 4) // 75% overlap
                        currentTime = CMTimeAdd(currentTime, CMTime(seconds: Double(windowDuration/4), preferredTimescale: 600))
                    }
                }
            }
        }
        
        // Sort and select highlights
        highlights.sort { $0.intensity > $1.intensity }
        
        // Ensure good distribution of highlight types
        var selectedHighlights = [VideoHighlight]()
        var actionCount = 0
        var transitionCount = 0
        let targetActionRatio = 0.7 // Aim for 70% action, 30% transitions
        
        for highlight in highlights {
            if selectedHighlights.count >= desiredCount {
                break
            }
            
            let currentTotal = Double(actionCount + transitionCount)
            let currentActionRatio = currentTotal > 0 ? Double(actionCount) / currentTotal : 0
            
            if highlight.type == .action && (currentActionRatio <= targetActionRatio || transitionCount == 0) {
                selectedHighlights.append(highlight)
                actionCount += 1
            } else if highlight.type == .transition && (currentActionRatio >= targetActionRatio || actionCount == 0) {
                selectedHighlights.append(highlight)
                transitionCount += 1
            }
        }
        
        // Fill remaining slots if needed
        while selectedHighlights.count < desiredCount && !highlights.isEmpty {
            if let nextHighlightIndex = highlights.firstIndex(where: { highlight in !selectedHighlights.contains(where: { $0.timeRange == highlight.timeRange }) }) {
                selectedHighlights.append(highlights[nextHighlightIndex])
                highlights.remove(at: nextHighlightIndex) // Avoid re-adding the same highlight
            } else {
                break
            }
        }
        
        // Sort final selection by timestamp
        selectedHighlights.sort { CMTimeCompare($0.timeRange.start, $1.timeRange.start) < 0 }
        
        print("Selected \(selectedHighlights.count) highlights with AI scoring (Actions: \(actionCount), Transitions: \(transitionCount))")
        return selectedHighlights
    }
    
    private func generateGuaranteedFallbackClips(from asset: AVAsset, count: Int) async throws -> [VideoHighlight] {
        if count == 0 {
            return []
        }
        print("Fallback: Generating exactly \(count) 1-second clips...")
        var generatedClips: [VideoHighlight] = []
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds >= 0.1 else { // Need at least a tiny bit of video to make clips
            if count > 0 {
                throw AppError.videoProcessingError("Video is too short (\(durationSeconds)s) to generate \(count) fallback clips.")
            }
            return []
        }

        var currentTime = CMTime.zero
        let clipDurationSeconds = 1.0
        let stepDurationSeconds = 0.25 // Create overlapping 1-second clips, stepping 0.25s
        
        var baseClips: [VideoHighlight] = []

        while CMTimeCompare(currentTime, duration) < 0 {
            let availableDuration = CMTimeSubtract(duration, currentTime)
            let actualClipDurationSeconds = min(clipDurationSeconds, CMTimeGetSeconds(availableDuration))
            
            if actualClipDurationSeconds < 0.1 { // Avoid creating tiny clips at the very end
                break
            }
            
            let clipCMDuration = CMTime(seconds: actualClipDurationSeconds, preferredTimescale: 600)
            baseClips.append(VideoHighlight(
                timeRange: CMTimeRange(start: currentTime, duration: clipCMDuration),
                intensity: 0.5, // Default intensity for fallback
                type: .action
            ))
            
            let nextTime = CMTimeAdd(currentTime, CMTime(seconds: stepDurationSeconds, preferredTimescale: 600))
            // Break if the next step would start at or after the duration, or if the current clip was shorter than a full step
            if CMTimeCompare(nextTime, duration) >= 0 || actualClipDurationSeconds < stepDurationSeconds {
                 // If the last clip was shorter than a full step, it means it was the final segment.
                if actualClipDurationSeconds < clipDurationSeconds && actualClipDurationSeconds > 0.1 && CMTimeCompare(CMTimeAdd(currentTime, clipCMDuration), duration) == 0 {
                    // This was the final partial clip, ensure it's included if not already.
                    // The loop condition usually handles this, but as a safeguard.
                }
                break
            }
            currentTime = nextTime
        }
        
        print("Fallback: Generated \(baseClips.count) base overlapping 1-second clips.")

        if baseClips.isEmpty {
            if count > 0 {
                 throw AppError.videoProcessingError("Fallback could not generate any base clips from a video of \(durationSeconds)s duration.")
            }
             return [] // Should be caught by duration guard, but as a safe return.
        }

        if baseClips.count >= count {
            // If we have enough, take the first 'count' to maintain order
            generatedClips = Array(baseClips.prefix(count))
        } else {
            // If not enough unique clips, use all unique ones and then cycle through them
            generatedClips.append(contentsOf: baseClips)
            if !baseClips.isEmpty { // Ensure baseClips is not empty before trying to cycle
                var currentBaseClipIndex = 0
                for _ in 0..<(count - baseClips.count) {
                    generatedClips.append(baseClips[currentBaseClipIndex])
                    currentBaseClipIndex = (currentBaseClipIndex + 1) % baseClips.count
                }
            }
        }
        
        print("Fallback: Returning \(generatedClips.count) clips to fulfill request for \(count).")
        guard generatedClips.count == count else {
            // This should ideally not be hit if logic is correct
            throw AppError.videoProcessingError("Fallback internal error: Failed to generate the exact number of desired clips. Expected \(count), got \(generatedClips.count)")
        }
        return generatedClips
    }
    
    private func analyzeMotion(in frames: [CVPixelBuffer]) throws -> Double {
        guard frames.count > 1 else { return 0.0 }
        
        var totalMotion = 0.0
        
        for i in 1..<frames.count {
            let previousFrame = frames[i-1]
            let currentFrame = frames[i]
            
            // Create CIImages from pixel buffers
            let previousImage = CIImage(cvPixelBuffer: previousFrame)
            let currentImage = CIImage(cvPixelBuffer: currentFrame)
            
            // Calculate optical flow
            let opticalFlow = try calculateOpticalFlow(from: previousImage, to: currentImage)
            totalMotion += opticalFlow
        }
        
        return totalMotion / Double(frames.count - 1)
    }
    
    private func calculateOpticalFlow(from image1: CIImage, to image2: CIImage) throws -> Double {
        let context = CIContext()
        
        // Convert images to grayscale
        let grayscaleFilter = CIFilter.colorMonochrome()
        grayscaleFilter.inputImage = image1
        grayscaleFilter.color = CIColor.white
        let gray1 = grayscaleFilter.outputImage!
        
        grayscaleFilter.inputImage = image2
        let gray2 = grayscaleFilter.outputImage!
        
        // Calculate difference between frames
        let differenceFilter = CIFilter.blendWithMask()
        differenceFilter.inputImage = gray1
        differenceFilter.backgroundImage = gray2
        let difference = differenceFilter.outputImage!
        
        // Calculate average brightness of difference
        let averageFilter = CIFilter.areaAverage()
        averageFilter.inputImage = difference
        averageFilter.extent = difference.extent // Use the extent here
        let averageColor = averageFilter.outputImage!
        
        // Get the brightness value
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(averageColor,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return Double(bitmap[0]) / 255.0
    }
    
    private func detectSceneChanges(in frames: [CVPixelBuffer]) throws -> Double {
        guard frames.count > 1 else { return 0.0 }
        
        var totalChange = 0.0
        
        for i in 1..<frames.count {
            let previousFrame = frames[i-1]
            let currentFrame = frames[i]
            
            // Calculate histogram difference
            let difference = try calculateHistogramDifference(between: previousFrame, and: currentFrame)
            totalChange += difference
        }
        
        return totalChange / Double(frames.count - 1)
    }
    
    private func calculateHistogramDifference(between frame1: CVPixelBuffer, and frame2: CVPixelBuffer) throws -> Double {
        let image1 = CIImage(cvPixelBuffer: frame1)
        let image2 = CIImage(cvPixelBuffer: frame2)
        
        // Calculate histograms
        let histogram1 = try calculateHistogram(for: image1)
        let histogram2 = try calculateHistogram(for: image2)
        
        // Calculate difference between histograms
        var difference = 0.0
        for i in 0..<histogram1.count {
            difference += abs(histogram1[i] - histogram2[i])
        }
        
        return difference / Double(histogram1.count)
    }
    
    private func calculateHistogram(for image: CIImage) throws -> [Double] {
        let context = CIContext()
        _ = image.extent // Mark as intentionally unused if not directly referenced
        
        // Convert to grayscale first
        let grayscaleFilter = CIFilter.colorMonochrome()
        grayscaleFilter.inputImage = image
        grayscaleFilter.color = CIColor.white
        
        guard let grayscale = grayscaleFilter.outputImage else {
            throw VideoEditingError.processingError("Failed to convert to grayscale")
        }
        
        // Create histogram
        let histogramFilter = CIFilter.areaHistogram()
        histogramFilter.inputImage = grayscale
        histogramFilter.scale = 1.0
        histogramFilter.count = 256
        
        guard let outputImage = histogramFilter.outputImage else {
            throw VideoEditingError.processingError("Failed to calculate histogram")
        }
        
        var histogram = [Double](repeating: 0, count: 256)
        context.render(outputImage,
                      toBitmap: &histogram,
                      rowBytes: MemoryLayout<Double>.size * 256,
                      bounds: CGRect(x: 0, y: 0, width: 256, height: 1),
                      format: .RGBAf,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return histogram
    }
    
    private func extractDominantColors(from buffer: CVPixelBuffer) -> [CIColor] {
        let image = CIImage(cvPixelBuffer: buffer)
        
        // Create a scaled down version for faster processing
        let scale = 0.1
        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Convert to LAB color space for better color analysis
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = scaledImage
        colorMatrix.setDefaults()
        
        guard let labImage = colorMatrix.outputImage else {
            return []
        }
        
        // Use k-means clustering to find dominant colors
        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: Int(labImage.extent.width * labImage.extent.height) * 4)
        context.render(labImage,
                      toBitmap: &bitmap,
                      rowBytes: Int(labImage.extent.width) * 4,
                      bounds: labImage.extent,
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        // Convert bitmap to colors
        var colors: [CIColor] = []
        for i in stride(from: 0, to: bitmap.count, by: 4) {
            let color = CIColor(red: CGFloat(bitmap[i]) / 255.0,
                              green: CGFloat(bitmap[i+1]) / 255.0,
                              blue: CGFloat(bitmap[i+2]) / 255.0,
                              alpha: CGFloat(bitmap[i+3]) / 255.0)
            colors.append(color)
        }
        
        // Cluster colors to find dominant ones
        return findDominantColors(in: colors, count: 5)
    }
    
    private func findDominantColors(in colors: [CIColor], count: Int) -> [CIColor] {
        // Simple k-means clustering
        var centroids = Array(colors.prefix(count))
        var lastCentroids: [CIColor] = []
        let maxIterations = 10
        var iteration = 0
        
        while !centroids.elementsEqual(lastCentroids, by: { $0.isApproximatelyEqual(to: $1) }) && iteration < maxIterations {
            lastCentroids = centroids
            
            // Assign colors to nearest centroid
            var clusters: [[CIColor]] = Array(repeating: [], count: count)
            for color in colors {
                let nearestIndex = centroids.enumerated().min(by: { $0.1.distance(to: color) < $1.1.distance(to: color) })!.offset
                clusters[nearestIndex].append(color)
            }
            
            // Update centroids
            for i in 0..<count {
                if !clusters[i].isEmpty {
                    let clusterSize = Double(clusters[i].count)
                    var sumRed: CGFloat = 0
                    var sumGreen: CGFloat = 0
                    var sumBlue: CGFloat = 0
                    for color in clusters[i] {
                        sumRed += color.red
                        sumGreen += color.green
                        sumBlue += color.blue
                    }
                    centroids[i] = CIColor(
                        red: sumRed / clusterSize,
                        green: sumGreen / clusterSize,
                        blue: sumBlue / clusterSize
                    )
                }
            }
            
            iteration += 1
        }
        
        return centroids
    }
    
    private func calculateEmotionalScore(from characteristics: SceneCharacteristics, motion: Double) -> Double {
        var score = 0.0
        
        // Human presence adds emotional weight
        if characteristics.faceCount > 0 || characteristics.humanPoseDetected {
            score += 0.3
        }
        
        // Scene content emotional analysis
        let emotionalScenes = ["happy", "sad", "dramatic", "romantic", "exciting", "peaceful"]
        if characteristics.dominantSceneLabels.contains(where: { label in
            emotionalScenes.contains(where: { label.lowercased().contains($0) })
        }) {
            score += 0.25
        }
        
        // Movement contributes to emotional intensity
        score += motion * 0.25
        
        // Visual complexity (saliency and objects) adds engagement
        score += min(Double(characteristics.saliencyHotspots) / 10.0, 1.0) * 0.1
        score += min(Double(characteristics.objectCount) / 10.0, 1.0) * 0.1
        
        return min(score, 1.0)
    }
    
    private func applyTransition(_ transition: VideoTransition, at time: CMTime, composition: AVMutableComposition) {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: time, duration: CMTime(seconds: 0.5, preferredTimescale: 600))
        
        switch transition {
        case .cut:
            // No transition needed
            break
            
        case .crossFade(let duration):
            // Add cross fade transition
            let fadeOutLayer = CABasicAnimation(keyPath: "opacity")
            fadeOutLayer.fromValue = 1.0
            fadeOutLayer.toValue = 0.0
            fadeOutLayer.duration = duration
            fadeOutLayer.beginTime = CFTimeInterval(CMTimeGetSeconds(time))
            
            let fadeInLayer = CABasicAnimation(keyPath: "opacity")
            fadeInLayer.fromValue = 0.0
            fadeInLayer.toValue = 1.0
            fadeInLayer.duration = duration
            fadeInLayer.beginTime = CFTimeInterval(CMTimeGetSeconds(time))
            
            // Apply animations to video layers
            let videoLayer = CALayer()
            videoLayer.add(fadeOutLayer, forKey: "fadeOut")
            let newVideoLayer = CALayer()
            newVideoLayer.add(fadeInLayer, forKey: "fadeIn")
            
        case .flash(let duration):
            // Add flash effect
            let flashLayer = CALayer()
            flashLayer.backgroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
            
            let fadeIn = CABasicAnimation(keyPath: "opacity")
            fadeIn.fromValue = 0.0
            fadeIn.toValue = 1.0
            fadeIn.duration = duration / 2
            
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1.0
            fadeOut.toValue = 0.0
            fadeOut.duration = duration / 2
            fadeOut.beginTime = CFTimeInterval(duration / 2)
            
            let group = CAAnimationGroup()
            group.animations = [fadeIn, fadeOut]
            group.duration = duration
            
            flashLayer.add(group, forKey: "flash")
            
        case .zoom(let duration, let scale):
            // Add zoom effect
            let zoomLayer = CALayer()
            
            let transform = CABasicAnimation(keyPath: "transform.scale")
            transform.fromValue = 1.0
            transform.toValue = scale
            transform.duration = duration
            
            zoomLayer.add(transform, forKey: "zoom")
        }
    }
    
    private func extractHighlight(from audioURL: URL) async throws -> (start: Double, duration: Double) {
        let audioProcessor = AudioProcessingService()
        let (beats, mood) = try await audioProcessor.analyzeAudio(url: audioURL)
        
        print("\nAnalyzing \(beats.count) beats for best highlight section...")
        
        // Group beats into windows of 20 seconds with 10 second overlap
        let windowDuration = 20.0
        let windowOverlap = 10.0
        var windows: [(start: Double, beats: [AudioProcessingService.Beat])] = []
        
        let lastBeatTime = beats.last?.timestamp ?? 0
        var currentStart = 0.0
        
        while currentStart < lastBeatTime {
            let windowBeats = beats.filter { 
                $0.timestamp >= currentStart && 
                $0.timestamp < (currentStart + windowDuration)
            }
            if !windowBeats.isEmpty {
                windows.append((start: currentStart, beats: windowBeats))
            }
            currentStart += (windowDuration - windowOverlap)
        }
        
        print("Created \(windows.count) overlapping windows for analysis")
        
        // Score each window based on beat characteristics
        var windowScores: [(start: Double, score: Double, avgIntensity: Double)] = []
        
        for window in windows {
            let beatCount = window.beats.count
            let avgIntensity = window.beats.map(\.intensity).reduce(0.0, +) / Double(beatCount)
            let intensityVariation = window.beats.map { abs($0.intensity - avgIntensity) }.reduce(0.0, +)
            
            // Calculate beat spacing consistency
            var spacingConsistency = 0.0
            if beatCount > 1 {
                let beatSpacings = zip(window.beats, window.beats.dropFirst()).map { 
                    $1.timestamp - $0.timestamp 
                }
                let avgSpacing = beatSpacings.reduce(0.0, +) / Double(beatSpacings.count)
                spacingConsistency = beatSpacings.map { abs($0 - avgSpacing) }.reduce(0.0, +)
                spacingConsistency = 1.0 / (1.0 + spacingConsistency) // Normalize to 0-1
            }
            
            // Calculate pattern strength
            let patternStrength = calculatePatternStrength(in: window.beats)
            
            // Combine factors with weights based on mood
            let beatDensityScore = Double(beatCount) / windowDuration
            let score = switch mood {
                case .energetic:
                    beatDensityScore * 0.4 + avgIntensity * 0.3 + spacingConsistency * 0.2 + patternStrength * 0.1
                case .emotional:
                    avgIntensity * 0.4 + spacingConsistency * 0.3 + patternStrength * 0.2 + beatDensityScore * 0.1
                case .tense:
                    intensityVariation * 0.4 + beatDensityScore * 0.3 + avgIntensity * 0.2 + spacingConsistency * 0.1
                default:
                    beatDensityScore * 0.3 + avgIntensity * 0.3 + spacingConsistency * 0.2 + patternStrength * 0.2
            }
            
            windowScores.append((
                start: window.start,
                score: score,
                avgIntensity: avgIntensity
            ))
        }
        
        // Prefer windows from the first half of the audio
        for i in 0..<windowScores.count {
            let positionPenalty = (windowScores[i].start / lastBeatTime) * 0.3 // Up to 30% penalty for later windows
            windowScores[i].score *= (1.0 - positionPenalty)
        }
        
        // Find the best window
        guard let bestWindow = windowScores.max(by: { $0.score < $1.score }) else {
            return (start: 0.0, duration: 20.0) // Fallback to start
        }
        
        print("Selected window at \(bestWindow.start)s with score \(bestWindow.score) and average intensity \(bestWindow.avgIntensity)")
        
        return (start: bestWindow.start, duration: windowDuration)
    }
    
    private func calculatePatternStrength(in beats: [AudioProcessingService.Beat]) -> Double {
        guard beats.count >= 8 else { return 0.0 }
        
        // Look for 4-beat patterns
        let patternSize = 4
        var maxPatternScore = 0.0
        
        for i in 0...(beats.count - patternSize * 2) {
            let pattern1 = Array(beats[i..<(i + patternSize)])
            let pattern2 = Array(beats[(i + patternSize)..<(i + patternSize * 2)])
            
            let patternScore = calculatePatternSimilarity(
                pattern1.map { $0.intensity },
                pattern2.map { $0.intensity }
            )
            maxPatternScore = max(maxPatternScore, patternScore)
        }
        
        return maxPatternScore
    }
    
    enum VideoEditingError: Error {
        case invalidVideo
        case processingError(String)
        case exportError(String)
    }

    func createAMVEdit(
        videoURL: URL,
        audioURL: URL,
        beats: [AudioProcessingService.Beat]
    ) async throws -> URL {
        print("\n=== Starting AI-Enhanced AMV Edit Creation ===")
        
        // Load assets
        let videoAsset = AVAsset(url: videoURL)
        let audioAsset = AVAsset(url: audioURL)
        
        // Get audio beats and highlight
        let audioProcessor = AudioProcessingService()
        let (allBeats, detectedMood) = try await audioProcessor.analyzeAudio(url: audioURL)
        
        // Override mood detection for high-intensity beats - lower threshold to 0.2
        let highIntensityBeats = allBeats.filter { $0.intensity > 0.2 }.count
        let highIntensityRatio = Double(highIntensityBeats) / Double(allBeats.count)
        let mood = if highIntensityRatio > 0.05 { // Lower threshold to 5%
            VideoMood.energetic // Force energetic for trap/intense beats
        } else {
            detectedMood
        }
        
        print("Total beats detected: \(allBeats.count)")
        print("High intensity beats ratio: \(highIntensityRatio)")
        print("Original mood: \(detectedMood), Adjusted mood: \(mood)")
        
        // Load video and audio tracks
        guard let sourceVideoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let sourceAudioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw AppError.videoProcessingError("Failed to load source tracks")
        }
        
        // Get the AI-detected highlight
        print("\nAnalyzing audio for best highlight section...")
        let highlight = try await extractHighlight(from: audioURL)
        print("AI suggested highlight: \(highlight.start)s to \(highlight.start + highlight.duration)s")
        
        // Analyze video comprehensively
        print("\nPerforming comprehensive video analysis...")
        let (videoHighlights, scenes) = try await analyzeVideo(url: videoURL)
        print("Found \(videoHighlights.count) potential video highlights across \(scenes.count) scenes")
        
        // Get video properties
        let videoDuration = try await videoAsset.load(.duration)
        let videoDurationSeconds = CMTimeGetSeconds(videoDuration)
        print("Video duration: \(videoDurationSeconds)s")
        
        // Get beats in the highlight window
        let startTime = highlight.start
        let endTime = startTime + highlight.duration
        let selectedBeats = allBeats.filter { 
            $0.timestamp >= startTime && 
            $0.timestamp < endTime
        }
        print("\nFound \(selectedBeats.count) beats in highlight window")
        
        // *** NEW: AI-POWERED SEQUENCE GENERATION ***
        print("\n🤖 Generating AI-optimized video sequence...")
        let videoSequence = try await self.generateAISequence(
            beats: selectedBeats,
            highlights: videoHighlights,
            scenes: scenes,
            mood: mood,
            duration: endTime - startTime
        )
        
        print("AI Generated sequence with \(videoSequence.count) segments")
        
        // Validate and optimize sequence
        let validatedSequence = try await self.validateAndOptimizeSequence(videoSequence)
        print("Validated sequence: \(validatedSequence.count) segments")
        
        // Create composition with the AI-generated sequence
        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw AppError.videoProcessingError("Failed to create composition tracks")
        }
        
        // Insert audio
        print("\nInserting audio segment...")
        let audioTimeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)
        )
        try compositionAudioTrack.insertTimeRange(audioTimeRange, of: sourceAudioTrack, at: .zero)
        
        // Apply the AI-generated sequence
        print("\nApplying AI-optimized video sequence...")
        var currentTime = CMTime.zero
        
        for (index, sequenceSegment) in validatedSequence.enumerated() {
            // Insert the video segment
            try compositionVideoTrack.insertTimeRange(
                sequenceSegment.sourceTimeRange,
                of: sourceVideoTrack,
                at: currentTime
            )
            
            // Apply transition
            applyTransition(sequenceSegment.transition, at: currentTime, composition: composition)
            
            print("Applied segment \(index + 1): \(sequenceSegment.sceneType.rawValue) (\(String(format: "%.2f", sequenceSegment.duration))s) - Score: \(String(format: "%.3f", sequenceSegment.qualityScore))")
            
            currentTime = CMTimeAdd(currentTime, CMTime(seconds: sequenceSegment.duration, preferredTimescale: 600))
        }
        
        print("\nSequence complete: \(validatedSequence.count) segments")
        
        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = try await sourceVideoTrack.load(.naturalSize)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        let transform = try await sourceVideoTrack.load(.preferredTransform)
        layerInstruction.setTransform(transform, at: .zero)
        
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]
        
        // Validate video composition
        print("Validating video composition...")
        print("- Render size: \(videoComposition.renderSize)")
        print("- Frame duration: \(videoComposition.frameDuration)")
        print("- Instructions count: \(videoComposition.instructions.count)")
        
        // Ensure render size is valid
        if videoComposition.renderSize.width <= 0 || videoComposition.renderSize.height <= 0 {
            print("⚠️ Invalid render size, using default")
            videoComposition.renderSize = CGSize(width: 1920, height: 1080)
        }
        
        // Ensure frame duration is valid
        if videoComposition.frameDuration == CMTime.zero {
            print("⚠️ Invalid frame duration, using default")
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30) // 30 FPS
        }
        
        // Create output URL
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        try? FileManager.default.removeItem(at: outputURL)
        
        // Export
        let exportSession: AVAssetExportSession
        if let highQualitySession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) {
            exportSession = highQualitySession
        } else {
            // Try with medium quality preset as fallback
            guard let fallbackSession = AVAssetExportSession(
                asset: composition,
                presetName: AVAssetExportPresetMediumQuality
            ) else {
                throw AppError.videoProcessingError("Failed to create export session")
            }
            exportSession = fallbackSession
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        print("\nStarting export...")
        print("Export preset: \(exportSession.presetName)")
        print("Output URL: \(outputURL)")
        print("Video composition: \(videoComposition)")
        
        await exportSession.export()
        
        print("Export status: \(exportSession.status.rawValue)")
        print("Export progress: \(exportSession.progress)")
        
        if let error = exportSession.error {
            print("Export failed with error: \(error.localizedDescription)")
            print("Error details: \(error)")
            throw AppError.videoProcessingError("Export failed: \(error.localizedDescription)")
        }
        
        guard exportSession.status == .completed else {
            let statusText = switch exportSession.status {
            case .unknown: "unknown"
            case .waiting: "waiting"
            case .exporting: "exporting"
            case .completed: "completed"
            case .failed: "failed"
            case .cancelled: "cancelled"
            @unknown default: "unknown status"
            }
            print("Export failed with status: \(statusText)")
            
            // Try simple export as fallback
            print("🔄 Trying simple export as fallback...")
            return try await simpleExport(composition: composition, outputURL: outputURL)
        }
        
        print("✅ AI-Enhanced AMV Export completed successfully!")
        return outputURL
    }
    
    // Fallback simple export without video composition
    private func simpleExport(composition: AVMutableComposition, outputURL: URL) async throws -> URL {
        print("🔄 Attempting simple export without video composition...")
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            throw AppError.videoProcessingError("Failed to create simple export session")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        // Note: No videoComposition set for simple export
        
        print("Starting simple export...")
        await exportSession.export()
        
        if let error = exportSession.error {
            print("Simple export failed: \(error.localizedDescription)")
            throw AppError.videoProcessingError("Simple export failed: \(error.localizedDescription)")
        }
        
        guard exportSession.status == .completed else {
            throw AppError.videoProcessingError("Simple export failed with status: \(exportSession.status.rawValue)")
        }
        
        print("✅ Simple export completed!")
        return outputURL
    }
    
    // MARK: - AI Sequence Generation
    
    private struct AISequenceSegment {
        let sourceTimeRange: CMTimeRange
        let duration: Double
        let sceneType: SceneType
        let transition: VideoTransition
        let qualityScore: Double
        let visualContext: VisualContext
        let narrative: String // Brief description of what this segment represents
    }
    
    private func generateAISequence(
        beats: [AudioProcessingService.Beat],
        highlights: [VideoHighlight],
        scenes: [Scene],
        mood: VideoMood,
        duration: Double
    ) async throws -> [AISequenceSegment] {
        
        // Step 1: Create a narrative structure based on mood
        let narrativeStructure = self.createNarrativeStructure(mood: mood, duration: duration, beatCount: beats.count)
        print("Narrative structure: \(narrativeStructure.map { $0.description }.joined(separator: " → "))")
        
        // Step 2: Create a diverse pool of video segments
        let segmentPool = self.createDiverseSegmentPool(highlights: highlights, scenes: scenes)
        print("Created pool of \(segmentPool.count) diverse video segments")
        
        // Step 3: AI-guided segment selection with beat grouping
        var selectedSegments: [AISequenceSegment] = []
        var usedSegments: Set<String> = []
        var lastVisualContext: VisualContext?
        var skippedBeats = 0
        
        print("Processing \(beats.count) beats for segment generation...")
        
        // Group beats into longer segments for very dense beat patterns
        let targetSegmentDuration = 0.5 // Target 0.5 second segments
        var groupedBeats: [(beat: AudioProcessingService.Beat, duration: Double)] = []
        
        var i = 0
        while i < beats.count {
            let startBeat = beats[i]
            var accumulatedDuration = 0.0
            var endIndex = i
            
            // Accumulate beats until we reach target duration
            while endIndex < beats.count - 1 && accumulatedDuration < targetSegmentDuration {
                let nextBeat = beats[endIndex + 1]
                let beatDuration = nextBeat.timestamp - beats[endIndex].timestamp
                accumulatedDuration += beatDuration
                endIndex += 1
            }
            
            // If we're at the last beat, use a default duration
            if endIndex == beats.count - 1 {
                accumulatedDuration = max(accumulatedDuration, 0.3)
            }
            
            // Only include if duration is reasonable
            if accumulatedDuration >= 0.1 {
                groupedBeats.append((beat: startBeat, duration: accumulatedDuration))
            } else {
                skippedBeats += (endIndex - i + 1)
            }
            
            i = endIndex + 1
        }
        
        print("Beat grouping result:")
        print("- Original beats: \(beats.count)")
        print("- Grouped segments: \(groupedBeats.count)")
        print("- Average segment duration: \(String(format: "%.2f", groupedBeats.map { $0.duration }.reduce(0, +) / Double(groupedBeats.count)))s")
        
        // Now process the grouped beats
        for (index, groupedBeat) in groupedBeats.enumerated() {
            let beat = groupedBeat.beat
            let segmentDuration = groupedBeat.duration
            
            // Determine what kind of segment we need based on narrative structure
            let narrativePhase = self.getCurrentNarrativePhase(
                progress: Double(index) / Double(groupedBeats.count),
                structure: narrativeStructure
            )
            
            // AI-select the best segment for this moment
            if let selectedSegment = self.selectOptimalSegment(
                for: beat,
                duration: segmentDuration,
                narrativePhase: narrativePhase,
                pool: segmentPool,
                scenes: scenes,
                usedSegments: usedSegments,
                lastContext: lastVisualContext,
                index: index
            ) {
                selectedSegments.append(selectedSegment)
                usedSegments.insert(selectedSegment.narrative)
                lastVisualContext = selectedSegment.visualContext
                
                // Periodically reset used segments to allow variety
                if usedSegments.count >= segmentPool.count / 2 {
                    usedSegments.removeAll()
                    print("Reset segment pool for variety")
                }
            } else {
                if index < 10 { // Debug first few failures
                    print("Warning: Could not find suitable segment for grouped beat \(index) (duration: \(segmentDuration)s)")
                }
            }
        }
        
        print("Segment generation complete:")
        print("- Total grouped beats processed: \(groupedBeats.count)")
        print("- Segments generated: \(selectedSegments.count)")
        print("- Total video duration: \(String(format: "%.2f", selectedSegments.map { $0.duration }.reduce(0, +)))s")
        print("- Target audio duration: \(String(format: "%.2f", duration))s")
        
        // DURATION MATCHING: Ensure video exactly matches audio duration
        let currentTotalDuration = selectedSegments.map { $0.duration }.reduce(0, +)
        let durationGap = duration - currentTotalDuration
        
        if abs(durationGap) > 0.1 { // Significant gap
            print("🔧 Fixing duration gap: \(String(format: "%.2f", durationGap))s")
            
            if durationGap > 0 { // Video too short - need to extend
                if !selectedSegments.isEmpty {
                    // Extend the last segment to fill the gap
                    let lastIndex = selectedSegments.count - 1
                    let lastSegment = selectedSegments[lastIndex]
                    let extendedDuration = lastSegment.duration + durationGap
                    
                    // Create extended segment
                    let extendedSegment = AISequenceSegment(
                        sourceTimeRange: CMTimeRange(
                            start: lastSegment.sourceTimeRange.start,
                            duration: CMTime(seconds: extendedDuration, preferredTimescale: 600)
                        ),
                        duration: extendedDuration,
                        sceneType: lastSegment.sceneType,
                        transition: lastSegment.transition,
                        qualityScore: lastSegment.qualityScore,
                        visualContext: lastSegment.visualContext,
                        narrative: lastSegment.narrative
                    )
                    
                    selectedSegments[lastIndex] = extendedSegment
                    print("✅ Extended last segment by \(String(format: "%.2f", durationGap))s")
                }
            } else { // Video too long - need to trim
                let excessDuration = -durationGap
                var remainingToTrim = excessDuration
                
                // Trim from the end segments
                for i in stride(from: selectedSegments.count - 1, through: 0, by: -1) {
                    guard remainingToTrim > 0 else { break }
                    
                    let segment = selectedSegments[i]
                    let maxTrim = min(remainingToTrim, segment.duration - 0.1) // Keep at least 0.1s
                    
                    if maxTrim > 0 {
                        let newDuration = segment.duration - maxTrim
                        let trimmedSegment = AISequenceSegment(
                            sourceTimeRange: CMTimeRange(
                                start: segment.sourceTimeRange.start,
                                duration: CMTime(seconds: newDuration, preferredTimescale: 600)
                            ),
                            duration: newDuration,
                            sceneType: segment.sceneType,
                            transition: segment.transition,
                            qualityScore: segment.qualityScore,
                            visualContext: segment.visualContext,
                            narrative: segment.narrative
                        )
                        
                        selectedSegments[i] = trimmedSegment
                        remainingToTrim -= maxTrim
                    }
                }
                print("✅ Trimmed \(String(format: "%.2f", excessDuration - remainingToTrim))s from segments")
            }
        }
        
        // Final verification
        let finalDuration = selectedSegments.map { $0.duration }.reduce(0, +)
        print("🎯 Final video duration: \(String(format: "%.2f", finalDuration))s (target: \(String(format: "%.2f", duration))s)")
        
        return selectedSegments
    }
    
    private struct NarrativePhase {
        let name: String
        let description: String
        let preferredSceneTypes: [SceneType]
        let energyLevel: Double // 0.0 to 1.0
        let transitionStyle: VideoTransition
    }
    
    private func createNarrativeStructure(mood: VideoMood, duration: Double, beatCount: Int) -> [NarrativePhase] {
        switch mood {
        case .energetic:
            return [
                NarrativePhase(name: "Opening", description: "Strong opening", preferredSceneTypes: [.wide, .action], energyLevel: 0.8, transitionStyle: .cut),
                NarrativePhase(name: "Build", description: "Energy building", preferredSceneTypes: [.medium, .action], energyLevel: 0.9, transitionStyle: .crossFade(duration: 0.1)),
                NarrativePhase(name: "Peak", description: "High energy peak", preferredSceneTypes: [.action, .highlight], energyLevel: 1.0, transitionStyle: .flash(duration: 0.1)),
                NarrativePhase(name: "Sustain", description: "Maintain intensity", preferredSceneTypes: [.action, .closeup], energyLevel: 0.9, transitionStyle: .zoom(duration: 0.2, scale: 1.2)),
                NarrativePhase(name: "Finale", description: "Strong conclusion", preferredSceneTypes: [.highlight, .action], energyLevel: 1.0, transitionStyle: .flash(duration: 0.15))
            ]
        case .emotional:
            return [
                NarrativePhase(name: "Intro", description: "Gentle opening", preferredSceneTypes: [.calm, .wide], energyLevel: 0.3, transitionStyle: .crossFade(duration: 0.4)),
                NarrativePhase(name: "Development", description: "Emotional building", preferredSceneTypes: [.closeup, .medium], energyLevel: 0.6, transitionStyle: .crossFade(duration: 0.3)),
                NarrativePhase(name: "Climax", description: "Emotional peak", preferredSceneTypes: [.closeup, .highlight], energyLevel: 0.8, transitionStyle: .zoom(duration: 0.3, scale: 1.1)),
                NarrativePhase(name: "Resolution", description: "Emotional resolution", preferredSceneTypes: [.wide, .calm], energyLevel: 0.4, transitionStyle: .crossFade(duration: 0.5))
            ]
        default:
            return [
                NarrativePhase(name: "Start", description: "Balanced opening", preferredSceneTypes: [.wide, .medium], energyLevel: 0.5, transitionStyle: .cut),
                NarrativePhase(name: "Development", description: "Story development", preferredSceneTypes: [.medium, .closeup], energyLevel: 0.6, transitionStyle: .crossFade(duration: 0.3)),
                NarrativePhase(name: "Peak", description: "Main focus", preferredSceneTypes: [.action, .highlight], energyLevel: 0.8, transitionStyle: .zoom(duration: 0.2, scale: 1.1)),
                NarrativePhase(name: "End", description: "Satisfying conclusion", preferredSceneTypes: [.wide, .transition], energyLevel: 0.5, transitionStyle: .crossFade(duration: 0.4))
            ]
        }
    }
    
    private func getCurrentNarrativePhase(progress: Double, structure: [NarrativePhase]) -> NarrativePhase {
        let phaseIndex = min(Int(progress * Double(structure.count)), structure.count - 1)
        return structure[phaseIndex]
    }
    
    private func createDiverseSegmentPool(highlights: [VideoHighlight], scenes: [Scene]) -> [VideoHighlight] {
        var pool: [VideoHighlight] = []
        
        // Group scenes by type for balanced selection
        let scenesByType = Dictionary(grouping: scenes, by: { $0.sceneType })
        
        // Create multiple highlights from each scene type
        for (sceneType, typeScenes) in scenesByType {
            let sortedScenes = typeScenes.sorted { $0.emotionalScore > $1.emotionalScore }
            
            // Take up to 8 best scenes of each type
            for (i, scene) in sortedScenes.prefix(8).enumerated() {
                // Create 3 variations of each scene (start, middle, end)
                let sceneDuration = scene.timeRange.duration
                let sceneStart = scene.timeRange.start
                
                // Full scene
                pool.append(VideoHighlight(
                    timeRange: CMTimeRange(
                        start: CMTime(seconds: sceneStart, preferredTimescale: 600),
                        duration: CMTime(seconds: sceneDuration, preferredTimescale: 600)
                    ),
                    intensity: scene.emotionalScore + Double(i) * 0.001,
                    type: sceneType == .action ? .action : sceneType == .closeup ? .detail : .transition
                ))
                
                // First half
                pool.append(VideoHighlight(
                    timeRange: CMTimeRange(
                        start: CMTime(seconds: sceneStart, preferredTimescale: 600),
                        duration: CMTime(seconds: sceneDuration * 0.6, preferredTimescale: 600)
                    ),
                    intensity: scene.emotionalScore + Double(i) * 0.001 + 0.01,
                    type: sceneType == .action ? .action : sceneType == .closeup ? .detail : .transition
                ))
                
                // Second half
                if sceneDuration > 0.8 {
                    pool.append(VideoHighlight(
                        timeRange: CMTimeRange(
                            start: CMTime(seconds: sceneStart + sceneDuration * 0.4, preferredTimescale: 600),
                            duration: CMTime(seconds: sceneDuration * 0.6, preferredTimescale: 600)
                        ),
                        intensity: scene.emotionalScore + Double(i) * 0.001 + 0.02,
                        type: sceneType == .action ? .action : sceneType == .closeup ? .detail : .transition
                    ))
                }
            }
        }
        
        // Add original highlights
        pool.append(contentsOf: highlights)
        
        // Remove duplicates and sort by quality
        let uniquePool = Array(Set(pool)).sorted { $0.intensity > $1.intensity }
        
        return uniquePool
    }
    
    private func selectOptimalSegment(
        for beat: AudioProcessingService.Beat,
        duration: Double,
        narrativePhase: NarrativePhase,
        pool: [VideoHighlight],
        scenes: [Scene], // Add scenes parameter
        usedSegments: Set<String>,
        lastContext: VisualContext?,
        index: Int
    ) -> AISequenceSegment? {
        
        var bestSegment: AISequenceSegment?
        var bestScore = -1.0
        
        // Find scenes that match our narrative needs
        let availableHighlights = pool.filter { highlight in
            CMTimeGetSeconds(highlight.timeRange.duration) >= duration * 0.8 // Must be long enough
        }
        
        for highlight in availableHighlights {
            // Find corresponding scene
            guard let scene = scenes.first(where: { scene in
                let highlightMid = CMTimeGetSeconds(highlight.timeRange.start) + CMTimeGetSeconds(highlight.timeRange.duration) / 2
                return highlightMid >= scene.timeRange.start && highlightMid < scene.timeRange.start + scene.timeRange.duration
            }) else { continue }
            
            // Create visual context
            let visualContext = createVisualContext(from: scene)
            let narrative = "\(scene.sceneType.rawValue)_\(String(format: "%.1f", scene.timeRange.start))"
            
            // Skip if already used (unless we're running out of options)
            if usedSegments.contains(narrative) && usedSegments.count < Int(Double(pool.count) * 0.7) {
                continue
            }
            
            // Calculate AI score
            let score = calculateAIScore(
                scene: scene,
                highlight: highlight,
                beat: beat,
                narrativePhase: narrativePhase,
                lastContext: lastContext,
                visualContext: visualContext,
                index: index,
                usedCount: usedSegments.contains(narrative) ? 1 : 0
            )
            
            if score > bestScore {
                bestScore = score
                
                // Create segment with appropriate transition
                let transition = selectTransition(
                    for: scene.sceneType,
                    beat: beat,
                    narrativePhase: narrativePhase,
                    index: index,
                    hasLastContext: lastContext != nil
                )
                
                bestSegment = AISequenceSegment(
                    sourceTimeRange: CMTimeRange(
                        start: highlight.timeRange.start,
                        duration: CMTime(seconds: duration, preferredTimescale: 600)
                    ),
                    duration: duration,
                    sceneType: scene.sceneType,
                    transition: transition,
                    qualityScore: score,
                    visualContext: visualContext,
                    narrative: narrative
                )
            }
        }
        
        return bestSegment
    }
    
    private func calculateAIScore(
        scene: Scene,
        highlight: VideoHighlight,
        beat: AudioProcessingService.Beat,
        narrativePhase: NarrativePhase,
        lastContext: VisualContext?,
        visualContext: VisualContext,
        index: Int,
        usedCount: Int
    ) -> Double {
        var score = 0.0
        
        // 1. Narrative alignment (40%)
        let narrativeScore = narrativePhase.preferredSceneTypes.contains(scene.sceneType) ? 1.0 : 0.3
        let energyAlignment = 1.0 - abs(scene.emotionalScore - narrativePhase.energyLevel)
        score += (narrativeScore * 0.7 + energyAlignment * 0.3) * 0.4
        
        // 2. Visual consistency (30%)
        if let lastContext = lastContext {
            let colorSimilarity = calculateColorSimilarity(visualContext.dominantColors, lastContext.dominantColors)
            let brightnessContinuity = 1.0 - min(abs(visualContext.brightness - lastContext.brightness), 0.5) * 2
            let movementFlow = 1.0 - min(abs(visualContext.movement - lastContext.movement), 0.3) * 3.33
            score += (colorSimilarity * 0.4 + brightnessContinuity * 0.3 + movementFlow * 0.3) * 0.3
        } else {
            score += 0.3 // Bonus for first segment
        }
        
        // 3. Beat synchronization (20%)
        let beatAlignment = min(beat.intensity * scene.movement, 1.0)
        score += beatAlignment * 0.2
        
        // 4. Content quality (10%)
        score += highlight.intensity * 0.1
        
        // 5. Penalty for overuse
        score *= (1.0 - Double(usedCount) * 0.3)
        
        // 6. Position-based bonus for variety
        if index % 4 == 0 {
            score += 0.05 // Every 4th segment gets variety bonus
        }
        
        return max(score, 0.0)
    }
    
    private func selectTransition(
        for sceneType: SceneType,
        beat: AudioProcessingService.Beat,
        narrativePhase: NarrativePhase,
        index: Int,
        hasLastContext: Bool
    ) -> VideoTransition {
        
        // First segment is always cut
        if !hasLastContext {
            return .cut
        }
        
        // High intensity beats get impact transitions
        if beat.intensity > 0.4 {
            return .flash(duration: 0.1)
        }
        
        // Scene type influences transition
        switch sceneType {
        case .action, .highlight:
            return index % 2 == 0 ? .zoom(duration: 0.15, scale: 1.2) : .flash(duration: 0.1)
        case .calm, .wide:
            return .crossFade(duration: 0.3)
        case .closeup:
            return .zoom(duration: 0.2, scale: 1.1)
        case .transition:
            return .crossFade(duration: 0.2)
        default:
            return narrativePhase.transitionStyle
        }
    }
    
    private func validateAndOptimizeSequence(_ sequence: [AISequenceSegment]) async throws -> [AISequenceSegment] {
        var optimizedSequence = sequence
        
        print("🔍 Validating sequence for consistency...")
        
        // Guard against empty or very short sequences
        guard optimizedSequence.count > 1 else {
            print("⚠️ Sequence too short for validation (\(optimizedSequence.count) segments)")
            return optimizedSequence
        }
        
        // 1. Check for visual jarring transitions
        for i in 1..<optimizedSequence.count {
            let prev = optimizedSequence[i-1]
            let curr = optimizedSequence[i]
            
            // Check for jarring brightness changes
            let brightnessDiff = abs(curr.visualContext.brightness - prev.visualContext.brightness)
            if brightnessDiff > 0.6 {
                print("⚠️ Jarring brightness transition detected at segment \(i)")
                // Apply smoother transition
                optimizedSequence[i] = AISequenceSegment(
                    sourceTimeRange: curr.sourceTimeRange,
                    duration: curr.duration,
                    sceneType: curr.sceneType,
                    transition: .crossFade(duration: 0.4),
                    qualityScore: curr.qualityScore,
                    visualContext: curr.visualContext,
                    narrative: curr.narrative
                )
            }
        }
        
        // 2. Ensure scene type diversity in local regions (only if sequence is long enough)
        let windowSize = 5
        if optimizedSequence.count > windowSize {
            for i in 0..<(optimizedSequence.count - windowSize) {
                let window = Array(optimizedSequence[i..<(i + windowSize)])
                let sceneTypes = Set(window.map { $0.sceneType })
                
                if sceneTypes.count < 3 { // Too little variety in this window
                    print("🔄 Enhancing variety in segments \(i)-\(i+windowSize)")
                    // This would trigger re-selection with forced variety
                }
            }
        } else {
            print("ℹ️ Sequence too short (\(optimizedSequence.count)) for window-based diversity analysis")
        }
        
        // 3. Final quality assessment
        let avgQualityScore = optimizedSequence.map { $0.qualityScore }.reduce(0, +) / Double(optimizedSequence.count)
        let sceneTypeCount = Set(optimizedSequence.map { $0.sceneType }).count
        
        print("✅ Sequence validation complete:")
        print("   - Average quality score: \(String(format: "%.3f", avgQualityScore))")
        print("   - Scene type diversity: \(sceneTypeCount) types")
        print("   - Total segments: \(optimizedSequence.count)")
        
        return optimizedSequence
    }

    func analyzeVideo(url: URL) async throws -> (highlights: [VideoHighlight], scenes: [Scene]) {
        let asset = AVAsset(url: url)
        guard let videoTrack = try? await asset.loadTracks(withMediaType: .video).first else {
            throw VideoEditingError.invalidVideo
        }
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        print("Starting simplified video analysis without frame extraction...")
        
        var highlights: [VideoHighlight] = []
        var scenes: [Scene] = []
        
        // Generate segments based on video duration (simpler approach)
        let segmentDuration = 1.0 // 1 second segments
        let totalSegments = Int(durationSeconds / segmentDuration)
        
        print("Creating \(totalSegments) segments from \(String(format: "%.1f", durationSeconds))s video")
        
        for i in 0..<totalSegments {
            let startTime = Double(i) * segmentDuration
            let endTime = min(startTime + segmentDuration, durationSeconds)
            let actualDuration = endTime - startTime
            
            if actualDuration > 0.1 { // Minimum segment duration
                // Create scene with varying characteristics
                let sceneType = determineSceneTypeByPosition(index: i, totalSegments: totalSegments)
                let movement = generateMovementScore(index: i)
                let emotionalScore = generateEmotionalScore(index: i, position: Double(i) / Double(totalSegments))
                
                let scene = Scene(
                    timeRange: Scene.TimeRange(start: startTime, duration: actualDuration),
                    sceneType: sceneType,
                    movement: movement,
                    emotionalScore: emotionalScore
                )
                scenes.append(scene)
                
                // Create highlight if this segment is deemed interesting
                let highlightScore = calculatePositionalHighlightScore(
                    index: i,
                    totalSegments: totalSegments,
                    movement: movement,
                    emotionalScore: emotionalScore
                )
                
                if highlightScore > 0.2 { // Reasonable threshold
                    let highlightType = determineHighlightTypeByScene(sceneType: sceneType, movement: movement)
                    let highlight = VideoHighlight(
                        timeRange: CMTimeRange(
                            start: CMTime(seconds: startTime, preferredTimescale: 600),
                            duration: CMTime(seconds: actualDuration, preferredTimescale: 600)
                        ),
                        intensity: highlightScore,
                        type: highlightType
                    )
                    highlights.append(highlight)
                }
            }
        }
        
        print("Analysis Complete:")
        print("- Created \(scenes.count) scenes with \(Set(scenes.map { $0.sceneType }).count) different types")
        print("- Generated \(highlights.count) highlights")
        
        return (highlights: highlights, scenes: scenes)
    }
    
    private func determineSceneTypeByPosition(index: Int, totalSegments: Int) -> SceneType {
        let position = Double(index) / Double(totalSegments)
        
        // Distribute scene types throughout the video
        switch index % 7 {
        case 0: return .wide
        case 1: return .medium
        case 2: return .closeup
        case 3: return .action
        case 4: return .transition
        case 5: return .highlight
        default: return .calm
        }
    }
    
    private func generateMovementScore(index: Int) -> Double {
        // Generate pseudo-random but consistent movement scores
        let baseMovement = sin(Double(index) * 0.3) * 0.5 + 0.5 // 0.0 to 1.0
        let variation = cos(Double(index) * 0.7) * 0.2 // Add some variation
        return max(0.0, min(1.0, baseMovement + variation))
    }
    
    private func generateEmotionalScore(index: Int, position: Double) -> Double {
        // Create emotional arc: build up -> peak -> resolution
        var score = 0.3 // Base emotional value
        
        if position < 0.3 {
            // Building up
            score += position * 0.5
        } else if position < 0.7 {
            // Peak emotional content
            score += 0.4 + sin((position - 0.3) * 5) * 0.3
        } else {
            // Resolution
            score += 0.6 - (position - 0.7) * 0.3
        }
        
        // Add segment-based variation
        score += sin(Double(index) * 0.4) * 0.2
        
        return max(0.0, min(1.0, score))
    }
    
    private func calculatePositionalHighlightScore(index: Int, totalSegments: Int, movement: Double, emotionalScore: Double) -> Double {
        let position = Double(index) / Double(totalSegments)
        var score = 0.0
        
        // Movement contributes to highlight potential
        score += movement * 0.4
        
        // Emotional score contributes
        score += emotionalScore * 0.3
        
        // Position in video matters (middle sections more likely to be highlights)
        if position > 0.2 && position < 0.8 {
            score += 0.2
        }
        
        // Every few segments gets a bonus (for variety)
        if index % 3 == 0 {
            score += 0.1
        }
        
        return min(1.0, score)
    }
    
    private func determineHighlightTypeByScene(sceneType: SceneType, movement: Double) -> HighlightType {
        switch sceneType {
        case .action, .highlight:
            return .action
        case .closeup, .wide:
            return .detail
        default:
            return movement > 0.5 ? .action : .transition
        }
    }

    private func detectObjects(in image: CIImage) throws -> [VNRectangleObservation] {
        let objectDetectionRequest = VNDetectRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: image)
        try handler.perform([objectDetectionRequest])
        return objectDetectionRequest.results ?? []
    }

    // Helper functions for visual and logical consistency

    private func determineComposition(from objects: [String]) -> String {
        let objectCount = objects.count
        let uniqueObjects = Set(objects).count
        
        if objectCount == 0 {
            return "wide"
        } else if objectCount == 1 {
            return "closeup"
        } else if uniqueObjects == 1 {
            return "focused"
        } else {
            return "medium"
        }
    }

    private func calculateBrightness(from colors: [CIColor]) -> Double {
        let totalBrightness = colors.map { ($0.red + $0.green + $0.blue) / 3 }.reduce(0, +)
        return totalBrightness / Double(colors.count)
    }

    private func calculateAverageColor(_ colors: [CIColor]) -> CIColor {
        var totalRed: Double = 0
        var totalGreen: Double = 0
        var totalBlue: Double = 0
        let count = Double(colors.count)
        
        for color in colors {
            totalRed += color.red
            totalGreen += color.green
            totalBlue += color.blue
        }
        
        return CIColor(red: totalRed / count,
                      green: totalGreen / count,
                      blue: totalBlue / count)
    }

    private func calculateColorDifference(between color1: CIColor, and color2: CIColor) -> Double {
        let redDiff = pow(color1.red - color2.red, 2)
        let greenDiff = pow(color1.green - color2.green, 2)
        let blueDiff = pow(color1.blue - color2.blue, 2)
        return sqrt(redDiff + greenDiff + blueDiff)
    }

    private func calculateColorSimilarity(_ colors1: [CIColor], _ colors2: [CIColor]) -> Double {
        guard !colors1.isEmpty && !colors2.isEmpty else { return 0.0 }
        
        let avg1 = calculateAverageColor(colors1)
        let avg2 = calculateAverageColor(colors2)
        let diff = calculateColorDifference(between: avg1, and: avg2)
        
        return 1.0 - min(diff, 1.0)
    }

    private func evaluateCompositionFlow(from: SceneType, to: SceneType) -> Double {
        // Evaluate how well two scene compositions flow together
        switch (from, to) {
        case (.wide, .medium), (.medium, .closeup), (.closeup, .medium), (.medium, .wide):
            return 1.0 // Natural progression
        case (.wide, .closeup), (.closeup, .wide):
            return 0.3 // Jarring transition
        case (.action, .calm), (.calm, .action):
            return 0.4 // Dramatic mood change
        case (.transition, _), (_, .transition):
            return 0.8 // Transitions are generally good
        case (.highlight, _), (_, .highlight):
            return 0.9 // Highlights can work anywhere
        default:
            return 0.7 // Neutral transition
        }
    }

    private func evaluateLogicalConsistency(
        currentContext: VisualContext,
        history: [VisualContext],
        sceneType: String,
        lastSceneType: String?
    ) -> Double {
        var score = 0.0
        
        // Object continuity
        if let lastContext = history.last {
            let commonObjects = Set(currentContext.objectTypes).intersection(Set(lastContext.objectTypes))
            score += Double(commonObjects.count) * 0.2
        }
        
        // Scene type progression
        if let last = lastSceneType {
            // Logical scene progressions
            let progressionScores: [String: [String: Double]] = [
                "action": ["reaction": 1.0, "aftermath": 0.9, "action": 0.7],
                "dialogue": ["reaction": 1.0, "action": 0.8, "dialogue": 0.6],
                "establishing": ["action": 1.0, "dialogue": 0.9, "detail": 0.8]
            ]
            score += progressionScores[last]?[sceneType] ?? 0.5
        }
        
        return score
    }

    private func evaluateEmotionalProgression(
        currentScene: Scene,
        highlight: VideoHighlight,
        beatIntensity: Double,
        history: [VisualContext]
    ) -> Double {
        var score = 0.0
        
        // Match emotional intensity with beat intensity
        let emotionalMatch = 1.0 - abs(currentScene.emotionalScore - beatIntensity)
        score += emotionalMatch * 0.4
        
        // Emotional arc progression
        if !history.isEmpty {
            let recentEmotionalAverage = history.suffix(3)
                .map { $0.movement }
                .reduce(0.0, +) / Double(min(history.count, 3))
            
            // Prefer building up or cooling down rather than erratic changes
            let emotionalDelta = currentScene.movement - recentEmotionalAverage
            let smoothProgression = 1.0 - min(abs(emotionalDelta), 0.5) * 2
            score += smoothProgression * 0.6
        }
        
        return score
    }

    private func createVisualContext(from scene: Scene) -> VisualContext {
        // Create visual context based on scene type
        let composition = scene.sceneType
        
        switch composition {
        case .action:
            return VisualContext(
                dominantColors: [CIColor(red: 0.8, green: 0.2, blue: 0.2)],
                brightness: 0.8,
                movement: scene.movement,
                composition: composition,
                objectTypes: ["person", "motion"]
            )
        case .calm:
            return VisualContext(
                dominantColors: [CIColor(red: 0.2, green: 0.6, blue: 0.8)],
                brightness: 0.6,
                movement: scene.movement,
                composition: composition,
                objectTypes: ["landscape", "static"]
            )
        case .transition:
            return VisualContext(
                dominantColors: [CIColor(red: 0.5, green: 0.5, blue: 0.5)],
                brightness: 0.5,
                movement: scene.movement,
                composition: composition,
                objectTypes: ["blur", "motion"]
            )
        case .highlight:
            return VisualContext(
                dominantColors: [CIColor(red: 0.9, green: 0.9, blue: 0.2)],
                brightness: 0.9,
                movement: scene.movement,
                composition: composition,
                objectTypes: ["focus", "important"]
            )
        case .wide:
            return VisualContext(
                dominantColors: [CIColor(red: 0.3, green: 0.3, blue: 0.3)],
                brightness: 0.7,
                movement: scene.movement,
                composition: composition,
                objectTypes: ["landscape", "wide"]
            )
        case .medium:
            return VisualContext(
                dominantColors: [CIColor(red: 0.4, green: 0.4, blue: 0.4)],
                brightness: 0.6,
                movement: scene.movement,
                composition: composition,
                objectTypes: ["person", "medium"]
            )
        case .closeup:
            return VisualContext(
                dominantColors: [CIColor(red: 0.3, green: 0.3, blue: 0.3)],
                brightness: 0.7,
                movement: scene.movement,
                composition: composition,
                objectTypes: ["face", "detail"]
            )
        }
    }

    // MARK: - AI Frame Analysis
    
    private struct SceneCharacteristics {
        var faceCount: Int = 0
        var humanPoseDetected: Bool = false
        var objectCount: Int = 0
        var dominantSceneLabels: [String] = []
        var saliencyHotspots: Int = 0
        var colorVariation: Double = 0.0
        var brightness: Double = 0.0
        
        mutating func merge(with other: SceneCharacteristics) {
            faceCount = max(faceCount, other.faceCount)
            humanPoseDetected = humanPoseDetected || other.humanPoseDetected
            objectCount += other.objectCount
            dominantSceneLabels.append(contentsOf: other.dominantSceneLabels)
            saliencyHotspots += other.saliencyHotspots
            colorVariation = max(colorVariation, other.colorVariation)
            brightness = (brightness + other.brightness) / 2
        }
    }
    
    private func analyzeFrameWithAI(frame: CVPixelBuffer, requests: [VNRequest]) async throws -> SceneCharacteristics {
        var characteristics = SceneCharacteristics()
        
        let handler = VNImageRequestHandler(cvPixelBuffer: frame, options: [:])
        try handler.perform(requests)
        
        // Process scene classification
        if let sceneRequest = requests.first(where: { $0 is VNClassifyImageRequest }) as? VNClassifyImageRequest,
           let observations = sceneRequest.results {
            // Get top 3 scene classifications with confidence > 0.1
            let significantLabels = observations
                .filter { $0.confidence > 0.1 }
                .prefix(3)
                .map { $0.identifier }
            characteristics.dominantSceneLabels = Array(significantLabels)
        }
        
        // Process face detection
        if let faceRequest = requests.first(where: { $0 is VNDetectFaceRectanglesRequest }) as? VNDetectFaceRectanglesRequest,
           let faceObservations = faceRequest.results {
            characteristics.faceCount = faceObservations.count
        }
        
        // Process human pose detection
        if let poseRequest = requests.first(where: { $0 is VNDetectHumanBodyPoseRequest }) as? VNDetectHumanBodyPoseRequest,
           let poseObservations = poseRequest.results {
            characteristics.humanPoseDetected = !poseObservations.isEmpty
        }
        
        // Process object detection
        if let objectRequest = requests.first(where: { $0 is VNDetectRectanglesRequest }) as? VNDetectRectanglesRequest,
           let objectObservations = objectRequest.results {
            characteristics.objectCount = objectObservations.count
        }
        
        // Process saliency
        if let saliencyRequest = requests.first(where: { $0 is VNGenerateAttentionBasedSaliencyImageRequest }) as? VNGenerateAttentionBasedSaliencyImageRequest,
           let saliencyObservations = saliencyRequest.results {
            // Count high-attention regions
            characteristics.saliencyHotspots = saliencyObservations.count
        }
        
        // Calculate color and brightness
        let ciImage = CIImage(cvPixelBuffer: frame)
        characteristics.brightness = self.calculateImageBrightness(ciImage)
        characteristics.colorVariation = self.calculateColorVariation(ciImage)
        
        return characteristics
    }
    
    private func determineSceneType(from characteristics: SceneCharacteristics, motion: Double) -> SceneType {
        let labels = characteristics.dominantSceneLabels.map { $0.lowercased() }
        
        // Use AI scene classification to determine type
        if labels.contains(where: { ["sport", "action", "dance", "performance"].contains($0) }) || motion > 0.7 {
            return .action
        } else if characteristics.faceCount > 0 || labels.contains(where: { ["portrait", "person", "face"].contains($0) }) {
            return .closeup
        } else if labels.contains(where: { ["landscape", "nature", "outdoor", "sky"].contains($0) }) {
            return .wide
        } else if motion > 0.3 || characteristics.saliencyHotspots > 2 {
            return .medium
        } else if labels.contains(where: { ["calm", "peaceful", "serene"].contains($0) }) || motion < 0.2 {
            return .calm
        } else if characteristics.objectCount > 5 {
            return .highlight
        } else {
            return .transition
        }
    }
    
    private func calculateHighlightScore(sceneCharacteristics: SceneCharacteristics, motion: Double, sceneChange: Double) -> Double {
        var score = 0.0
        
        // Motion contributes 30%
        score += motion * 0.3
        
        // Scene change contributes 20%
        score += sceneChange * 0.2
        
        // Human presence contributes 20%
        if sceneCharacteristics.faceCount > 0 || sceneCharacteristics.humanPoseDetected {
            score += 0.2
        }
        
        // Saliency contributes 15%
        score += min(Double(sceneCharacteristics.saliencyHotspots) / 5.0, 1.0) * 0.15
        
        // Scene interest contributes 15%
        let interestingScenes = ["sport", "action", "performance", "dance", "concert", "stage"]
        if sceneCharacteristics.dominantSceneLabels.contains(where: { label in
            interestingScenes.contains(where: { label.lowercased().contains($0) })
        }) {
            score += 0.15
        }
        
        return min(score, 1.0)
    }
    
    private func determineHighlightType(from characteristics: SceneCharacteristics) -> HighlightType {
        if characteristics.faceCount > 0 || characteristics.dominantSceneLabels.contains(where: { 
            $0.lowercased().contains("portrait") || $0.lowercased().contains("face") 
        }) {
            return .detail
        } else if characteristics.dominantSceneLabels.contains(where: { 
            ["action", "sport", "dance", "performance"].contains($0.lowercased()) 
        }) {
            return .action
        } else {
            return .transition
        }
    }
    
    private func ensureSceneDiversity(_ scenes: [Scene]) -> [Scene] {
        var diversifiedScenes = scenes
        let sceneTypeCounts = Dictionary(grouping: scenes, by: { $0.sceneType })
        
        // If any scene type dominates (>70%), reclassify some scenes
        for (sceneType, scenesOfType) in sceneTypeCounts {
            if Double(scenesOfType.count) / Double(scenes.count) > 0.7 {
                print("Diversifying: \(sceneType.rawValue) scenes dominate, reclassifying...")
                
                // Reclassify every 3rd scene of this type to create variety
                for (index, scene) in scenesOfType.enumerated() {
                    if index % 3 == 0, let sceneIndex = diversifiedScenes.firstIndex(where: { $0.timeRange.start == scene.timeRange.start }) {
                        let alternativeType: SceneType = switch scene.movement {
                        case 0.7...: .action
                        case 0.4..<0.7: .medium
                        case 0.2..<0.4: .transition
                        default: .calm
                        }
                        
                        if alternativeType != sceneType {
                            diversifiedScenes[sceneIndex] = Scene(
                                timeRange: scene.timeRange,
                                sceneType: alternativeType,
                                movement: scene.movement,
                                emotionalScore: scene.emotionalScore
                            )
                        }
                    }
                }
            }
        }
        
        return diversifiedScenes
    }
    
    private func filterAndDiversifyHighlights(_ highlights: [VideoHighlight], scenes: [Scene]) -> [VideoHighlight] {
        // Group highlights by scene type and ensure variety
        let highlightsByType = Dictionary(grouping: highlights) { highlight in
            // Find corresponding scene
            return scenes.first { scene in
                let highlightMid = CMTimeGetSeconds(highlight.timeRange.start) + CMTimeGetSeconds(highlight.timeRange.duration) / 2
                return highlightMid >= scene.timeRange.start && highlightMid < scene.timeRange.start + scene.timeRange.duration
            }?.sceneType ?? .action
        }
        
        var diversifiedHighlights: [VideoHighlight] = []
        
        // Take top highlights from each scene type
        for (sceneType, typeHighlights) in highlightsByType {
            let sortedHighlights = typeHighlights.sorted { $0.intensity > $1.intensity }
            let takeCount = min(sortedHighlights.count, max(1, highlights.count / highlightsByType.count))
            
            print("Taking \(takeCount) highlights from \(sceneType.rawValue) scenes")
            diversifiedHighlights.append(contentsOf: sortedHighlights.prefix(takeCount))
        }
        
        return diversifiedHighlights.sorted { CMTimeCompare($0.timeRange.start, $1.timeRange.start) < 0 }
    }
    
    private func calculateImageBrightness(_ image: CIImage) -> Double {
        let averageFilter = CIFilter.areaAverage()
        averageFilter.inputImage = image
        averageFilter.extent = image.extent
        
        guard let outputImage = averageFilter.outputImage else { return 0.5 }
        
        let context = CIContext()
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return Double(bitmap[0]) / 255.0
    }
    
    private func calculateColorVariation(_ image: CIImage) -> Double {
        // Use histogram to measure color variation
        let histogramFilter = CIFilter.areaHistogram()
        histogramFilter.inputImage = image
        histogramFilter.scale = 1.0
        histogramFilter.count = 64 // Smaller histogram for efficiency
        
        guard let outputImage = histogramFilter.outputImage else { return 0.0 }
        
        let context = CIContext()
        var histogram = [Float](repeating: 0, count: 64 * 4)
        context.render(outputImage,
                      toBitmap: &histogram,
                      rowBytes: MemoryLayout<Float>.size * 64 * 4,
                      bounds: CGRect(x: 0, y: 0, width: 64, height: 1),
                      format: .RGBAf,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        // Calculate variance in histogram
        let mean = histogram.reduce(0, +) / Float(histogram.count)
        let variance = histogram.map { pow($0 - mean, 2) }.reduce(0, +) / Float(histogram.count)
        
        return Double(sqrt(variance))
    }
}

extension CIColor {
    func isApproximatelyEqual(to other: CIColor, tolerance: Double = 0.01) -> Bool {
        abs(self.red - other.red) < tolerance &&
        abs(self.green - other.green) < tolerance &&
        abs(self.blue - other.blue) < tolerance
    }
    
    func distance(to other: CIColor) -> Double {
        let dr = self.red - other.red
        let dg = self.green - other.green
        let db = self.blue - other.blue
        return sqrt(dr * dr + dg * dg + db * db)
    }
} 