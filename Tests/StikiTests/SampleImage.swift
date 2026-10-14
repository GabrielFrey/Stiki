import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Builds a tiny PNG in memory so tests never depend on a fixture file.
enum SampleImage {
    /// Opaque 64×64 PNG with a white circle on a magenta field — magenta is
    /// easy to assert against after a cutout because it should disappear if
    /// the mask is applied, and remain if it is not.
    static func circlePNG(side: Int = 64) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return Data()
        }
        context.setFillColor(red: 1, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        let inset = CGFloat(side) * 0.18
        context.fillEllipse(in: CGRect(x: inset, y: inset, width: CGFloat(side) - inset * 2, height: CGFloat(side) - inset * 2))
        guard let image = context.makeImage() else { return Data() }
        return pngData(image)
    }

    /// Grayscale mask: white circle, black elsewhere.
    static func circleMaskPNG(side: Int = 64) -> Data {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return Data()
        }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(gray: 1, alpha: 1)
        let inset = CGFloat(side) * 0.18
        context.fillEllipse(in: CGRect(x: inset, y: inset, width: CGFloat(side) - inset * 2, height: CGFloat(side) - inset * 2))
        guard let image = context.makeImage() else { return Data() }
        return pngData(image)
    }

    static func pngData(_ image: CGImage) -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return Data()
        }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
