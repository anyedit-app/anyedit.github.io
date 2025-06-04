import Foundation
import AppKit
import UniformTypeIdentifiers

class FileManagementService {
    private let fileManager = FileManager.default
    
    // MARK: - Video Import
    func selectVideoFile(completion: @escaping (Result<URL, Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                completion(.success(url))
            } else {
                completion(.failure(AppError.fileImportFailed(nil)))
            }
        }
    }
    
    // MARK: - Audio Import
    func selectAudioFile(completion: @escaping (Result<URL, Error>) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.mp3, .wav, .aac, .m4a]
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                completion(.success(url))
            } else {
                completion(.failure(AppError.fileImportFailed(nil)))
            }
        }
    }
    
    // MARK: - Video Export
    func getSaveURL(completion: @escaping (Result<URL, Error>) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "edited_video.mp4"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                completion(.success(url))
            } else {
                completion(.failure(AppError.fileExportFailed(nil)))
            }
        }
    }
    
    func copyFile(from sourceURL: URL, to destinationURL: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    func createTemporaryURL(withExtension ext: String) throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let fileName = UUID().uuidString + "." + ext
        return tempDir.appendingPathComponent(fileName)
    }
}

// MARK: - UTType Extensions
extension UTType {
    static let mp3 = UTType(filenameExtension: "mp3")!
    static let wav = UTType(filenameExtension: "wav")!
    static let aac = UTType(filenameExtension: "aac")!
    static let m4a = UTType(filenameExtension: "m4a")!
} 