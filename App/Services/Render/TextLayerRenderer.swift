import CoreGraphics
import CoreText
import Foundation
import StikiCore
import UIKit

/// Draws text and emoji layers into a canvas-sized transparent bitmap.
///
/// CoreText is used directly rather than `UILabel` snapshots so the renderer
/// can run off the main actor and so curved captions can be laid out glyph by
/// glyph along an arc — the classic sticker caption that `NSAttributedString`
/// drawing cannot produce.
struct TextLayerRenderer {
    var canvas: PixelSize

    /// Returns `nil` when there is nothing to draw, so the pipeline can skip a
    /// composite step entirely.
    func render(textLayers: [TextLayer], emojiLayers: [EmojiLayer]) -> CGImage? {
        let drawableText = textLayers.filter { $0.renderableText != nil }
        guard !drawableText.isEmpty || !emojiLayers.isEmpty, !canvas.isEmpty else { return nil }

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: canvas.width, height: canvas.height),
            format: format
        )

        let image = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            for layer in emojiLayers {
                draw(emoji: layer, in: context)
            }
            for layer in drawableText {
                draw(text: layer, in: context)
            }
        }
        return image.cgImage
    }

    // MARK: - Emoji

    private func draw(emoji layer: EmojiLayer, in context: CGContext) {
        let size = max(8, layer.relativeSize * Double(canvas.height))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size)
        ]
        let string = NSAttributedString(string: layer.emoji, attributes: attributes)
        let bounds = string.size()
        let center = CGPoint(
            x: layer.transform.position.x * Double(canvas.width),
            y: layer.transform.position.y * Double(canvas.height)
        )

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: layer.transform.rotation)
        context.scaleBy(x: layer.transform.sanitizedScale, y: layer.transform.sanitizedScale)
        UIGraphicsPushContext(context)
        string.draw(at: CGPoint(x: -bounds.width / 2, y: -bounds.height / 2))
        UIGraphicsPopContext()
        context.restoreGState()
    }

    // MARK: - Text

    private func draw(text layer: TextLayer, in context: CGContext) {
        guard let string = layer.renderableText else { return }
        let fontSize = max(8, layer.relativeFontSize * Double(canvas.height))
        let font = font(for: layer.fontStyle, size: fontSize)
        let strokeWidth = layer.strokeWidth * fontSize

        let center = CGPoint(
            x: layer.transform.position.x * Double(canvas.width),
            y: layer.transform.position.y * Double(canvas.height)
        )

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: layer.transform.rotation)
        context.scaleBy(x: layer.transform.sanitizedScale, y: layer.transform.sanitizedScale)

        switch layer.curve {
        case .straight:
            drawStraight(string, layer: layer, font: font, strokeWidth: strokeWidth, in: context)
        case .arcUp, .arcDown:
            drawCurved(string, layer: layer, font: font, strokeWidth: strokeWidth, in: context)
        }

        context.restoreGState()
    }

    private func drawStraight(
        _ string: String,
        layer: TextLayer,
        font: UIFont,
        strokeWidth: Double,
        in context: CGContext
    ) {
        let maxWidth = Double(canvas.width) * 0.92
        // Stroke is drawn as a negative width so the fill is not eaten by it.
        let attributed = NSAttributedString(
            string: string,
            attributes: [
                .font: font,
                .foregroundColor: UIColor(recipe: layer.color),
                .strokeColor: UIColor(recipe: layer.strokeColor),
                .strokeWidth: -strokeWidth / font.pointSize * 100,
                .paragraphStyle: centeredParagraphStyle()
            ]
        )
        let bounding = attributed.boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        UIGraphicsPushContext(context)
        attributed.draw(
            with: CGRect(
                x: -bounding.width / 2,
                y: -bounding.height / 2,
                width: bounding.width,
                height: bounding.height
            ),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        UIGraphicsPopContext()
    }

    /// Lays out glyphs along a circular arc.
    private func drawCurved(
        _ string: String,
        layer: TextLayer,
        font: UIFont,
        strokeWidth: Double,
        in context: CGContext
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(recipe: layer.color),
            .strokeColor: UIColor(recipe: layer.strokeColor),
            .strokeWidth: -strokeWidth / font.pointSize * 100
        ]

        let characters = string.map { String($0) }
        let widths = characters.map { NSAttributedString(string: $0, attributes: attributes).size().width }
        let totalWidth = widths.reduce(0, +)
        guard totalWidth > 0 else { return }

        let radius = Double(canvas.width) * 0.42
        let isUp = layer.curve == .arcUp
        let totalAngle = totalWidth / radius
        var angle = -totalAngle / 2

        UIGraphicsPushContext(context)
        for (index, character) in characters.enumerated() {
            let width = widths[index]
            let step = width / radius
            angle += step / 2

            context.saveGState()
            // Rotate into place, then step out to the arc and flip for the
            // downward case so glyphs stay upright relative to the curve.
            context.rotate(by: isUp ? angle : -angle)
            context.translateBy(x: 0, y: isUp ? -radius : radius)
            if !isUp {
                context.rotate(by: .pi)
                context.scaleBy(x: -1, y: 1)
            }
            let attributed = NSAttributedString(string: character, attributes: attributes)
            let size = attributed.size()
            attributed.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
            context.restoreGState()

            angle += step / 2
        }
        UIGraphicsPopContext()
    }

    private func centeredParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        return style
    }

    private func font(for style: TextLayer.FontStyle, size: Double) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: .heavy)
        let descriptor: UIFontDescriptor?
        switch style {
        case .rounded:
            descriptor = systemFont.fontDescriptor.withDesign(.rounded)
        case .serif:
            descriptor = systemFont.fontDescriptor.withDesign(.serif)
        case .monospaced:
            descriptor = systemFont.fontDescriptor.withDesign(.monospaced)
        case .condensed:
            descriptor = systemFont.fontDescriptor.withSymbolicTraits(.traitCondensed)
        }
        guard let descriptor else { return systemFont }
        return UIFont(descriptor: descriptor, size: size)
    }
}

extension UIColor {
    convenience init(recipe color: RecipeColor) {
        self.init(
            red: color.red,
            green: color.green,
            blue: color.blue,
            alpha: color.alpha
        )
    }

    /// Converts a UIKit colour back into a recipe colour for persistence.
    var recipeColor: RecipeColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RecipeColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
