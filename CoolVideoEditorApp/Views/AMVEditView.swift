import SwiftUI
import AVKit

struct AMVEditView: View {
    @StateObject private var viewModel = AMVEditViewModel()
    @State private var showingPreview = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Modern Header
                VStack(spacing: 8) {
                    Text("anyedit")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("AI-Powered Video Editor")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                // Side-by-side Video Preview
                HStack(spacing: 1) {
                    // Original Video Panel
                    VStack(spacing: 12) {
                        Text("Original")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 2)
                                )
                            
                            if viewModel.videoURL != nil {
                                VStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("Video Loaded")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "video")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("Select Video")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 250)
                    }
                    .frame(width: geometry.size.width / 2)
                    .padding(.horizontal, 8)
                    
                    // AI Edited Video Panel
                    VStack(spacing: 12) {
                        Text("AI Edited")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.5), lineWidth: 2)
                                )
                            
                            if viewModel.editedVideoURL != nil {
                                VStack(spacing: 8) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.blue)
                                    Text("AI Video Ready")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "sparkles.tv")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("AI Video Will Appear Here")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                        .frame(height: 250)
                    }
                    .frame(width: geometry.size.width / 2)
                    .padding(.horizontal, 8)
                }
                .frame(height: 320)
                
                Divider()
                
                // Controls Section
                ScrollView {
                    VStack(spacing: 24) {
                        // File Selection Cards
                        HStack(spacing: 20) {
                            // Video Card
                            Button(action: {
                                viewModel.selectVideoFile()
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "video.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(viewModel.videoURL != nil ? .blue : .secondary)
                                    
                                    VStack(spacing: 4) {
                                        Text("Video")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(viewModel.videoURL?.lastPathComponent ?? "No video selected")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(viewModel.videoURL != nil ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(viewModel.videoURL != nil ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Audio Card
                            Button(action: {
                                viewModel.selectAudioFile()
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "music.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(viewModel.audioURL != nil ? .purple : .secondary)
                                    
                                    VStack(spacing: 4) {
                                        Text("Audio")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        Text(viewModel.audioURL?.lastPathComponent ?? "No audio selected")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(viewModel.audioURL != nil ? Color.purple.opacity(0.1) : Color(NSColor.controlBackgroundColor))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(viewModel.audioURL != nil ? Color.purple : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Beat Visualization
                        if !viewModel.beats.isEmpty {
                            VStack(spacing: 8) {
                                Text("Audio Beats Detected: \(viewModel.beats.count)")
                                    .font(.headline)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 2) {
                                        ForEach(viewModel.beats, id: \.timestamp) { beat in
                                            Rectangle()
                                                .fill(Color.blue)
                                                .frame(width: 4, height: CGFloat(beat.intensity * 30))
                                        }
                                    }
                                    .padding()
                                }
                                .frame(height: 80)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(8)
                            }
                        }
                        
                        // Create AI Video Button
                        Button(action: {
                            Task {
                                await viewModel.createEdit()
                            }
                        }) {
                            HStack(spacing: 12) {
                                if viewModel.isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                
                                Text(viewModel.isProcessing ? "Creating AI Video..." : "Create AI Video")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: viewModel.canCreateEdit ? [.blue, .purple] : [.gray],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .cornerRadius(12)
                            )
                        }
                        .disabled(!viewModel.canCreateEdit || viewModel.isProcessing)
                        .buttonStyle(PlainButtonStyle())
                        
                        // Status Message
                        if !viewModel.statusMessage.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.statusMessage.contains("Error") ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .foregroundColor(viewModel.statusMessage.contains("Error") ? .red : .green)
                                
                                Text(viewModel.statusMessage)
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
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

// Preview
struct AMVEditView_Previews: PreviewProvider {
    static var previews: some View {
        AMVEditView()
    }
} 