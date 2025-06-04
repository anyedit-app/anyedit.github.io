import SwiftUI
import AVKit

@main
struct AnyEditApp: App {    
    var body: WindowGroup<AnyEditContentView> {
        WindowGroup {
            AnyEditContentView()
        }
    }
}

struct AnyEditContentView: View {
    @StateObject private var viewModel = AMVEditViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Modern dark gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.1, green: 0.1, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Modern Header with dark styling
                    VStack(spacing: 12) {
                        Text("anyedit")
                            .font(.system(size: min(36, geometry.size.width * 0.06), weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("AI-Powered Video Editor")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .background(.ultraThinMaterial)
                    )
                    
                    // Main Content Area
                    ScrollView {
                        if geometry.size.width > 800 {
                            // Wide layout - side by side
                            HStack(alignment: .top, spacing: 20) {
                                // Left Side - File Selection & Controls
                                LeftSidePanel(viewModel: viewModel)
                                    .frame(width: min(350, geometry.size.width * 0.4))
                                
                                // Right Side - Video Previews
                                RightSidePanel(viewModel: viewModel, geometry: geometry)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        } else {
                            // Narrow layout - stacked
                            VStack(spacing: 20) {
                                LeftSidePanel(viewModel: viewModel)
                                    .frame(maxWidth: .infinity)
                                
                                RightSidePanel(viewModel: viewModel, geometry: geometry)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .alert(item: Binding(
            get: { viewModel.currentError.map { ErrorWrapper(error: $0) } },
            set: { _ in viewModel.currentError = nil }
        )) { wrapper in
            Alert(
                title: Text("Error"),
                message: Text(wrapper.error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct LeftSidePanel: View {
    @ObservedObject var viewModel: AMVEditViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // File Selection Cards
            VStack(spacing: 16) {
                Text("Select Files")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                // Video Selection
                FileDropZone(
                    title: "Video File",
                    subtitle: viewModel.videoURL?.lastPathComponent ?? "Click to select or drag video file here",
                    icon: "video.circle.fill",
                    color: .blue,
                    isSelected: viewModel.videoURL != nil,
                    acceptedTypes: ["public.movie"]
                ) {
                    viewModel.selectVideoFile()
                } onDrop: { urls in
                    if let url = urls.first {
                        Task { @MainActor in
                            viewModel.videoURL = url
                            viewModel.statusMessage = "Video loaded successfully"
                        }
                    }
                }
                
                // Audio Selection
                FileDropZone(
                    title: "Audio File",
                    subtitle: viewModel.audioURL?.lastPathComponent ?? "Click to select or drag audio file here",
                    icon: "music.circle.fill",
                    color: .purple,
                    isSelected: viewModel.audioURL != nil,
                    acceptedTypes: ["public.audio"]
                ) {
                    viewModel.selectAudioFile()
                } onDrop: { urls in
                    if let url = urls.first {
                        Task { @MainActor in
                            viewModel.audioURL = url
                            viewModel.statusMessage = "Audio loaded successfully"
                            await viewModel.detectBeats(in: url)
                        }
                    }
                }
            }
            
            // Beat Visualization
            if !viewModel.beats.isEmpty {
                VStack(spacing: 12) {
                    HStack {
                        Text("Audio Beats: \(viewModel.beats.count)")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("BPM: \(Int(Double(viewModel.beats.count) * 60.0 / (viewModel.beats.last?.timestamp ?? 1)))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(viewModel.beats.prefix(100), id: \.timestamp) { beat in
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .frame(width: 3, height: CGFloat(beat.intensity * 40))
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .background(.ultraThinMaterial)
                    )
                }
            }
            
            // Create Button
            Button(action: {
                Task {
                    await viewModel.createEdit()
                }
            }) {
                HStack(spacing: 12) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .scaleEffect(0.9)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text(viewModel.isProcessing ? "Creating AI Video..." : "Create AI Video")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if viewModel.canCreateEdit {
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            LinearGradient(
                                colors: [.gray.opacity(0.6), .gray.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: viewModel.canCreateEdit ? .purple.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
            }
            .disabled(!viewModel.canCreateEdit || viewModel.isProcessing)
            .buttonStyle(ScaleButtonStyle())
            
            // Status Message
            if !viewModel.statusMessage.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.statusMessage.contains("Error") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(viewModel.statusMessage.contains("Error") ? .red : .green)
                        .font(.title3)
                    
                    Text(viewModel.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .background(.ultraThinMaterial)
                )
            }
        }
    }
}

struct RightSidePanel: View {
    @ObservedObject var viewModel: AMVEditViewModel
    let geometry: GeometryProxy
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Preview")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            let videoHeight = min(200, geometry.size.height * 0.25)
            let isWideLayout = geometry.size.width > 800
            
            if isWideLayout {
                // Vertical layout for wide screens
                VStack(spacing: 16) {
                    // Original Video (Top)
                    SafeVideoPreviewPanel(
                        title: "Original Video",
                        url: viewModel.videoURL,
                        color: .blue,
                        height: videoHeight
                    )
                    
                    // AI Edited Video (Bottom)
                    SafeVideoPreviewPanel(
                        title: "AI Edited Video",
                        url: viewModel.editedVideoURL,
                        color: .purple,
                        height: videoHeight
                    )
                }
            } else {
                // Horizontal layout for narrow screens
                HStack(spacing: 12) {
                    SafeVideoPreviewPanel(
                        title: "Original",
                        url: viewModel.videoURL,
                        color: .blue,
                        height: videoHeight
                    )
                    
                    SafeVideoPreviewPanel(
                        title: "AI Edited",
                        url: viewModel.editedVideoURL,
                        color: .purple,
                        height: videoHeight
                    )
                }
            }
        }
    }
}

// Custom button style for scaling effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Interactive file drop zone with modern design
struct FileDropZone: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let acceptedTypes: [String]
    let onTap: () -> Void
    let onDrop: ([URL]) -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        isSelected ? 
                        LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom) :
                        LinearGradient(colors: [.white.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    )
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isHovering ? color.opacity(0.3) :
                        isSelected ? color.opacity(0.2) : 
                        Color.white.opacity(0.08)
                    )
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isHovering ? color.opacity(0.8) :
                                isSelected ? color.opacity(0.6) : 
                                Color.white.opacity(0.2), 
                                lineWidth: isHovering ? 3 : 2
                            )
                            .animation(.easeInOut(duration: 0.2), value: isHovering)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .onDrop(of: acceptedTypes, isTargeted: $isHovering) { providers in
            Task {
                for provider in providers {
                    if let url = await loadURL(from: provider) {
                        onDrop([url])
                        return true
                    }
                }
                return false
            }
            return true
        }
    }
    
    private func loadURL(from provider: NSItemProvider) async -> URL? {
        return await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

// Safe video preview panel that won't crash
struct SafeVideoPreviewPanel: View {
    let title: String
    let url: URL?
    let color: Color
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if url != nil {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Ready")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [color.opacity(0.6), color.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ), 
                                lineWidth: 2
                            )
                    )
                
                if let videoURL = url {
                    // Safe video preview with thumbnail
                    VStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [color, color.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(spacing: 4) {
                            Text("Video Loaded")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            Text(videoURL.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("▶ Play") {
                            // Open in QuickTime or default player
                            NSWorkspace.shared.open(videoURL)
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color.opacity(0.3))
                        )
                        .buttonStyle(ScaleButtonStyle())
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: title.contains("Original") ? "video.fill" : "sparkles.tv.fill")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [color.opacity(0.6), color.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text(title.contains("Original") ? "No Video Selected" : "AI Video Will Appear Here")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(height: height)
        }
        .frame(maxWidth: .infinity)
    }
} 