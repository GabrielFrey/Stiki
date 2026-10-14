import Foundation

/// How a target constrains the pixel dimensions of a sticker.
public enum CanvasRule: Hashable, Sendable {
    /// The image must be exactly `side × side`.
    case exactSquare(Int)
    /// The longest side must be exactly this many pixels; the other side may
    /// be smaller.
    case longestSideExactly(Int)
    /// The image must be one of these square sizes.
    case allowedSquares([Int])
    /// The image may be anything up to this longest side.
    case maxLongestSide(Int)

    public func isSatisfied(by size: PixelSize) -> Bool {
        guard !size.isEmpty else { return false }
        switch self {
        case let .exactSquare(side):
            return size.width == side && size.height == side
        case let .longestSideExactly(side):
            return size.longestSide == side
        case let .allowedSquares(sides):
            return size.isSquare && sides.contains(size.width)
        case let .maxLongestSide(side):
            return size.longestSide <= side
        }
    }

    /// The size this rule wants, preserving aspect ratio where allowed.
    public func fittedSize(for size: PixelSize) -> PixelSize {
        switch self {
        case let .exactSquare(side):
            return .square(side)
        case let .longestSideExactly(side):
            return SizeFitting.scaled(size, longestSideTo: side)
        case let .allowedSquares(sides):
            let sorted = sides.sorted()
            guard let largest = sorted.last else { return size }
            let target = sorted.first { $0 >= size.longestSide } ?? largest
            return .square(target)
        case let .maxLongestSide(side):
            guard size.longestSide > side else { return size }
            return SizeFitting.scaled(size, longestSideTo: side)
        }
    }

    /// Longest side this rule renders at, used to pick a render resolution.
    public var nominalLongestSide: Int {
        switch self {
        case let .exactSquare(side), let .longestSideExactly(side), let .maxLongestSide(side):
            return side
        case let .allowedSquares(sides):
            return sides.max() ?? 512
        }
    }
}

/// Tray (pack cover) requirements.
public struct TrayIconRule: Hashable, Sendable {
    public var size: PixelSize
    public var format: StickerFormat
    public var maxBytes: Int

    public init(size: PixelSize, format: StickerFormat, maxBytes: Int) {
        self.size = size
        self.format = format
        self.maxBytes = maxBytes
    }
}

/// The published limits of one export target.
///
/// These numbers are the whole reason the validator exists: competitors let
/// users build a pack and only fail at hand-off with "pack too large / wrong
/// dimensions". We check them up front and offer a one-tap fix.
public struct ExportLimits: Hashable, Sendable {
    public var target: ExportTarget
    public var canvas: CanvasRule
    public var staticFormats: [StickerFormat]
    public var animatedFormats: [StickerFormat]
    public var maxStaticBytes: Int
    public var maxAnimatedBytes: Int
    /// Shortest legal frame duration; below it messengers reject the file.
    public var minFrameDurationMilliseconds: Int?
    public var maxAnimationDurationMilliseconds: Int?
    public var packSizeRange: ClosedRange<Int>
    public var emojiTagsRange: ClosedRange<Int>?
    public var trayIcon: TrayIconRule?
    /// Longest pack name the target displays without truncation.
    public var maxPackNameLength: Int

    public init(
        target: ExportTarget,
        canvas: CanvasRule,
        staticFormats: [StickerFormat],
        animatedFormats: [StickerFormat],
        maxStaticBytes: Int,
        maxAnimatedBytes: Int,
        minFrameDurationMilliseconds: Int? = nil,
        maxAnimationDurationMilliseconds: Int? = nil,
        packSizeRange: ClosedRange<Int>,
        emojiTagsRange: ClosedRange<Int>? = nil,
        trayIcon: TrayIconRule? = nil,
        maxPackNameLength: Int = 128
    ) {
        self.target = target
        self.canvas = canvas
        self.staticFormats = staticFormats
        self.animatedFormats = animatedFormats
        self.maxStaticBytes = maxStaticBytes
        self.maxAnimatedBytes = maxAnimatedBytes
        self.minFrameDurationMilliseconds = minFrameDurationMilliseconds
        self.maxAnimationDurationMilliseconds = maxAnimationDurationMilliseconds
        self.packSizeRange = packSizeRange
        self.emojiTagsRange = emojiTagsRange
        self.trayIcon = trayIcon
        self.maxPackNameLength = maxPackNameLength
    }

    public func maxBytes(isAnimated: Bool) -> Int {
        isAnimated ? maxAnimatedBytes : maxStaticBytes
    }

    public func formats(isAnimated: Bool) -> [StickerFormat] {
        isAnimated ? animatedFormats : staticFormats
    }

    /// Format the exporter writes by default for this target.
    public func preferredFormat(isAnimated: Bool) -> StickerFormat {
        formats(isAnimated: isAnimated).first ?? .png
    }

    public var supportsAnimation: Bool { !animatedFormats.isEmpty }

    // MARK: - Published limits

    /// 512×512 WebP, 100 KB static / 500 KB animated, 3–30 stickers,
    /// 1–3 emoji each, 96×96 PNG tray icon under 50 KB.
    public static let whatsApp = ExportLimits(
        target: .whatsApp,
        canvas: .exactSquare(512),
        staticFormats: [.webp, .png],
        animatedFormats: [.animatedWebP],
        maxStaticBytes: 100 * 1024,
        maxAnimatedBytes: 500 * 1024,
        minFrameDurationMilliseconds: 8,
        maxAnimationDurationMilliseconds: 10_000,
        packSizeRange: 3...30,
        emojiTagsRange: 1...3,
        trayIcon: TrayIconRule(size: .square(96), format: .png, maxBytes: 50 * 1024),
        maxPackNameLength: 128
    )

    /// 512 px on the longest side, 512 KB static WebP/PNG, animated WebM
    /// capped at 256 KB and 3 seconds.
    public static let telegram = ExportLimits(
        target: .telegram,
        canvas: .longestSideExactly(512),
        staticFormats: [.webp, .png],
        animatedFormats: [.webm],
        maxStaticBytes: 512 * 1024,
        maxAnimatedBytes: 256 * 1024,
        minFrameDurationMilliseconds: nil,
        maxAnimationDurationMilliseconds: 3_000,
        packSizeRange: 1...120,
        emojiTagsRange: 1...20,
        trayIcon: nil,
        maxPackNameLength: 64
    )

    /// PNG/APNG/GIF up to 500 KB at the three sticker sizes Messages renders:
    /// 300, 408 and 618 pt.
    public static let iMessage = ExportLimits(
        target: .iMessage,
        canvas: .allowedSquares([300, 408, 618]),
        staticFormats: [.png],
        animatedFormats: [.apng, .gif],
        maxStaticBytes: 500 * 1024,
        maxAnimatedBytes: 500 * 1024,
        minFrameDurationMilliseconds: nil,
        maxAnimationDurationMilliseconds: nil,
        packSizeRange: 1...1_000,
        emojiTagsRange: nil,
        trayIcon: nil,
        maxPackNameLength: 64
    )

    /// Anything goes; kept as a target so the UI can share a full-resolution
    /// PNG or GIF without pretending there are rules.
    public static let photosAndFiles = ExportLimits(
        target: .photosAndFiles,
        canvas: .maxLongestSide(2048),
        staticFormats: [.png],
        animatedFormats: [.gif, .apng],
        maxStaticBytes: 32 * 1024 * 1024,
        maxAnimatedBytes: 32 * 1024 * 1024,
        packSizeRange: 1...1_000,
        maxPackNameLength: 255
    )

    public static func limits(for target: ExportTarget) -> ExportLimits {
        switch target {
        case .whatsApp: return .whatsApp
        case .telegram: return .telegram
        case .iMessage: return .iMessage
        case .photosAndFiles: return .photosAndFiles
        }
    }
}
