import SwiftUI

struct MainView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    
    var body: some View {
        HSplitView {
            // Left side: Effects Panel
            EffectsSelectionView(
                viewModel: mainViewModel.effectsViewModel,
                onEffectSelected: { effect in
                    mainViewModel.selectedAIEffect = effect
                }
            )
            
            // Right side: Video Players and Controls
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Original Video
                    VideoPlayerContainerView(
                        viewModel: mainViewModel.videoPlayerViewModel,
                        title: "Original Video"
                    )
                    
                    // Processed Video
                    VideoPlayerContainerView(
                        viewModel: mainViewModel.processedVideoPlayerViewModel,
                        title: "Processed Video"
                    )
                }
                .frame(maxHeight: .infinity)
                
                // Bottom Controls
                VStack(spacing: 8) {
                    // Import/Export Buttons
                    HStack {
                        Button("Import Video") {
                            mainViewModel.importVideo()
                        }
                        
                        Spacer()
                        
                        if mainViewModel.processedVideoURL != nil {
                            Button("Export Video") {
                                mainViewModel.exportVideo()
                            }
                        }
                    }
                    
                    // Apply Effect Button & Progress
                    HStack {
                        Button("Apply Effect") {
                            mainViewModel.applySelectedEffect()
                        }
                        .disabled(mainViewModel.originalVideoURL == nil || 
                                mainViewModel.selectedAIEffect == nil ||
                                mainViewModel.isProcessing)
                        
                        if mainViewModel.isProcessing {
                            ProgressView(value: mainViewModel.processingProgress)
                                .progressViewStyle(.linear)
                        }
                    }
                }
                .padding()
            }
            .padding()
        }
        .alert(item: Binding(
            get: { mainViewModel.currentError.map { ErrorWrapper(error: $0) } },
            set: { _ in mainViewModel.currentError = nil }
        )) { wrapper in
            Alert(
                title: Text("Error"),
                message: Text(wrapper.error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// Helper to make AppError work with Alert
struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: AppError
} 