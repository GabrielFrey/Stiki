import CoreGraphics
import CoreImage
import Foundation
import StikiCore
import os

/// Recipe → pixels, off the main actor.
///
/// One Metal-backed `CIContext` is cached for the lifetime of the service so
/// live editor previews can hold 60 fps without rebuilding a GPU context per
/// frame. Inputs are `Data` (or already-decoded `CGImage`) so the actor never
/// has to borrow UIKit types.
actor RenderService {
    private let ciContext: CIContext
    private let logger = Logger(subsystem: "com.stiki.app", category: "Render")

    init() {
        ciContext = CIContext(options: [
            .useSoftwareRenderer: false,
            .cacheIntermediates: true,
            .priorityRequestLow: false
        ])
    }

    /// Renders a still sticker at `canvas`.
    func render(
        recipe: EditRecipe,
        source: CGImage,
        mask: CGImage?,
        canvas: PixelSize
    ) throws -> CGImage {
        try Task.checkCancellation()
        let overlay = TextLayerRenderer(canvas: canvas)
            .render(textLayers: recipe.textLayers, emojiLayers: recipe.emojiLayers)
        let pipeline = RecipePipeline(recipe: recipe, canvas: canvas)
        let output = pipeline.composite(source: source, mask: mask, overlay: overlay)
        return try rasterize(output, canvas: canvas)
    }

    /// Renders and encodes a still sticker, walking the compression ladder
    /// when a byte budget is supplied.
    func renderStill(
        recipe: EditRecipe,
        sourceData: Data,
        maskData: Data?,
        canvas: PixelSize,
        format: StickerFormat,
        maxBytes: Int?
    ) throws -> RenderedImage {
        let source = try ImageCoding.decode(data: sourceData)
        let mask = try maskData.map { try ImageCoding.decode(data: $0) }
        let image = try render(recipe: recipe, source: source, mask: mask, canvas: canvas)
        return try encodeStill(image, format: format, maxBytes: maxBytes, canvas: canvas)
    }

    /// Renders every animation frame with the same recipe.
    func renderFrames(
        recipe: EditRecipe,
        frames: [CGImage],
        mask: CGImage?,
        canvas: PixelSize,
        progress: (@Sendable (Double) -> Void)? = nil
    ) throws -> [CGImage] {
        let overlay = TextLayerRenderer(canvas: canvas)
            .render(textLayers: recipe.textLayers, emojiLayers: recipe.emojiLayers)
        let pipeline = RecipePipeline(recipe: recipe, canvas: canvas)
        var output: [CGImage] = []
        output.reserveCapacity(frames.count)
        for (index, frame) in frames.enumerated() {
            try Task.checkCancellation()
            output.append(try rasterize(
                pipeline.composite(source: frame, mask: mask, overlay: overlay),
                canvas: canvas
            ))
            progress?(Double(index + 1) / Double(max(frames.count, 1)))
        }
        return output
    }

    /// Encodes a still image, optionally shrinking quality (and, where the
    /// canvas rule allows, pixels) until `maxBytes` is met.
    func encodeStill(
        _ image: CGImage,
        format: StickerFormat,
        maxBytes: Int?,
        canvas: PixelSize
    ) throws -> RenderedImage {
        let attempts = CompressionPlan.attempts(
            canvas: .maxLongestSide(max(canvas.longestSide, 1)),
            baseSize: canvas,
            isAnimated: false
        )
        // The first attempt is always the requested canvas at top quality.
        // Subsequent attempts only run when a budget is in play.
        var last: RenderedImage?
        let ladder = maxBytes == nil
            ? [CompressionAttempt(pixelSize: canvas, quality: 1)]
            : attempts

        for attempt in ladder {
            try Task.checkCancellation()
            let pixels = try ImageCoding.resized(image, to: attempt.pixelSize)
            let data = try ImageCoding.encode(pixels, as: format, quality: attempt.quality)
            let encoded = RenderedImage(data: data, pixelSize: attempt.pixelSize, format: format)
            last = encoded
            if let maxBytes, data.count > maxBytes { continue }
            return encoded
        }

        guard let last else { throw StikiError.imageEncodingFailed(format) }
        if let maxBytes, last.byteCount > maxBytes {
            throw StikiError.sizeLimitUnreachable(
                achievedBytes: last.byteCount,
                limitBytes: maxBytes
            )
        }
        return last
    }

    /// Encodes an animation, thinning frames and dropping quality until the
    /// budget is met. Dimensions stay put for exact-canvas targets.
    func encodeAnimation(
        frames: [CGImage],
        format: StickerFormat,
        frameDurationMilliseconds: Int,
        canvas: PixelSize,
        maxBytes: Int?,
        canvasRule: CanvasRule
    ) throws -> RenderedImage {
        guard !frames.isEmpty else { throw StikiError.frameExtractionFailed }
        let attempts = CompressionPlan.attempts(
            canvas: canvasRule,
            baseSize: canvas,
            isAnimated: true,
            frameCount: frames.count
        )
        var last: RenderedImage?

        for attempt in attempts {
            try Task.checkCancellation()
            let sampled = stride(from: 0, to: frames.count, by: attempt.frameStride)
                .compactMap { frames[$0] }
            let resized = try sampled.map { try ImageCoding.resized($0, to: attempt.pixelSize) }
            let duration = CompressionPlan.frameDuration(
                frameDurationMilliseconds,
                stride: attempt.frameStride,
                minimumMilliseconds: 8
            )
            let data = try ImageCoding.encodeAnimation(
                frames: resized,
                as: format,
                frameDurationMilliseconds: duration,
                quality: attempt.quality
            )
            let encoded = RenderedImage(
                data: data,
                pixelSize: attempt.pixelSize,
                format: format,
                frameCount: resized.count,
                frameDurationMilliseconds: duration
            )
            last = encoded
            if let maxBytes, data.count > maxBytes { continue }
            return encoded
        }

        guard let last else { throw StikiError.imageEncodingFailed(format) }
        if let maxBytes, last.byteCount > maxBytes {
            throw StikiError.sizeLimitUnreachable(
                achievedBytes: last.byteCount,
                limitBytes: maxBytes
            )
        }
        return last
    }

    /// 96×96 PNG tray icon, padded and downscaled from a sticker.
    func trayIcon(from image: CGImage, maxBytes: Int) throws -> RenderedImage {
        let size = PixelSize.square(96)
        let padded = try ImageCoding.resized(image, to: size)
        return try encodeStill(padded, format: .png, maxBytes: maxBytes, canvas: size)
    }

    private func rasterize(_ image: CIImage, canvas: PixelSize) throws -> CGImage {
        let rect = CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
        guard let cgImage = ciContext.createCGImage(
            image,
            from: rect,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        ) else {
            logger.error("CIContext failed to rasterize")
            throw StikiError.renderFailed("rasterize")
        }
        return cgImage
    }
}
