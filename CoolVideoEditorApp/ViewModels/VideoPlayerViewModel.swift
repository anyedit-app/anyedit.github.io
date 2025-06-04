import SwiftUI
import AVFoundation

@MainActor
class VideoPlayerViewModel: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    
    func loadVideo(url: URL?) async {
        // Remove existing observers
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        statusObserver?.invalidate()
        statusObserver = nil
        
        // Clear player if URL is nil
        guard let url = url else {
            player = nil
            isPlaying = false
            currentTime = 0
            duration = 0
            return
        }
        
        do {
            // Create and configure asset
            let asset = AVAsset(url: url)
            let duration = try await asset.load(.duration)
            self.duration = CMTimeGetSeconds(duration)
            
            // Pre-load video track properties
            let videoTrack = try await asset.loadTracks(withMediaType: .video).first
            if let videoTrack = videoTrack {
                _ = try await videoTrack.load(.naturalSize)
                _ = try await videoTrack.load(.preferredTransform)
            }
            
            // Create player
            let playerItem = AVPlayerItem(asset: asset)
            let newPlayer = AVPlayer(playerItem: playerItem)
            self.player = newPlayer
            
            // Observe player item status
            statusObserver = playerItem.observe(\.status) { item, _ in
                if item.status == .failed {
                    print("Player item failed: \(String(describing: item.error))")
                }
            }
            
            // Add time observer
            let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                let seconds = CMTimeGetSeconds(time)
                Task { @MainActor [weak self] in
                    self?.currentTime = seconds
                }
            }
        } catch {
            print("Failed to load video: \(error)")
            player = nil
            isPlaying = false
            currentTime = 0
            duration = 0
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime)
    }
    
    deinit {
        Task { @MainActor [weak self] in
            if let observer = self?.timeObserver {
                self?.player?.removeTimeObserver(observer)
            }
            self?.statusObserver?.invalidate()
        }
    }
} 