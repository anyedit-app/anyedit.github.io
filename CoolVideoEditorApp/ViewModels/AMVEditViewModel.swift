import Foundation
import AVFoundation

@MainActor
class AMVEditViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var videoURL: URL?
    @Published var audioURL: URL?
    @Published var editedVideoURL: URL?
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    @Published var statusMessage: String = ""
    @Published var currentError: AppError?
    @Published var beats: [AudioProcessingService.Beat] = []
    
    // MARK: - Services
    private let fileManager = FileManagementService()
    private let audioProcessor = AudioProcessingService()
    private let videoEditor = VideoEditingService()
    
    // MARK: - Computed Properties
    var canCreateEdit: Bool {
        videoURL != nil && audioURL != nil && !isProcessing
    }
    
    // MARK: - File Selection Methods
    func selectVideoFile() {
        fileManager.selectVideoFile { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success(let url):
                    self?.videoURL = url
                    self?.statusMessage = "Video loaded successfully"
                case .failure(let error):
                    self?.currentError = .fileImportFailed(error)
                    self?.statusMessage = "Error loading video: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func selectAudioFile() {
        fileManager.selectAudioFile { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success(let url):
                    self?.audioURL = url
                    self?.statusMessage = "Audio loaded successfully"
                    await self?.detectBeats(in: url)
                case .failure(let error):
                    self?.currentError = .fileImportFailed(error)
                    self?.statusMessage = "Error loading audio: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Audio Import (Legacy method)
    func importAudio() {
        selectAudioFile()
    }
    
    // MARK: - Video Import (Legacy method)
    func importVideo() {
        selectVideoFile()
    }
    
    // MARK: - Beat Detection
    func detectBeats(in audioURL: URL) async {
        do {
            statusMessage = "Analyzing audio beats..."
            let (detectedBeats, _) = try await audioProcessor.analyzeAudio(url: audioURL)
            beats = detectedBeats
            statusMessage = "Found \(detectedBeats.count) beats in audio"
        } catch {
            currentError = error as? AppError ?? .beatDetectionError(error.localizedDescription)
            statusMessage = "Error analyzing audio: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Create Edit
    func createEdit() async {
        guard let videoURL = videoURL, let audioURL = audioURL else {
            currentError = .videoProcessingError("Please select both video and audio files")
            statusMessage = "Please select both video and audio files"
            return
        }
        
        isProcessing = true
        processingProgress = 0.0
        statusMessage = "Creating AI-enhanced video..."
        editedVideoURL = nil // Clear previous result
        
        do {
            let outputURL = try await videoEditor.createAMVEdit(
                videoURL: videoURL,
                audioURL: audioURL,
                beats: beats
            )
            
            editedVideoURL = outputURL
            statusMessage = "AI video created successfully!"
            print("Edit completed: \(outputURL)")
        } catch {
            currentError = error as? AppError ?? .videoProcessingError(error.localizedDescription)
            statusMessage = "Error creating video: \(error.localizedDescription)"
        }
        
        isProcessing = false
    }
    
    // MARK: - Clear Status
    func clearStatus() {
        statusMessage = ""
        currentError = nil
    }
} 