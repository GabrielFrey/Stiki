import Foundation

/// Where scaled content sits inside a canvas, in pixels from the top-left.
public struct ContentPlacement: Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var size: PixelSize

    public init(x: Int, y: Int, size: PixelSize) {
        self.x = x
        self.y = y
        self.size = size
    }
}

/// Resolution math shared by the renderer, the exporter and the validator.
public enum SizeFitting {
    /// The largest size that preserves the aspect ratio of `size` and has
    /// `longestSide` as its longest edge.
    public static func scaled(_ size: PixelSize, longestSideTo longestSide: Int) -> PixelSize {
        guard !size.isEmpty, longestSide > 0 else { return .square(max(longestSide, 1)) }
        if size.width >= size.height {
            let height = Int((Double(longestSide) / size.aspectRatio).rounded())
            return PixelSize(width: longestSide, height: max(1, height))
        } else {
            let width = Int((Double(longestSide) * size.aspectRatio).rounded())
            return PixelSize(width: max(1, width), height: longestSide)
        }
    }

    /// Multiplies both edges by `factor`, never going below one pixel.
    public static func scaled(_ size: PixelSize, by factor: Double) -> PixelSize {
        guard factor > 0 else { return .square(1) }
        return PixelSize(
            width: max(1, Int((Double(size.width) * factor).rounded())),
            height: max(1, Int((Double(size.height) * factor).rounded()))
        )
    }

    /// Aspect-fits `content` inside `canvas` and centres it, optionally
    /// reserving a margin on every side for outlines and shadows.
    ///
    /// - Parameter paddingFraction: Margin as a fraction of the canvas's
    ///   shortest side, clamped to `0..<0.45`.
    public static func aspectFit(
        content: PixelSize,
        in canvas: PixelSize,
        paddingFraction: Double = 0
    ) -> ContentPlacement {
        guard !content.isEmpty, !canvas.isEmpty else {
            return ContentPlacement(x: 0, y: 0, size: canvas)
        }
        let padding = min(max(paddingFraction, 0), 0.449)
        let inset = Double(canvas.shortestSide) * padding
        let availableWidth = max(1.0, Double(canvas.width) - inset * 2)
        let availableHeight = max(1.0, Double(canvas.height) - inset * 2)
        let factor = min(availableWidth / Double(content.width), availableHeight / Double(content.height))
        let size = scaled(content, by: factor)
        return ContentPlacement(
            x: (canvas.width - size.width) / 2,
            y: (canvas.height - size.height) / 2,
            size: size
        )
    }

    /// Pads a size out to a square by growing the shorter edge, which is how
    /// stickers reach WhatsApp's mandatory 512×512 canvas without distortion.
    public static func squared(_ size: PixelSize) -> PixelSize {
        .square(max(1, size.longestSide))
    }

    /// The render resolution to use for a target: the canvas rule's nominal
    /// size, but never upscaled beyond what the source can supply plus a
    /// little headroom for downsampling quality.
    public static func renderSize(
        for canvas: CanvasRule,
        sourceSize: PixelSize,
        allowUpscaling: Bool = true
    ) -> PixelSize {
        let nominal = canvas.fittedSize(for: SizeFitting.squared(sourceSize))
        guard !allowUpscaling else { return nominal }
        let cap = sourceSize.longestSide
        guard nominal.longestSide > cap, cap > 0 else { return nominal }
        return scaled(nominal, longestSideTo: cap)
    }

    /// Longest side the import pipeline keeps, to bound Vision and CoreImage
    /// work on very large photos.
    public static let maximumProcessingSide = 2048

    /// Downscales an imported asset to ``maximumProcessingSide`` if needed.
    public static func processingSize(for size: PixelSize) -> PixelSize {
        guard size.longestSide > maximumProcessingSide else { return size }
        return scaled(size, longestSideTo: maximumProcessingSide)
    }
}
