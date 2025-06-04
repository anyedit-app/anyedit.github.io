import SwiftUI

struct EffectsSelectionView: View {
    @ObservedObject var viewModel: EffectsViewModel
    let onEffectSelected: (any AIEffect) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Effects")
                .font(.headline)
                .padding(.horizontal)
            
            // Effects List
            List(viewModel.availableEffects, id: \.id) { effect in
                EffectRowView(
                    effect: effect,
                    isSelected: viewModel.selectedEffect?.id == effect.id,
                    onSelect: {
                        viewModel.selectedEffect = effect
                        onEffectSelected(effect)
                    }
                )
            }
            .listStyle(SidebarListStyle())
            
            // Parameters Section
            if let effect = viewModel.selectedEffect {
                ParametersView(
                    effect: effect,
                    parameters: viewModel.currentParameters,
                    onParameterChanged: viewModel.updateParameter
                )
                .padding()
            }
        }
        .frame(width: 300)
        .background(Color(.windowBackgroundColor))
    }
}

struct EffectRowView: View {
    let effect: any AIEffect
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                Text(effect.displayName)
                    .font(.headline)
                Text(effect.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ParametersView: View {
    let effect: any AIEffect
    let parameters: [String: Any]
    let onParameterChanged: (String, Any) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Parameters")
                .font(.headline)
            
            ForEach(Array(parameters.keys), id: \.self) { key in
                ParameterRowView(
                    key: key,
                    value: parameters[key],
                    description: effect.parameterDescription(for: key),
                    onChange: { onParameterChanged(key, $0) }
                )
            }
        }
    }
}

struct ParameterRowView: View {
    let key: String
    let value: Any?
    let description: String
    let onChange: (Any) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key.capitalized)
                .font(.subheadline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let doubleValue = value as? Double {
                Slider(
                    value: Binding(
                        get: { doubleValue },
                        set: { onChange($0) }
                    ),
                    in: 0...1
                )
            } else if let intValue = value as? Int {
                Stepper(
                    value: Binding(
                        get: { Double(intValue) },
                        set: { onChange(Int($0)) }
                    ),
                    in: 0...7
                ) {
                    Text("\(intValue)")
                }
            }
        }
    }
} 