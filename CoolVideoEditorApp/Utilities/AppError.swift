import Foundation

enum AppError: LocalizedError {
    case fileImportFailed(Error?)
    case fileExportFailed(Error?)
    case invalidVideoFormat
    case videoProcessingError(String)
    case aiModelError(String)
    case audioProcessingError(String)
    case beatDetectionError(String)
    case frameProcessingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileImportFailed(let error):
            return "Failed to import file: \(error?.localizedDescription ?? "Unknown error")"
        case .fileExportFailed(let error):
            return "Failed to export file: \(error?.localizedDescription ?? "Unknown error")"
        case .invalidVideoFormat:
            return "Invalid video format"
        case .videoProcessingError(let message):
            return "Video processing error: \(message)"
        case .aiModelError(let message):
            return "AI model error: \(message)"
        case .audioProcessingError(let message):
            return "Audio processing error: \(message)"
        case .beatDetectionError(let message):
            return "Beat detection error: \(message)"
        case .frameProcessingFailed(let message):
            return "Frame processing error: \(message)"
        }
    }
} 