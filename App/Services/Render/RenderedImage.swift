import CoreGraphics
import Foundation
import StikiCore

/// One rasterised sticker, ready to persist or hand off.
///
/// The library stores this as the cache of the last render. The exporter
/// produces a new one per target, because WhatsApp, Telegram and iMessage
/// disagree on canvas, format and byte budget.
struct RenderedImage: Hashable, Sendable {
    var data: Data
    var pixelSize: PixelSize
    var format: StickerFormat
    var frameCount: Int
    var frameDurationMilliseconds: Int

    init(
        data: Data,
        pixelSize: PixelSize,
        format: StickerFormat,
        frameCount: Int = 1,
        frameDurationMilliseconds: Int = 0
    ) {
        self.data = data
        self.pixelSize = pixelSize
        self.format = format
        self.frameCount = max(1, frameCount)
        self.frameDurationMilliseconds = max(0, frameDurationMilliseconds)
    }

    var isAnimated: Bool { frameCount > 1 || format.isAnimated }
    var byteCount: Int { data.count }

    func asStickerSpec(id: UUID, name: String, emojiTags: [String]) -> StickerSpec {
        StickerSpec(
            id: id,
            name: name,
            pixelSize: pixelSize,
            byteCount: byteCount,
            format: format,
            emojiTags: emojiTags,
            frameCount: frameCount,
            frameDurationMilliseconds: frameDurationMilliseconds
        )
    }
}

/// One decoded animation frame the renderer can restamp with a recipe.
struct SourceFrame: Sendable {
    var image: CGImage
    var timestampSeconds: Double
}
