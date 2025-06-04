import Foundation
import CoreML
import CoreImage

@preconcurrency
protocol AIEffect: Identifiable, Sendable {
    var id: UUID { get }
    var displayName: String { get }
    var description: String { get }
    var parameters: [String: Any] { get set }
    var defaultParameters: [String: Any] { get }
    
    func validateParameters() async -> Bool
    func parameterDescription(for key: String) -> String
    func process(image: CIImage) async throws -> CIImage
}

// Default implementation
extension AIEffect {
    func validateParameters() -> Bool {
        // Basic validation - ensure all default parameters exist
        return defaultParameters.keys.allSatisfy { parameters.keys.contains($0) }
    }
}

@MainActor
final class StyleTransferEffect: @preconcurrency AIEffect {
    let id = UUID()
    let displayName = "Artistic Style Transfer"
    let description = "Transform your video using various artistic filters"
    
    var parameters: [String: Any]
    let defaultParameters: [String: Any] = [
        "styleStrength": 0.8,
        "styleIndex": 0
    ]
    
    private let styleTransferModel: StyleTransferModel
    
    init() {
        self.parameters = defaultParameters
        self.styleTransferModel = StyleTransferModel()
        
        // Save initial parameters to UserDefaults
        UserDefaults.standard.set(defaultParameters["styleStrength"] as! Double, forKey: "styleStrength")
        UserDefaults.standard.set(defaultParameters["styleIndex"] as! Int, forKey: "styleIndex")
    }
    
    func validateParameters() async -> Bool {
        guard let styleStrength = parameters["styleStrength"] as? Double,
              let styleIndex = parameters["styleIndex"] as? Int else {
            return false
        }
        return styleStrength >= 0 && styleStrength <= 1 && styleIndex >= 0
    }
    
    nonisolated func parameterDescription(for key: String) -> String {
        switch key {
        case "styleStrength":
            return "Controls the strength of the style transfer (0.0 - 1.0)"
        case "styleIndex":
            return "Index of the style to apply"
        default:
            return "Unknown parameter"
        }
    }
    
    func process(image: CIImage) async throws -> CIImage {
        guard let _ = parameters["styleStrength"] as? Double,
              let _ = parameters["styleIndex"] as? Int else {
            throw AppError.videoProcessingError("Invalid parameters")
        }
        
        // Update UserDefaults with current parameters
        if let styleStrength = parameters["styleStrength"] as? Double {
            UserDefaults.standard.set(styleStrength, forKey: "styleStrength")
        }
        if let styleIndex = parameters["styleIndex"] as? Int {
            UserDefaults.standard.set(styleIndex, forKey: "styleIndex")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            styleTransferModel.applyStyle(to: image) { result in
                continuation.resume(with: result)
            }
        }
    }
}

@MainActor
final class BeatSyncEffect: @preconcurrency AIEffect {
    let id = UUID()
    let displayName = "Beat Sync Effects"
    let description = "Dynamic effects that sync with music beats"
    
    var parameters: [String: Any]
    let defaultParameters: [String: Any] = [
        "effectIntensity": 0.7,
        "beatSensitivity": 0.5,
        "colorShift": true,
        "zoomEffect": true
    ]
    
    init() {
        self.parameters = defaultParameters
    }
    
    func validateParameters() async -> Bool {
        guard let effectIntensity = parameters["effectIntensity"] as? Double,
              let beatSensitivity = parameters["beatSensitivity"] as? Double,
              let _ = parameters["colorShift"] as? Bool,
              let _ = parameters["zoomEffect"] as? Bool else {
            return false
        }
        return effectIntensity >= 0 && effectIntensity <= 1 && beatSensitivity >= 0 && beatSensitivity <= 1
    }
    
    nonisolated func parameterDescription(for key: String) -> String {
        switch key {
        case "effectIntensity":
            return "Controls the strength of the beat sync effect (0.0 - 1.0)"
        case "beatSensitivity":
            return "Controls the sensitivity to music beats (0.0 - 1.0)"
        case "colorShift":
            return "Applies color shift effect"
        case "zoomEffect":
            return "Applies zoom effect"
        default:
            return "Unknown parameter"
        }
    }
    
    func process(image: CIImage) async throws -> CIImage {
        guard let effectIntensity = parameters["effectIntensity"] as? Double,
              let beatSensitivity = parameters["beatSensitivity"] as? Double,
              let colorShift = parameters["colorShift"] as? Bool,
              let zoomEffect = parameters["zoomEffect"] as? Bool else {
            throw AppError.videoProcessingError("Invalid parameters")
        }
        
        // Get current beat info from UserDefaults (set by VideoEditingService)
        let beatIntensity = UserDefaults.standard.double(forKey: "currentBeatIntensity")
        let timeSinceBeat = UserDefaults.standard.double(forKey: "timeSinceBeat")
        
        var processedImage = image
        
        if colorShift {
            let hue = timeSinceBeat * 0.05
            let saturation = 1.0 - beatIntensity * 0.5
            let brightness = 1.0 - beatIntensity * 0.5
            let color = CIColor(red: hue, green: saturation, blue: brightness)
            processedImage = image.applyingFilter("CIColorControls", parameters: ["inputBrightness": 0.5, "inputContrast": 1.0, "inputSaturation": saturation])
            processedImage = processedImage.applyingFilter("CIColorMonochrome", parameters: ["inputColor": color])
        }
        
        if zoomEffect {
            let scale = 1.0 + (effectIntensity * beatSensitivity * 0.2)
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            processedImage = image.transformed(by: transform)
        }
        
        // Apply color tint if specified
        if let colorTint = parameters["colorTint"] as? Double, colorTint > 0 {
            let tintColor = CIColor(red: 0.8, green: 0.4, blue: 1.0, alpha: colorTint * beatIntensity)
            let parameters = [
                "inputColor": tintColor
            ]
            processedImage = processedImage.applyingFilter("CIColorMonochrome", parameters: parameters)
        }
        
        return processedImage
    }
}

extension AIEffect {
    static var all: [any AIEffect] {
        get async {
            return [await StyleTransferEffect(), await BeatSyncEffect()]
        }
    }
} 