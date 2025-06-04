import Foundation
import CoreImage
import Vision

enum StyleTransferError: Error {
    case processingFailed(String)
}

class StyleTransferModel {
    private let ciContext: CIContext
    private let filters: [String] = [
        "CIPhotoEffectNoir",
        "CIPhotoEffectChrome",
        "CIPhotoEffectFade",
        "CIPhotoEffectInstant",
        "CIPhotoEffectMono",
        "CIPhotoEffectProcess",
        "CIPhotoEffectTonal",
        "CIPhotoEffectTransfer"
    ]
    
    init() {
        self.ciContext = CIContext()
    }
    
    func applyStyle(to image: CIImage, completion: @escaping (Result<CIImage, Error>) -> Void) {
        // Get style index from parameters, default to 0
        let styleIndex = min(max(0, UserDefaults.standard.integer(forKey: "styleIndex")), filters.count - 1)
        let filterName = filters[styleIndex]
        
        guard let filter = CIFilter(name: filterName) else {
            completion(.failure(StyleTransferError.processingFailed("Failed to create filter")))
            return
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        
        guard let outputImage = filter.outputImage else {
            completion(.failure(StyleTransferError.processingFailed("Filter produced no output")))
            return
        }
        
        // Apply strength adjustment if needed
        let styleStrength = UserDefaults.standard.double(forKey: "styleStrength")
        if styleStrength < 1.0 {
            let blendFilter = CIFilter(name: "CIBlendWithMask")
            blendFilter?.setValue(image, forKey: kCIInputImageKey)
            blendFilter?.setValue(outputImage, forKey: kCIInputBackgroundImageKey)
            
            // Create a mask based on style strength
            let mask = CIImage(color: CIColor(red: styleStrength, green: styleStrength, blue: styleStrength))
                .cropped(to: image.extent)
            blendFilter?.setValue(mask, forKey: kCIInputMaskImageKey)
            
            if let blendedImage = blendFilter?.outputImage {
                completion(.success(blendedImage))
            } else {
                completion(.failure(StyleTransferError.processingFailed("Failed to blend images")))
            }
        } else {
            completion(.success(outputImage))
        }
    }
} 