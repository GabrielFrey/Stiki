import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import StikiCore

/// Builds the CoreImage graph for one sticker.
///
/// The pipeline is a pure function of (source, mask, recipe, canvas): no
/// caching, no IO, no actor state. That is what makes a recipe replayable at
/// any resolution — the same graph produces a 96 px tray icon and a 618 px
/// iMessage sticker — and it keeps the whole effect chain testable against a
/// synthetic mask.
///
/// Order matters and follows how the eye reads a sticker: background, shadow,
/// outline, subject, captions.
struct RecipePipeline {
    var recipe: EditRecipe
    var canvas: PixelSize

    private var canvasRect: CGRect {
        CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
    }

    /// Composites one frame.
    ///
    /// - Parameters:
    ///   - source: Full-colour source frame.
    ///   - mask: Grayscale cutout mask, white where the subject is kept.
    ///   - overlay: Pre-rendered text and emoji layers, canvas sized.
    func composite(source: CGImage, mask: CGImage?, overlay: CGImage?) -> CIImage {
        let sourceImage = CIImage(cgImage: source)
        let placement = layoutTransform(for: source.pixelSize)

        var subject = sourceImage.transformed(by: placement)
        var silhouette: CIImage

        if let mask {
            let maskImage = CIImage(cgImage: mask)
                .transformed(by: layoutTransform(for: mask.pixelSize))
                .cropped(to: canvasRect)
            subject = cutOut(subject, using: maskImage)
            silhouette = maskImage
        } else {
            // "Keep whole image" (meme mode): the sticker is the padded photo
            // with rounded corners, which Apple's Live Stickers cannot do.
            subject = roundedCrop(subject.cropped(to: canvasRect))
            silhouette = alphaAsLuminance(subject)
        }

        subject = applyFilters(to: subject)
        silhouette = silhouette.cropped(to: canvasRect)

        var result = subject.cropped(to: canvasRect)

        if let outline = recipe.outline, outline.sanitizedRelativeWidth > 0 {
            result = compositeOutline(outline, subject: result, silhouette: silhouette)
        }

        if let shadow = recipe.dropShadow {
            result = compositeShadow(shadow, over: result)
        }

        result = compositeBackground(under: result, source: sourceImage, placement: placement)

        if let overlay {
            result = CIImage(cgImage: overlay).composited(over: result)
        }

        return result.cropped(to: canvasRect)
    }

    // MARK: - Layout

    /// Maps source pixels into the canvas: aspect fit with room reserved for
    /// the outline and shadow, then the user's own transform.
    private func layoutTransform(for sourceSize: PixelSize) -> CGAffineTransform {
        let padding = OutlineGeometry.safePaddingFraction(
            outline: recipe.outline,
            shadow: recipe.dropShadow
        )
        let placement = SizeFitting.aspectFit(
            content: sourceSize,
            in: canvas,
            paddingFraction: padding
        )
        let fitScale = Double(placement.size.width) / Double(max(1, sourceSize.width))

        let transform = recipe.transform
        let userScale = transform.sanitizedScale
        let centerX = transform.position.x * Double(canvas.width)
        // CoreImage's origin is bottom-left; recipe positions are top-left.
        let centerY = (1 - transform.position.y) * Double(canvas.height)

        var affine = CGAffineTransform.identity
        affine = affine.translatedBy(x: centerX, y: centerY)
        affine = affine.rotated(by: -transform.rotation)
        affine = affine.scaledBy(
            x: fitScale * userScale * (transform.isFlippedHorizontally ? -1 : 1),
            y: fitScale * userScale
        )
        affine = affine.translatedBy(
            x: -Double(sourceSize.width) / 2,
            y: -Double(sourceSize.height) / 2
        )
        return affine
    }

    // MARK: - Cutout

    private func cutOut(_ image: CIImage, using mask: CIImage) -> CIImage {
        let filter = CIFilter.blendWithMask()
        filter.inputImage = image
        filter.backgroundImage = CIImage.empty().cropped(to: canvasRect)
        filter.maskImage = mask
        return filter.outputImage ?? image
    }

    private func roundedCrop(_ image: CIImage) -> CIImage {
        let radius = OutlineGeometry.memeModeCornerRadius(canvas: canvas)
        let rounded = CIFilter.roundedRectangleGenerator()
        rounded.extent = canvasRect.insetBy(dx: 1, dy: 1)
        rounded.radius = Float(radius)
        rounded.color = CIColor.white
        guard let maskImage = rounded.outputImage?.cropped(to: canvasRect) else { return image }
        return cutOut(image, using: maskImage)
    }

    /// Promotes alpha into the luminance channels, producing a silhouette the
    /// morphology filters can dilate.
    private func alphaAsLuminance(_ image: CIImage) -> CIImage {
        let matrix = CIFilter.colorMatrix()
        matrix.inputImage = image
        matrix.rVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.gVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.bVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        matrix.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        return matrix.outputImage ?? image
    }

    // MARK: - Filters

    private func applyFilters(to image: CIImage) -> CIImage {
        recipe.filters.reduce(image) { current, spec in
            apply(spec, to: current)
        }
    }

    private func apply(_ spec: FilterSpec, to image: CIImage) -> CIImage {
        let amount = spec.intensity
        switch spec.kind {
        case .vivid:
            let vibrance = CIFilter.vibrance()
            vibrance.inputImage = image
            vibrance.amount = Float(amount)
            let controls = CIFilter.colorControls()
            controls.inputImage = vibrance.outputImage ?? image
            controls.saturation = Float(1 + 0.35 * amount)
            controls.contrast = Float(1 + 0.12 * amount)
            return controls.outputImage ?? image

        case .mono:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = image
            return blend(mono.outputImage, over: image, amount: amount)

        case .comic:
            let comic = CIFilter.comicEffect()
            comic.inputImage = image
            // Comic ignores alpha, so the cutout is re-applied afterwards.
            let masked = comic.outputImage.map { cutOut($0, using: alphaAsLuminance(image)) }
            return blend(masked, over: image, amount: amount)

        case .posterize:
            let posterize = CIFilter.colorPosterize()
            posterize.inputImage = image
            posterize.levels = Float(max(2, 12 - 8 * amount))
            return blend(posterize.outputImage, over: image, amount: amount)

        case .glossy:
            return glossy(image, amount: amount)
        }
    }

    /// Cross-fades a filtered image with the original so intensity sliders
    /// behave for effects that have no strength parameter of their own.
    private func blend(_ filtered: CIImage?, over original: CIImage, amount: Double) -> CIImage {
        guard let filtered else { return original }
        guard amount < 1 else { return filtered }
        let dissolve = CIFilter.dissolveTransition()
        dissolve.inputImage = original
        dissolve.targetImage = filtered
        dissolve.time = Float(amount)
        return dissolve.outputImage ?? filtered
    }

    /// A diagonal highlight sweep, the "shiny" sticker look.
    private func glossy(_ image: CIImage, amount: Double) -> CIImage {
        let gradient = CIFilter.linearGradient()
        gradient.point0 = CGPoint(x: 0, y: canvasRect.height)
        gradient.point1 = CGPoint(x: canvasRect.width * 0.75, y: 0)
        gradient.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 0.65 * amount)
        gradient.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)
        guard let sweep = gradient.outputImage?.cropped(to: canvasRect) else { return image }

        let screen = CIFilter.screenBlendMode()
        screen.inputImage = sweep
        screen.backgroundImage = image
        // Confine the highlight to the subject, not the transparent canvas.
        guard let lit = screen.outputImage else { return image }
        return cutOut(lit, using: alphaAsLuminance(image))
    }

    // MARK: - Outline

    private func compositeOutline(
        _ outline: OutlineSpec,
        subject: CIImage,
        silhouette: CIImage
    ) -> CIImage {
        let radius = OutlineGeometry.dilationRadius(
            relativeWidth: outline.sanitizedRelativeWidth,
            canvas: canvas
        )
        guard radius >= 1 else { return subject }

        let dilate = CIFilter.morphologyMaximum()
        dilate.inputImage = silhouette
        dilate.radius = Float(radius)
        guard var band = dilate.outputImage?.cropped(to: canvasRect) else { return subject }

        let feather = OutlineGeometry.featherRadius(for: outline, canvas: canvas)
        if feather >= 0.5 {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = band
            blur.radius = Float(feather)
            band = blur.outputImage?.cropped(to: canvasRect) ?? band
        }

        if outline.style == .dashed {
            band = applyDashes(to: band, silhouette: silhouette, outline: outline)
        }

        let color = CIFilter.constantColorGenerator()
        color.color = CIColor.recipe(outline.color)
        guard let flood = color.outputImage?.cropped(to: canvasRect) else { return subject }

        let tintFilter = CIFilter.blendWithMask()
        tintFilter.inputImage = flood
        tintFilter.backgroundImage = CIImage.empty().cropped(to: canvasRect)
        tintFilter.maskImage = band
        guard var outlineLayer = tintFilter.outputImage else { return subject }

        if outline.style == .glow {
            let glow = CIFilter.screenBlendMode()
            glow.inputImage = outlineLayer
            glow.backgroundImage = outlineLayer
            outlineLayer = glow.outputImage ?? outlineLayer
        }

        if outline.style == .puffy {
            // The puffy look is a thick band plus a tight shadow under it.
            let puffShadow = DropShadowSpec(
                color: .black,
                offset: UnitPoint2D(x: 0.008, y: 0.014),
                blur: outline.sanitizedRelativeWidth * 0.4,
                opacity: 0.4
            )
            outlineLayer = compositeShadow(puffShadow, over: outlineLayer)
        }

        return subject.composited(over: outlineLayer)
    }

    private func applyDashes(to band: CIImage, silhouette: CIImage, outline: OutlineSpec) -> CIImage {
        let pattern = OutlineGeometry.dashPattern(
            relativeWidth: outline.sanitizedRelativeWidth,
            canvas: canvas
        )
        let stripes = CIFilter.stripesGenerator()
        stripes.color0 = CIColor.white
        stripes.color1 = CIColor.black
        stripes.width = Float(pattern.first ?? 8)
        stripes.sharpness = 1
        stripes.center = CGPoint(x: canvasRect.midX, y: canvasRect.midY)
        guard let stripeImage = stripes.outputImage?
            .transformed(by: CGAffineTransform(rotationAngle: .pi / 4))
            .cropped(to: canvasRect) else {
            return band
        }
        let multiply = CIFilter.multiplyCompositing()
        multiply.inputImage = stripeImage
        multiply.backgroundImage = band
        return multiply.outputImage?.cropped(to: canvasRect) ?? band
    }

    // MARK: - Shadow and background

    private func compositeShadow(_ shadow: DropShadowSpec, over image: CIImage) -> CIImage {
        let silhouette = alphaAsLuminance(image)
        let color = CIFilter.constantColorGenerator()
        color.color = CIColor.recipe(shadow.color).withAlpha(shadow.opacity)
        guard let flood = color.outputImage?.cropped(to: canvasRect) else { return image }

        let tint = CIFilter.blendWithMask()
        tint.inputImage = flood
        tint.backgroundImage = CIImage.empty().cropped(to: canvasRect)
        tint.maskImage = silhouette
        guard var shadowLayer = tint.outputImage else { return image }

        let blurRadius = OutlineGeometry.shadowBlurRadius(for: shadow, canvas: canvas)
        if blurRadius >= 0.5 {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = shadowLayer
            blur.radius = Float(blurRadius)
            shadowLayer = blur.outputImage ?? shadowLayer
        }

        let offset = OutlineGeometry.shadowOffset(for: shadow, canvas: canvas)
        shadowLayer = shadowLayer
            .transformed(by: CGAffineTransform(translationX: offset.x, y: -offset.y))
            .cropped(to: canvasRect)

        return image.composited(over: shadowLayer)
    }

    private func compositeBackground(
        under image: CIImage,
        source: CIImage,
        placement: CGAffineTransform
    ) -> CIImage {
        switch recipe.background {
        case .transparent:
            return image
        case let .solid(color):
            let generator = CIFilter.constantColorGenerator()
            generator.color = CIColor.recipe(color)
            guard let flood = generator.outputImage?.cropped(to: canvasRect) else { return image }
            return image.composited(over: flood)
        case .originalImage:
            let backdrop = source.transformed(by: placement).cropped(to: canvasRect)
            return image.composited(over: backdrop)
        }
    }
}

extension CIColor {
    /// Bridges a resolution-independent recipe colour into CoreImage.
    static func recipe(_ color: RecipeColor) -> CIColor {
        CIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    func withAlpha(_ alpha: Double) -> CIColor {
        CIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
