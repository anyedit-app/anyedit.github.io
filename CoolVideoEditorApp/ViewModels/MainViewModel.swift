import SwiftUI
import AVFoundation
import Combine

@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var originalVideoURL: URL?
    @Published var processedVideoURL: URL?
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var currentError: AppError?
    @Published var selectedAIEffect: (any AIEffect)?
    
    // MARK: - Services
    private let fileManager = FileManagementService()
    private var videoProcessor: VideoProcessingService!
    private var aiEngine: AIEngineService!
    
    init() {
        Task {
            self.videoProcessor = await VideoProcessingService()
            self.aiEngine = await AIEngineService()
        }
    }
    
    // MARK: - Child ViewModels
    @Published var videoPlayerViewModel = VideoPlayerViewModel()
    @Published var processedVideoPlayerViewModel = VideoPlayerViewModel()
    @Published var effectsViewModel = EffectsViewModel()
    
    // MARK: - Video Import
    func importVideo() {
        fileManager.selectVideoFile { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success(let url):
                    self?.originalVideoURL = url
                    await self?.videoPlayerViewModel.loadVideo(url: url)
                    self?.processedVideoURL = nil
                    await self?.processedVideoPlayerViewModel.loadVideo(url: nil)
                    self?.processingProgress = 0.0
                case .failure(let error):
                    self?.currentError = .fileImportFailed(error)
                }
            }
        }
    }
    
    // MARK: - Effect Application
    func applySelectedEffect() {
        guard let inputURL = originalVideoURL,
              let effect = selectedAIEffect else {
            currentError = .videoProcessingError("No video or effect selected")
            return
        }
        
        isProcessing = true
        processingProgress = 0.0
        
        // Create temporary URL for processed video
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        Task { @MainActor [weak self] in
            do {
                guard let videoProcessor = self?.videoProcessor,
                      let aiEngine = self?.aiEngine else {
                    self?.currentError = .videoProcessingError("Services not initialized")
                    self?.isProcessing = false
                    return
                }
                
                try await videoProcessor.processVideo(
                    inputURL: inputURL,
                    outputURL: tempURL,
                    effect: effect,
                    aiEngine: aiEngine
                ) { [weak self] progress in
                    Task { @MainActor in
                        self?.processingProgress = progress
                    }
                }
                
                self?.processedVideoURL = tempURL
                await self?.processedVideoPlayerViewModel.loadVideo(url: tempURL)
                self?.isProcessing = false
            } catch {
                self?.currentError = .videoProcessingError(error.localizedDescription)
                self?.isProcessing = false
            }
        }
    }
    
    // MARK: - Video Export
    func exportVideo() {
        guard let processedURL = processedVideoURL else {
            currentError = .fileExportFailed(nil)
            return
        }
        
        fileManager.getSaveURL { [weak self] result in
            switch result {
            case .success(let saveURL):
                self?.fileManager.copyFile(from: processedURL, to: saveURL) { copyResult in
                    Task { @MainActor in
                        if case .failure(let error) = copyResult {
                            self?.currentError = .fileExportFailed(error)
                        }
                    }
                }
            case .failure(let error):
                Task { @MainActor in
                    self?.currentError = .fileExportFailed(error)
                }
            }
        }
    }
    
    func processVideo(inputURL: URL, effect: any AIEffect) async throws -> URL {
        guard let videoProcessor = self.videoProcessor,
              let aiEngine = self.aiEngine else {
            throw AppError.videoProcessingError("Services not initialized")
        }
        
        let tempURL = try fileManager.createTemporaryURL(withExtension: "mp4")
        
        try await videoProcessor.processVideo(
            inputURL: inputURL,
            outputURL: tempURL,
            effect: effect,
            aiEngine: aiEngine
        ) { [weak self] progress in
            Task { @MainActor in
                self?.processingProgress = progress
            }
        }
        
        return tempURL
    }
} 