import Foundation

/// The sticker border drawn underneath the lifted subject.
public struct OutlineSpec: Codable, Hashable, Sendable {
    public enum Style: String, Codable, Hashable, Sendable, CaseIterable {
        /// Flat band of colour hugging the subject.
        case solid
        /// Soft coloured bloom, brightest at the edge.
        case glow
        /// Dashes marching along the subject contour.
        case dashed
        /// Thick band plus an offset shadow, the "sticker on paper" look.
        case puffy
    }

    public var style: Style
    /// Width as a fraction of the canvas's shortest side, so outlines keep
    /// their visual weight at every export resolution.
    public var relativeWidth: Double
    public var color: RecipeColor
    /// Edge softness in the same relative unit as ``relativeWidth``.
    public var feather: Double

    public init(
        style: Style = .solid,
        relativeWidth: Double = 0.035,
        color: RecipeColor = .white,
        feather: Double = 0.002
    ) {
        self.style = style
        self.relativeWidth = relativeWidth
        self.color = color
        self.feather = feather
    }

    /// Relative width clamped to what the renderer can draw without eating the
    /// whole canvas.
    public var sanitizedRelativeWidth: Double { min(max(relativeWidth, 0), 0.25) }

    public static let `default` = OutlineSpec()
}

/// A drop shadow cast by the subject and its outline.
public struct DropShadowSpec: Codable, Hashable, Sendable {
    public var color: RecipeColor
    /// Offset in normalised canvas units.
    public var offset: UnitPoint2D
    public var blur: Double
    public var opacity: Double

    public init(
        color: RecipeColor = .black,
        offset: UnitPoint2D = UnitPoint2D(x: 0.015, y: 0.025),
        blur: Double = 0.02,
        opacity: Double = 0.35
    ) {
        self.color = color
        self.offset = offset
        self.blur = blur
        self.opacity = opacity
    }

    public static let `default` = DropShadowSpec()
}

/// A colour treatment applied to the subject before outlining.
public struct FilterSpec: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Hashable, Sendable, CaseIterable {
        case vivid
        case mono
        case comic
        case posterize
        case glossy

        /// `true` when the effect only becomes visible for Pro users.
        public var requiresPro: Bool {
            switch self {
            case .vivid, .mono:
                return false
            case .comic, .posterize, .glossy:
                return true
            }
        }
    }

    public var id: UUID
    public var kind: Kind
    /// Effect strength in `0...1`.
    public var intensity: Double

    public init(id: UUID = UUID(), kind: Kind, intensity: Double = 1) {
        self.id = id
        self.kind = kind
        self.intensity = min(max(intensity, 0), 1)
    }
}

/// What fills the canvas behind the subject.
public enum BackgroundSpec: Codable, Hashable, Sendable {
    /// Transparent, the default for messenger stickers.
    case transparent
    case solid(RecipeColor)
    /// Keeps the untouched source image behind the subject — "meme mode",
    /// which Apple's own Live Stickers cannot do.
    case originalImage

    public var isTransparent: Bool {
        if case .transparent = self { return true }
        return false
    }
}
