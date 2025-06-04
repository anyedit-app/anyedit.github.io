import SwiftUI
import Combine

class EffectsViewModel: ObservableObject {
    @Published var availableEffects: [any AIEffect]
    @Published var selectedEffect: (any AIEffect)? {
        didSet {
            if let effect = selectedEffect {
                currentParameters = effect.parameters
            } else {
                currentParameters = [:]
            }
        }
    }
    @Published var currentParameters: [String: Any] = [:]
    
    init() {
        self.availableEffects = []
        Task { @MainActor in
            self.availableEffects = [
                StyleTransferEffect(),
                BeatSyncEffect()
            ]
        }
    }
    
    func updateParameter(_ key: String, value: Any) {
        currentParameters[key] = value
        if var effect = selectedEffect {
            effect.parameters = currentParameters
            selectedEffect = effect
        }
    }
    
    func resetParameters() {
        if let effect = selectedEffect {
            currentParameters = effect.defaultParameters
            updateParameter("", value: "") // Trigger update
        }
    }
    
    func validateParameters() async -> Bool {
        guard let effect = selectedEffect else { return false }
        return await effect.validateParameters()
    }
} 