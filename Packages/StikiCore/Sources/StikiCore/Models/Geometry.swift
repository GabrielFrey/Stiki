import Foundation

/// Integer pixel dimensions of a raster image.
///
/// `StikiCore` deliberately avoids CoreGraphics so that every rule in this
/// package (export limits, fitting math, recipe coding) can be unit tested on
/// any platform, including Linux CI.
public struct PixelSize: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// A square size, the shape every messenger sticker format expects.
    public static func square(_ side: Int) -> PixelSize {
        PixelSize(width: side, height: side)
    }

    public var longestSide: Int { max(width, height) }
    public var shortestSide: Int { min(width, height) }
    public var isSquare: Bool { width == height }
    public var isEmpty: Bool { width <= 0 || height <= 0 }

    /// Width divided by height, or `1` for degenerate sizes.
    public var aspectRatio: Double {
        guard width > 0, height > 0 else { return 1 }
        return Double(width) / Double(height)
    }

    public var pixelCount: Int { max(0, width) * max(0, height) }
}

extension PixelSize: CustomStringConvertible {
    public var description: String { "\(width)×\(height)" }
}

/// A normalised point in a sticker canvas, where `(0, 0)` is the top-left
/// corner and `(1, 1)` is the bottom-right corner.
///
/// Normalised coordinates keep an ``EditRecipe`` resolution independent: the
/// same recipe renders correctly at 512 px for WhatsApp and at 618 pt for a
/// large iMessage sticker.
public struct UnitPoint2D: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let center = UnitPoint2D(x: 0.5, y: 0.5)

    /// Clamps both components into `0...1`.
    public func clampedToUnitSquare() -> UnitPoint2D {
        UnitPoint2D(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }
}

/// A resolution independent, premultiplied-free sRGB colour.
public struct RecipeColor: Codable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let white = RecipeColor(red: 1, green: 1, blue: 1)
    public static let black = RecipeColor(red: 0, green: 0, blue: 0)
    public static let clear = RecipeColor(red: 0, green: 0, blue: 0, alpha: 0)

    /// Relative luminance per WCAG 2.1, used to pick readable text over glass.
    public var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}

/// Position, scale and rotation of a layer inside the sticker canvas.
public struct LayerTransform: Codable, Hashable, Sendable {
    /// Centre of the layer in normalised canvas coordinates.
    public var position: UnitPoint2D
    /// Uniform scale, `1` meaning "fit the canvas".
    public var scale: Double
    /// Clockwise rotation in radians.
    public var rotation: Double
    public var isFlippedHorizontally: Bool

    public init(
        position: UnitPoint2D = .center,
        scale: Double = 1,
        rotation: Double = 0,
        isFlippedHorizontally: Bool = false
    ) {
        self.position = position
        self.scale = scale
        self.rotation = rotation
        self.isFlippedHorizontally = isFlippedHorizontally
    }

    public static let identity = LayerTransform()

    /// Scale clamped to the range the editor exposes, so a corrupt or
    /// hand-edited recipe can never produce a zero-sized or absurd layer.
    public var sanitizedScale: Double { min(max(scale, 0.05), 8) }
}
