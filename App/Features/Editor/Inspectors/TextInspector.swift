import StikiCore
import SwiftUI

struct TextInspector: View {
    @Binding var recipe: EditRecipe
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Caption")
                .font(.headline)
            TextField("Say something", text: $draft)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .onSubmit(add)
                .environment(\.layoutDirection, .leftToRight)
                // Captions can be Hebrew or English; the field follows the
                // system direction, but we force LTR only for the placeholder
                // measurement. The actual text respects the characters.

            HStack {
                Button("Add") { add() }
                    .buttonStyle(.glassProminent)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ForEach(TextLayer.Curve.allCases, id: \.self) { curve in
                    GlassChip(
                        title: curve.label,
                        isSelected: recipe.textLayers.last?.curve == curve
                    ) {
                        if !recipe.textLayers.isEmpty {
                            recipe.textLayers[recipe.textLayers.count - 1].curve = curve
                        }
                    }
                }
            }

            ForEach(recipe.textLayers) { layer in
                HStack {
                    Text(layer.text)
                        .lineLimit(1)
                    Spacer()
                    Button(role: .destructive) {
                        recipe.textLayers.removeAll { $0.id == layer.id }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete caption")
                }
            }
        }
    }

    private func add() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recipe.textLayers.append(TextLayer(text: trimmed))
        draft = ""
    }
}

extension TextLayer.Curve {
    var label: LocalizedStringKey {
        switch self {
        case .straight: return "Straight"
        case .arcUp: return "Arc up"
        case .arcDown: return "Arc down"
        }
    }
}
