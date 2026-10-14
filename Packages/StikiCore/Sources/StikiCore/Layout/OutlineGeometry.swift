import Foundation

/// Pixel geometry for the sticker border and shadow.
///
/// The renderer dilates the subject mask to build an outline, so it needs to
/// know how many pixels to grow by at the current resolution — and how much of
/// the canvas to keep free so the grown mask is not clipped at the edge.
public enum OutlineGeometry {
    /// Radius, in pixels, to dilate the mask by for a given outline width.
    public static func dilationRadius(
        relativeWidth: Double,
        canvas: PixelSize
    ) -> Double {
        guard !canvas.isEmpty else { return 0 }
        let clamped = min(max(relativeWidth, 0), 0.25)
        return clamped * Double(canvas.shortestSide)
    }

    /// Blur radius for the outline's soft edge. Glow outlines bloom well past
    /// their nominal width, which is what makes them read as light.
    public static func featherRadius(
        for outline: OutlineSpec,
        canvas: PixelSize
    ) -> Double {
        let base = max(0, outline.feather) * Double(canvas.shortestSide)
        switch outline.style {
        case .solid, .dashed:
            return base
        case .glow:
            return max(base, dilationRadius(relativeWidth: outline.sanitizedRelativeWidth, canvas: canvas) * 0.9)
        case .puffy:
            return max(base, Double(canvas.shortestSide) * 0.006)
        }
    }

    /// Shadow offset in pixels for the current canvas.
    public static func shadowOffset(
        for shadow: DropShadowSpec,
        canvas: PixelSize
    ) -> (x: Double, y: Double) {
        (x: shadow.offset.x * Double(canvas.width), y: shadow.offset.y * Double(canvas.height))
    }

    public static func shadowBlurRadius(
        for shadow: DropShadowSpec,
        canvas: PixelSize
    ) -> Double {
        max(0, shadow.blur) * Double(canvas.shortestSide)
    }

    /// Fraction of the canvas to reserve on each side so the outline, its
    /// feather and the shadow all stay inside the frame.
    public static func safePaddingFraction(
        outline: OutlineSpec?,
        shadow: DropShadowSpec?
    ) -> Double {
        var padding = 0.015
        if let outline {
            let width = outline.sanitizedRelativeWidth
            let feather = max(0, outline.feather)
            padding += width + feather
            if outline.style == .glow {
                padding += width * 0.9
            }
            if outline.style == .puffy {
                padding += width * 0.5
            }
        }
        if let shadow {
            let reach = max(abs(shadow.offset.x), abs(shadow.offset.y)) + max(0, shadow.blur)
            padding = max(padding, padding * 0.5 + reach)
        }
        return min(padding, 0.4)
    }

    /// Dash pattern for ``OutlineSpec/Style/dashed``, in pixels.
    public static func dashPattern(
        relativeWidth: Double,
        canvas: PixelSize
    ) -> [Double] {
        let unit = max(1, dilationRadius(relativeWidth: relativeWidth, canvas: canvas))
        return [unit * 1.6, unit * 1.1]
    }

    /// Corner radius used when the user keeps the whole image (meme mode).
    public static func memeModeCornerRadius(canvas: PixelSize) -> Double {
        Double(canvas.shortestSide) * 0.08
    }
}
