import SwiftUI

/// A circular glass button for a single SF Symbol.
///
/// Used in floating toolbars, where a label would not fit but VoiceOver still
/// needs one — the symbol name is never the label.
struct GlassIconButton: View {
    var systemImage: String
    var label: LocalizedStringKey
    var hint: LocalizedStringKey?
    var isSelected: Bool = false
    var tint: Color?
    /// Morph identity, so the button can merge with its neighbours when the
    /// palette expands or collapses.
    var morphID: String?
    var morphNamespace: Namespace.ID?
    var action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 46

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(width: side, height: side)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .stikiGlass(glass, in: Circle())
        .modifier(GlassMorphIdentity(id: morphID, namespace: morphNamespace))
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var glass: Glass {
        let base: Glass = isSelected ? .regular.tint(tint ?? .accentColor) : .regular
        return base.interactive()
    }

    private var foreground: AnyShapeStyle {
        guard isSelected else { return AnyShapeStyle(HierarchicalShapeStyle.primary) }
        // A tinted glass capsule is dark enough for white glyphs, but the
        // opaque Reduce Transparency fallback is not.
        return reduceTransparency
            ? AnyShapeStyle(tint ?? Color.accentColor)
            : AnyShapeStyle(Color.white)
    }
}

/// A glass pill with an icon and a title, for destinations and actions that
/// need to say what they do.
struct GlassActionButton: View {
    var systemImage: String
    var title: LocalizedStringKey
    var isProminent: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: GlassMetrics.controlHeight)
        }
        .buttonStyle(.glass)
        .modifier(ProminentGlassButton(isProminent: isProminent))
    }
}

/// Promotes a button to `.glassProminent`, which the design system reserves
/// for the single primary action on a screen.
private struct ProminentGlassButton: ViewModifier {
    var isProminent: Bool

    func body(content: Content) -> some View {
        if isProminent {
            content.buttonStyle(.glassProminent)
        } else {
            content
        }
    }
}

#Preview("Icon buttons") {
    ZStack {
        LinearGradient(colors: [.purple, .orange], startPoint: .top, endPoint: .bottom)
        GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
            HStack(spacing: GlassMetrics.paletteSpacing) {
                GlassIconButton(
                    systemImage: "scissors",
                    label: "Cut out subject",
                    hint: "Lifts the subject out of the photo"
                ) {}
                GlassIconButton(
                    systemImage: "textformat",
                    label: "Add text",
                    isSelected: true
                ) {}
                GlassIconButton(systemImage: "wand.and.stars", label: "Filters") {}
            }
        }
    }
    .ignoresSafeArea()
}
