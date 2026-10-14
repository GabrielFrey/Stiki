import Foundation

/// A stable reference to a file inside the app's asset store.
///
/// Recipes never embed pixels. They point at immutable originals so a sticker
/// can be re-edited forever without generation loss — the non-destructive
/// guarantee that competitors break once a sticker joins a pack.
public struct AssetRef: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        /// A still image (PNG/JPEG/HEIC) stored in the asset store.
        case image
        /// A movie used as the source of an animated sticker.
        case video
        /// The paired video of a Live Photo.
        case livePhotoVideo
        /// An 8-bit grayscale PNG mask, white = keep.
        case mask
    }

    /// File name inside the asset store directory, e.g. `A1B2-source.png`.
    public var fileName: String
    public var kind: Kind
    /// Pixel size of the referenced asset, cached to avoid decoding the file
    /// just to lay out the editor canvas.
    public var pixelSize: PixelSize

    public init(fileName: String, kind: Kind, pixelSize: PixelSize) {
        self.fileName = fileName
        self.kind = kind
        self.pixelSize = pixelSize
    }

    public var id: String { fileName }
}

/// Raster formats the app can read or write.
public enum StickerFormat: String, Codable, Hashable, Sendable, CaseIterable {
    case png
    case apng
    case gif
    case webp
    case animatedWebP
    case webm

    public var isAnimated: Bool {
        switch self {
        case .png, .webp:
            return false
        case .apng, .gif, .animatedWebP, .webm:
            return true
        }
    }

    public var fileExtension: String {
        switch self {
        case .png, .apng:
            return "png"
        case .gif:
            return "gif"
        case .webp, .animatedWebP:
            return "webp"
        case .webm:
            return "webm"
        }
    }

    /// Uniform type identifier, or `nil` for formats without a system UTI
    /// (WebM has no ImageIO representation on iOS).
    public var uniformTypeIdentifier: String? {
        switch self {
        case .png, .apng:
            return "public.png"
        case .gif:
            return "com.compuserve.gif"
        case .webp, .animatedWebP:
            return "org.webmproject.webp"
        case .webm:
            return nil
        }
    }

    public var displayName: String {
        switch self {
        case .png: return "PNG"
        case .apng: return "APNG"
        case .gif: return "GIF"
        case .webp: return "WebP"
        case .animatedWebP: return "Animated WebP"
        case .webm: return "WebM"
        }
    }
}
