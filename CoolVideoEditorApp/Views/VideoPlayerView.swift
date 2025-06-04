import SwiftUI
import AVFoundation

struct VideoPlayerView: NSViewRepresentable {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.player = viewModel.player
        return view
    }
    
    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        nsView.player = viewModel.player
    }
}

// Custom NSView that uses AVPlayerLayer
class PlayerContainerView: NSView {
    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
    
    private var playerLayer: AVPlayerLayer!
    
    init() {
        super.init(frame: .zero)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        
        playerLayer = AVPlayerLayer()
        playerLayer.videoGravity = .resizeAspect
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(playerLayer)
    }
    
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}

struct VideoPlayerControlsView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    var body: some View {
        HStack {
            // Play/Pause Button
            Button(action: {
                if viewModel.isPlaying {
                    viewModel.pause()
                } else {
                    viewModel.play()
                }
            }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .disabled(viewModel.player == nil)
            
            // Time Slider
            Slider(
                value: Binding(
                    get: { viewModel.currentTime },
                    set: { viewModel.seek(to: $0) }
                ),
                in: 0...max(viewModel.duration, 1)
            )
            .disabled(viewModel.player == nil)
            
            // Time Label
            Text(formatTime(viewModel.currentTime) + " / " + formatTime(viewModel.duration))
                .font(.caption)
                .monospacedDigit()
        }
        .padding(.horizontal)
    }
    
    func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct VideoPlayerContainerView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let title: String
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.vertical, 8)
            
            VideoPlayerView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VideoPlayerControlsView(viewModel: viewModel)
                .padding(.vertical, 8)
        }
        .background(Color(.windowBackgroundColor))
        .cornerRadius(8)
    }
} 