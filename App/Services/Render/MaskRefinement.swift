import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import StikiCore

/// One brush stroke the user paints on the cutout mask.
struct BrushStroke: Hashable, Sendable {
    enum Mode: String, Hashable, Sendable {
        /// White: keep this area.
        case add
        /// Black: erase this area.
        case erase
    }

    var points: [UnitPoint2D]
    var relativeRadius: Double
    var mode: Mode

    init(points: [UnitPoint2D], relativeRadius: Double, mode: Mode) {
        self.points = points
        self.relativeRadius = relativeRadius
        self.mode = mode
    }
}

/// Applies brush strokes and edge feather to a grayscale mask.
///
/// The refined mask is stored as a PNG on the recipe so reopening the sticker
/// restores the user's work, not just the original Vision cutout.
enum MaskRefinement {
    /// Default brush radius as a fraction of the mask's shortest side.
    static let defaultRelativeRadius = 0.04
    static let relativeRadiusRange = 0.01...0.18
    static let featherRange = 0...0.08

    /// Paints `strokes` onto `mask` and optionally feathers the edge.
    static func apply(
        strokes: [BrushStroke],
        to mask: CGImage,
        feather: Double
    ) throws -> CGImage {
        var current = mask
        if !strokes.isEmpty {
            current = try paint(strokes: strokes, onto: current)
        }
        let clampedFeather = min(max(feather, featherRange.lowerBound), featherRange.upperBound)
        if clampedFeather > 0 {
            current = try featherMask(current, relativeRadius: clampedFeather)
        }
        return current
    }

    /// Rounded-rect "keep whole image" mask, used when the user declines
    /// subject lifting (meme mode).
    static func wholeImageMask(size: PixelSize) throws -> CGImage {
        guard !size.isEmpty else { throw StikiError.renderFailed("empty mask") }
        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
              let context = CGContext(
                data: nil,
                width: size.width,
                height: size.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else {
            throw StikiError.renderFailed("mask context")
        }
        context.setFillColor(gray: 1, alpha: 1)
        let radius = OutlineGeometry.memeModeCornerRadius(canvas: size)
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            .insetBy(dx: 1, dy: 1)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
        guard let image = context.makeImage() else { throw StikiError.renderFailed("mask image") }
        return image
    }

    private static func paint(strokes: [BrushStroke], onto mask: CGImage) throws -> CGImage {
        let width = mask.width
        let height = mask.height
        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else {
            throw StikiError.renderFailed("brush context")
        }
        context.draw(mask, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.setBlendMode(.copy)

        let shortest = Double(min(width, height))
        for stroke in strokes {
            guard stroke.points.count >= 1 else { continue }
            let radius = max(1, stroke.relativeRadius * shortest)
            context.setStrokeColor(gray: stroke.mode == .add ? 1 : 0, alpha: 1)
            context.setFillColor(gray: stroke.mode == .add ? 1 : 0, alpha: 1)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.setLineWidth(radius * 2)

            let points = stroke.points.map {
                CGPoint(x: $0.x * Double(width), y: (1 - $0.y) * Double(height))
            }
            if points.count == 1 {
                context.fillEllipse(in: CGRect(
                    x: points[0].x - radius,
                    y: points[0].y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
                continue
            }
            context.beginPath()
            context.move(to: points[0])
            for point in points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }

        guard let image = context.makeImage() else { throw StikiError.renderFailed("brush image") }
        return image
    }

    private static func featherMask(_ mask: CGImage, relativeRadius: Double) throws -> CGImage {
        let radius = relativeRadius * Double(min(mask.width, mask.height))
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = CIImage(cgImage: mask)
        blur.radius = Float(radius)
        guard let output = blur.outputImage else { return mask }
        let context = CIContext(options: [.useSoftwareRenderer: true])
        let extent = CGRect(x: 0, y: 0, width: mask.width, height: mask.height)
        return context.createCGImage(output, from: extent) ?? mask
    }
}
