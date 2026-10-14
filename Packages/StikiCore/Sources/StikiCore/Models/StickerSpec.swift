import Foundation

/// A rendered sticker described purely in terms the validator cares about.
///
/// The app builds one of these from a stored sticker plus the bytes it just
/// rendered; the validator never touches pixels.
public struct StickerSpec: Hashable, Sendable, Identifiable {
    public var id: UUID
    /// Shown in validator rows so the user knows which sticker to fix.
    public var name: String
    public var pixelSize: PixelSize
    public var byteCount: Int
    public var format: StickerFormat
    /// Emoji the messenger associates with the sticker for search.
    public var emojiTags: [String]
    /// `1` for a still sticker.
    public var frameCount: Int
    public var frameDurationMilliseconds: Int

    public init(
        id: UUID = UUID(),
        name: String = "",
        pixelSize: PixelSize,
        byteCount: Int,
        format: StickerFormat,
        emojiTags: [String] = [],
        frameCount: Int = 1,
        frameDurationMilliseconds: Int = 0
    ) {
        self.id = id
        self.name = name
        self.pixelSize = pixelSize
        self.byteCount = byteCount
        self.format = format
        self.emojiTags = emojiTags
        self.frameCount = max(1, frameCount)
        self.frameDurationMilliseconds = max(0, frameDurationMilliseconds)
    }

    public var isAnimated: Bool { frameCount > 1 || format.isAnimated }

    public var animationDurationMilliseconds: Int {
        isAnimated ? frameCount * frameDurationMilliseconds : 0
    }
}

/// The pack cover image shipped to WhatsApp.
public struct TrayIconSpec: Hashable, Sendable {
    public var pixelSize: PixelSize
    public var byteCount: Int
    public var format: StickerFormat

    public init(pixelSize: PixelSize, byteCount: Int, format: StickerFormat) {
        self.pixelSize = pixelSize
        self.byteCount = byteCount
        self.format = format
    }
}

/// A pack prepared for one export target.
public struct PackSpec: Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var authorName: String
    public var stickers: [StickerSpec]
    public var trayIcon: TrayIconSpec?

    public init(
        id: UUID = UUID(),
        name: String,
        authorName: String = "",
        stickers: [StickerSpec],
        trayIcon: TrayIconSpec? = nil
    ) {
        self.id = id
        self.name = name
        self.authorName = authorName
        self.stickers = stickers
        self.trayIcon = trayIcon
    }

    public var containsAnimatedStickers: Bool { stickers.contains(where: \.isAnimated) }

    public var totalByteCount: Int { stickers.reduce(0) { $0 + $1.byteCount } }
}
