import CoreGraphics
import Foundation
import ImageIO
import StikiCore
import UniformTypeIdentifiers
import os

/// ImageIO wrappers for decoding, resizing and encoding sticker images.
///
/// Decoding goes through `CGImageSourceCreateThumbnailAtIndex` with
/// `kCGImageSourceCreateThumbnailWithTransform`, which does two important
/// things at once: it bakes in the EXIF orientation (so a photo shot in
/// portrait is not cut out sideways) and it never materialises the full-size
/// bitmap of a 48-megapixel photo, keeping peak memory bounded during import.
enum ImageCoding {
    static let logger = Logger(subsystem: "com.stiki.app", category: "ImageCoding")

    // MARK: - Decoding

    /// Decodes image data, applying EXIF orientation and downscaling so the
    /// longest side is at most `maxPixelSide`.
    static func decodeNormalized(data: Data, maxPixelSide: Int) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw StikiError.imageDecodingFailed
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSide),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw StikiError.imageDecodingFailed
        }
        return image
    }

    /// Decodes data the app wrote itself (masks, rendered stickers), where the
    /// orientation is already identity and the full resolution is wanted.
    static func decode(data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw StikiError.imageDecodingFailed
        }
        return image
    }

    /// Reads the pixel size of image data without decoding the pixels.
    static func pixelSize(ofData data: Data) -> PixelSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }
        // Orientations 5-8 swap the stored width and height.
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let isRotated = (5...8).contains(orientation)
        return isRotated
            ? PixelSize(width: height, height: width)
            : PixelSize(width: width, height: height)
    }

    // MARK: - Resizing

    /// Redraws `image` at `size` in premultiplied sRGB, preserving alpha.
    static func resized(_ image: CGImage, to size: PixelSize) throws -> CGImage {
        guard !size.isEmpty else { throw StikiError.renderFailed("empty target size") }
        if image.width == size.width && image.height == size.height { return image }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: size.width,
                height: size.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw StikiError.renderFailed("bitmap context")
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        guard let resized = context.makeImage() else {
            throw StikiError.renderFailed("resize")
        }
        return resized
    }

    // MARK: - Capability probing

    /// Formats this device can actually write, probed once at first use.
    ///
    /// WebP encoding is the reason this exists: it is present on current iOS
    /// releases but has not always been, so the exporter asks instead of
    /// assuming and silently producing an empty file.
    static let writableTypeIdentifiers: Set<String> = {
        let identifiers = CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []
        return Set(identifiers)
    }()

    static func canWrite(_ format: StickerFormat) -> Bool {
        guard let identifier = format.uniformTypeIdentifier else { return false }
        return writableTypeIdentifiers.contains(identifier)
    }

    // MARK: - Encoding

    /// Encodes a still image.
    ///
    /// - Parameter quality: Lossy quality in `0...1`, ignored for PNG.
    static func encode(_ image: CGImage, as format: StickerFormat, quality: Double = 1) throws -> Data {
        guard let identifier = format.uniformTypeIdentifier, canWrite(format) else {
            throw StikiError.formatNotSupportedByDevice(format)
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            identifier as CFString,
            1,
            nil
        ) else {
            throw StikiError.imageEncodingFailed(format)
        }
        var properties: [CFString: Any] = [:]
        if format != .png && format != .apng {
            properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1)
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw StikiError.imageEncodingFailed(format)
        }
        return output as Data
    }

    /// Encodes an animation as APNG, GIF or animated WebP.
    static func encodeAnimation(
        frames: [CGImage],
        as format: StickerFormat,
        frameDurationMilliseconds: Int,
        loopForever: Bool = true,
        quality: Double = 0.85
    ) throws -> Data {
        guard !frames.isEmpty else { throw StikiError.frameExtractionFailed }
        guard let identifier = format.uniformTypeIdentifier, canWrite(format) else {
            throw StikiError.formatNotSupportedByDevice(format)
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            identifier as CFString,
            frames.count,
            nil
        ) else {
            throw StikiError.imageEncodingFailed(format)
        }

        let seconds = Double(max(1, frameDurationMilliseconds)) / 1000
        let loopCount = loopForever ? 0 : 1
        CGImageDestinationSetProperties(
            destination,
            containerProperties(for: format, loopCount: loopCount) as CFDictionary
        )

        for frame in frames {
            var properties = frameProperties(for: format, seconds: seconds)
            if format != .apng {
                properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1)
            }
            CGImageDestinationAddImage(destination, frame, properties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw StikiError.imageEncodingFailed(format)
        }
        return output as Data
    }

    private static func containerProperties(for format: StickerFormat, loopCount: Int) -> [CFString: Any] {
        switch format {
        case .gif:
            return [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loopCount]]
        case .apng, .png:
            return [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: loopCount]]
        case .animatedWebP, .webp:
            return [kCGImagePropertyWebPDictionary: [kCGImagePropertyWebPLoopCount: loopCount]]
        case .webm:
            return [:]
        }
    }

    private static func frameProperties(for format: StickerFormat, seconds: Double) -> [CFString: Any] {
        switch format {
        case .gif:
            return [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: seconds,
                    kCGImagePropertyGIFUnclampedDelayTime: seconds
                ]
            ]
        case .apng, .png:
            return [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGDelayTime: seconds]]
        case .animatedWebP, .webp:
            return [
                kCGImagePropertyWebPDictionary: [
                    kCGImagePropertyWebPDelayTime: seconds,
                    kCGImagePropertyWebPUnclampedDelayTime: seconds
                ]
            ]
        case .webm:
            return [:]
        }
    }
}

extension CGImage {
    var pixelSize: PixelSize { PixelSize(width: width, height: height) }
}
