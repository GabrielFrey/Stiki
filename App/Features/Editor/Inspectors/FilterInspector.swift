import StikiCore
import SwiftUI

struct FilterInspector: View {
    @Binding var recipe: EditRecipe
    var isPro: Bool
    var onLocked: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    GlassChip(title: "None", isSelected: recipe.filters.isEmpty) {
                        recipe.filters = []
                    }
                    ForEach(FilterSpec.Kind.allCases, id: \.self) { kind in
                        GlassChip(
                            title: kind.label,
                            isSelected: recipe.filters.contains { $0.kind == kind },
                            isLocked: kind.requiresPro && !isPro
                        ) {
                            if kind.requiresPro && !isPro {
                                onLocked()
                                return
                            }
                            if recipe.filters.contains(where: { $0.kind == kind }) {
                                recipe.filters.removeAll { $0.kind == kind }
                            } else {
                                recipe.filters.append(FilterSpec(kind: kind))
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)

            if let index = recipe.filters.indices.last {
                GlassInspectorRow(title: "Amount", systemImage: "dial.low") {
                    Slider(
                        value: Binding(
                            get: { recipe.filters[index].intensity },
                            set: { recipe.filters[index].intensity = $0 }
                        ),
                        in: 0...1
                    )
                    .accessibilityLabel("Filter intensity")
                }
            }
        }
    }
}

extension FilterSpec.Kind {
    var label: LocalizedStringKey {
        switch self {
        case .vivid: return "Vivid"
        case .mono: return "Mono"
        case .comic: return "Comic"
        case .posterize: return "Posterize"
        case .glossy: return "Glossy"
        }
    }
}
