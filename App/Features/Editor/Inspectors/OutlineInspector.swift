import StikiCore
import SwiftUI

struct OutlineInspector: View {
    @Binding var recipe: EditRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Outline")
                .font(.headline)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    GlassChip(title: "None", isSelected: recipe.outline == nil) {
                        recipe.outline = nil
                    }
                    ForEach(OutlineSpec.Style.allCases, id: \.self) { style in
                        GlassChip(
                            title: style.label,
                            isSelected: recipe.outline?.style == style,
                            isLocked: style == .glow || style == .puffy
                        ) {
                            var outline = recipe.outline ?? .default
                            outline.style = style
                            recipe.outline = outline
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            if recipe.outline != nil {
                GlassInspectorRow(title: "Width", systemImage: "circle.dashed") {
                    Slider(
                        value: Binding(
                            get: { recipe.outline?.relativeWidth ?? 0.035 },
                            set: { recipe.outline?.relativeWidth = $0 }
                        ),
                        in: 0.01...0.12
                    )
                    .accessibilityLabel("Outline width")
                }
                ColorPicker(
                    "Colour",
                    selection: Binding(
                        get: { Color(recipe: recipe.outline?.color ?? .white) },
                        set: { recipe.outline?.color = $0.recipeColor }
                    ),
                    supportsOpacity: false
                )
            }
        }
    }
}

extension OutlineSpec.Style {
    var label: LocalizedStringKey {
        switch self {
        case .solid: return "Solid"
        case .glow: return "Glow"
        case .dashed: return "Dashed"
        case .puffy: return "Puffy"
        }
    }
}

extension Color {
    init(recipe: RecipeColor) {
        self.init(
            .sRGB,
            red: recipe.red,
            green: recipe.green,
            blue: recipe.blue,
            opacity: recipe.alpha
        )
    }

    var recipeColor: RecipeColor {
        let resolved = UIColor(self)
        return resolved.recipeColor
    }
}
