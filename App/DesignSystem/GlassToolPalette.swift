import SwiftUI

/// One entry in the editor's floating palette.
struct GlassTool: Identifiable, Hashable {
    var id: String
    var systemImage: String
    var label: LocalizedStringKey
    var isLocked: Bool = false
}

/// The floating editor palette: a single "+" that morphs into the tool row.
///
/// Collapsed, it keeps the canvas unobstructed; expanded, the buttons share one
/// `GlassEffectContainer` so neighbouring glass merges instead of stacking
/// (glass cannot sample glass). The expand/collapse is driven by
/// `glassEffectID(_:in:)` inside a bouncy animation, and becomes an instant
/// change under Reduce Motion.
struct GlassToolPalette: View {
    @Binding var isExpanded: Bool
    var tools: [GlassTool]
    var selectedToolID: String?
    var onSelect: (GlassTool) -> Void

    @Namespace private var morph
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
            Group {
                if isExpanded {
                    expandedPalette
                } else {
                    collapsedButton
                }
            }
        }
        .sensoryFeedback(.selection, trigger: isExpanded)
    }

    private var collapsedButton: some View {
        GlassIconButton(
            systemImage: "plus",
            label: "Show tools",
            hint: "Opens cutout, outline, text, emoji, filters and animation tools",
            morphID: Self.toggleMorphID,
            morphNamespace: morph
        ) {
            toggle()
        }
    }

    @ViewBuilder
    private var expandedPalette: some View {
        // At accessibility sizes the row cannot fit; it scrolls instead of
        // shrinking the controls below the 44 pt touch target.
        let row = HStack(spacing: GlassMetrics.paletteSpacing) {
            GlassIconButton(
                systemImage: "xmark",
                label: "Hide tools",
                morphID: Self.toggleMorphID,
                morphNamespace: morph
            ) {
                toggle()
            }

            ForEach(tools) { tool in
                GlassIconButton(
                    systemImage: tool.systemImage,
                    label: tool.label,
                    isSelected: tool.id == selectedToolID,
                    morphID: tool.id,
                    morphNamespace: morph
                ) {
                    onSelect(tool)
                }
                .overlay(alignment: .topTrailing) {
                    if tool.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .padding(4)
                            .background(.tint, in: Circle())
                            .foregroundStyle(.white)
                            .offset(x: 2, y: -2)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.horizontal, 4)

        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                row
            }
            .scrollIndicators(.hidden)
        } else {
            row
        }
    }

    private static let toggleMorphID = "palette-toggle"

    private func toggle() {
        withAnimation(.stikiMorph(reduceMotion: reduceMotion)) {
            isExpanded.toggle()
        }
    }
}

#Preview("Tool palette") {
    @Previewable @State var isExpanded = true

    return ZStack {
        LinearGradient(colors: [.orange, .pink, .purple], startPoint: .top, endPoint: .bottom)
        VStack {
            Spacer()
            GlassToolPalette(
                isExpanded: $isExpanded,
                tools: [
                    GlassTool(id: "cutout", systemImage: "scissors", label: "Cut out"),
                    GlassTool(id: "outline", systemImage: "circle.dashed", label: "Outline"),
                    GlassTool(id: "text", systemImage: "textformat", label: "Text"),
                    GlassTool(id: "emoji", systemImage: "face.smiling", label: "Emoji"),
                    GlassTool(id: "filters", systemImage: "wand.and.stars", label: "Filters", isLocked: true),
                    GlassTool(id: "animate", systemImage: "play.circle", label: "Animate", isLocked: true)
                ],
                selectedToolID: "outline",
                onSelect: { _ in }
            )
            .padding(.bottom, 32)
        }
    }
    .ignoresSafeArea()
}
