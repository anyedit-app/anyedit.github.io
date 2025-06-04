@preconcurrency import CoreImage
import Foundation

@globalActor actor AIEngineActor {
    static let shared = AIEngineActor()
}

@AIEngineActor
class AIEngineService: @unchecked Sendable {
    private let processingQueue = DispatchQueue(label: "ai.processing.queue")
    private let ciContext = CIContext()
    
    func convertToPixelBuffer(_ image: CIImage) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                           width,
                           height,
                           kCVPixelFormatType_32BGRA,
                           attrs,
                           &pixelBuffer)
        
        guard let buffer = pixelBuffer else {
            throw AppError.videoProcessingError("Failed to create pixel buffer")
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let context = ciContext
        context.render(image,
                      to: buffer,
                      bounds: image.extent,
                      colorSpace: CGColorSpaceCreateDeviceRGB())
        
        return buffer
    }
    
    func processFrame(pixelBuffer: CVPixelBuffer, using effect: any AIEffect) async throws -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let outputImage = try await effect.process(image: ciImage)
        
        // Create output pixel buffer
        var outputBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault,
                          CVPixelBufferGetWidth(pixelBuffer),
                          CVPixelBufferGetHeight(pixelBuffer),
                          CVPixelBufferGetPixelFormatType(pixelBuffer),
                          nil,
                          &outputBuffer)
        
        guard let outputBuffer = outputBuffer else {
            throw AppError.frameProcessingFailed("Failed to create output buffer")
        }
        
        // Render the processed image to the output buffer
        ciContext.render(outputImage, to: outputBuffer)
        
        return outputBuffer
    }
} 