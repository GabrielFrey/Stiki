import CoreGraphics
import StikiCore
import XCTest
@testable import Stiki

/// Outline rendering on a synthetic mask: the dilated silhouette must occupy
/// more opaque pixels than the cut-out subject alone, which is the visible
/// "sticker border" the product promises.
final class RenderServiceTests: XCTestCase {
    func testOutlineDilatesTheMask() async throws {
        let sourceData = SampleImage.circlePNG()
        let maskData = SampleImage.circleMaskPNG()
        guard let source = SampleImage.decode(sourceData),
              let mask = SampleImage.decode(maskData) else {
            return XCTFail("sample images")
        }

        let recipe = EditRecipe(
            source: AssetRef(fileName: "s.png", kind: .image, pixelSize: .square(64)),
            mask: AssetRef(fileName: "m.png", kind: .mask, pixelSize: .square(64)),
            outline: OutlineSpec(style: .solid, relativeWidth: 0.08, color: .black, feather: 0),
            dropShadow: nil,
            background: .transparent
        )
        let withoutOutline = EditRecipe(
            source: recipe.source,
            mask: recipe.mask,
            outline: nil,
            dropShadow: nil,
            background: .transparent
        )

        let renderer = RenderService()
        let canvas = PixelSize.square(64)
        let plain = try await renderer.render(recipe: withoutOutline, source: source, mask: mask, canvas: canvas)
        let outlined = try await renderer.render(recipe: recipe, source: source, mask: mask, canvas: canvas)

        let plainOpaque = opaqueCount(plain)
        let outlinedOpaque = opaqueCount(outlined)
        XCTAssertGreaterThan(outlinedOpaque, plainOpaque, "outline should add opaque pixels around the subject")
        XCTAssertGreaterThan(plainOpaque, 0)
    }

    func testWholeImageMaskIsMostlyOpaque() throws {
        let mask = try MaskRefinement.wholeImageMask(size: .square(32))
        XCTAssertGreaterThan(opaqueCount(mask), 32 * 32 / 2)
    }

    func testBrushAddPaintsWhite() throws {
        let maskData = SampleImage.circleMaskPNG(side: 32)
        guard let mask = SampleImage.decode(maskData) else {
            return XCTFail("mask")
        }
        let stroke = BrushStroke(
            points: [UnitPoint2D(x: 0.05, y: 0.05)],
            relativeRadius: 0.15,
            mode: .add
        )
        let painted = try MaskRefinement.apply(strokes: [stroke], to: mask, feather: 0)
        XCTAssertGreaterThan(opaqueCount(painted), opaqueCount(mask))
    }

    private func opaqueCount(_ image: CGImage) -> Int {
        guard let data = image.dataProvider?.data,
              let pointer = CFDataGetBytePtr(data) else { return 0 }
        let bytes = CFDataGetLength(data)
        let bpp = max(1, image.bitsPerPixel / 8)
        var count = 0
        if bpp == 1 {
            for i in 0..<bytes where pointer[i] > 127 { count += 1 }
        } else {
            var i = 0
            while i + 3 < bytes {
                if pointer[i + 3] > 127 { count += 1 }
                i += bpp
            }
        }
        return count
    }
}
