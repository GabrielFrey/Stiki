import Foundation
import StikiCore

/// Encodes WebP so the rest of the exporter does not care which backend won.
///
/// ImageIO writes WebP on current iOS releases, but that has not always been
/// true, so capability is probed at runtime via
/// `CGImageDestinationCopyTypeIdentifiers()`. If writing is unavailable the
/// exporter falls back to PNG (static) or GIF (animated) and the UI tells the
/// user. A `libwebp` SPM wrapper can replace this type without touching
/// call sites.
protocol WebPEncoding: Sendable {
    var canEncodeStatic: Bool { get }
    var canEncodeAnimated: Bool { get }
    func encodeStatic(_ image: CGImage, quality: Double) throws -> Data
    func encodeAnimated(
        frames: [CGImage],
        frameDurationMilliseconds: Int,
        quality: Double
    ) throws -> Data
}

/// ImageIO-backed WebP encoder.
struct ImageIOWebPEncoder: WebPEncoding {
    var canEncodeStatic: Bool { ImageCoding.canWrite(.webp) }
    var canEncodeAnimated: Bool { ImageCoding.canWrite(.animatedWebP) }

    func encodeStatic(_ image: CGImage, quality: Double) throws -> Data {
        try ImageCoding.encode(image, as: .webp, quality: quality)
    }

    func encodeAnimated(
        frames: [CGImage],
        frameDurationMilliseconds: Int,
        quality: Double
    ) throws -> Data {
        try ImageCoding.encodeAnimation(
            frames: frames,
            as: .animatedWebP,
            frameDurationMilliseconds: frameDurationMilliseconds,
            quality: quality
        )
    }
}
