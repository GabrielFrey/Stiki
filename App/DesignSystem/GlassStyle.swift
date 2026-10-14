import SwiftUI

/// Liquid Glass styling helpers that degrade gracefully.
///
/// Every glass surface in Stiki goes through these modifiers rather than
/// calling `glassEffect(_:in:)` directly, because two accessibility settings
/// must be honoured everywhere: Reduce Transparency (glass becomes an opaque
/// material) and Reduce Motion (morph animations become instant).
struct GlassSurface<S: Shape>: ViewModifier {
    var glass: Glass
    var shape: S

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.stroke(.separator, lineWidth: 0.5)
                }
        } else {
            content.glassEffect(glass, in: shape)
        }
    }
}

extension View {
    /// Applies a glass background in `shape`, or an opaque material when the
    /// user has asked for reduced transparency.
    ///
    /// Apply it *after* layout and appearance modifiers, as Liquid Glass
    /// samples what is behind the view at the point the effect is attached.
    func stikiGlass<S: Shape>(_ glass: Glass = .regular, in shape: S) -> some View {
        modifier(GlassSurface(glass: glass, shape: shape))
    }

    /// Capsule-shaped glass, the default for floating controls.
    func stikiGlass(_ glass: Glass = .regular) -> some View {
        modifier(GlassSurface(glass: glass, shape: Capsule()))
    }

    /// Rounded-rectangle glass, the default for panels and cards.
    func stikiGlassPanel(_ glass: Glass = .regular, cornerRadius: CGFloat = 26) -> some View {
        modifier(
            GlassSurface(
                glass: glass,
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        )
    }
}

/// Attaches a morph identity to a glass surface when one is supplied.
///
/// `glassEffectID(_:in:)` has to be applied to the same view that carries the
/// glass effect, so components take the identity as a parameter instead of
/// letting callers wrap them.
struct GlassMorphIdentity: ViewModifier {
    var id: String?
    var namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let id, let namespace {
            content.glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

extension Animation {
    /// The morph used when glass elements merge or split.
    static func stikiMorph(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .bouncy(duration: 0.38, extraBounce: 0.12)
    }

    /// The transition used when a panel's contents change.
    static func stikiPanel(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .smooth(duration: 0.26)
    }
}

/// Spacing values that keep neighbouring glass elements close enough to merge.
enum GlassMetrics {
    /// Gap inside a `GlassEffectContainer`; below this, elements blend.
    static let containerSpacing: CGFloat = 18
    static let paletteSpacing: CGFloat = 10
    static let panelCornerRadius: CGFloat = 26
    static let controlHeight: CGFloat = 52
    static let thumbnailCornerRadius: CGFloat = 18
}
