import Foundation
import StikiCore

/// Builders that produce specs which pass validation, so each test can break
/// exactly one rule and assert on exactly one issue.
enum Fixtures {
    static func whatsAppReadySticker(
        id: UUID = UUID(),
        name: String = "Sticker",
        byteCount: Int = 42_000,
        emojiTags: [String] = ["😀"]
    ) -> StickerSpec {
        StickerSpec(
            id: id,
            name: name,
            pixelSize: .square(512),
            byteCount: byteCount,
            format: .webp,
            emojiTags: emojiTags
        )
    }

    static func whatsAppReadyPack(
        stickerCount: Int = 3,
        name: String = "Cats"
    ) -> PackSpec {
        PackSpec(
            name: name,
            authorName: "GlassStickers",
            stickers: (0..<stickerCount).map { index in
                whatsAppReadySticker(name: "Sticker \(index + 1)")
            },
            trayIcon: TrayIconSpec(pixelSize: .square(96), byteCount: 18_000, format: .png)
        )
    }

    static func animatedSticker(
        frameCount: Int = 24,
        frameDurationMilliseconds: Int = 42,
        byteCount: Int = 320_000,
        format: StickerFormat = .animatedWebP
    ) -> StickerSpec {
        StickerSpec(
            name: "Animated",
            pixelSize: .square(512),
            byteCount: byteCount,
            format: format,
            emojiTags: ["✨"],
            frameCount: frameCount,
            frameDurationMilliseconds: frameDurationMilliseconds
        )
    }

    static func recipe(
        mask: Bool = true,
        animated: Bool = false
    ) -> EditRecipe {
        EditRecipe(
            source: AssetRef(
                fileName: "source.png",
                kind: .image,
                pixelSize: PixelSize(width: 1600, height: 1200)
            ),
            mask: mask
                ? AssetRef(fileName: "mask.png", kind: .mask, pixelSize: PixelSize(width: 1600, height: 1200))
                : nil,
            transform: LayerTransform(position: UnitPoint2D(x: 0.52, y: 0.48), scale: 1.2, rotation: 0.1),
            outline: OutlineSpec(style: .puffy, relativeWidth: 0.05, color: .white, feather: 0.004),
            dropShadow: .default,
            filters: [FilterSpec(kind: .vivid, intensity: 0.8)],
            textLayers: [TextLayer(text: "שלום")],
            emojiLayers: [EmojiLayer(emoji: "🔥")],
            background: .solid(RecipeColor(red: 0.1, green: 0.2, blue: 0.9, alpha: 1)),
            animation: animated ? AnimationSpec(durationSeconds: 2.5, framesPerSecond: 24) : nil
        )
    }
}
