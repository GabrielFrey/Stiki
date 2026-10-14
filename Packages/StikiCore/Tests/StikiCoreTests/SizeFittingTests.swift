import Foundation
import Testing
@testable import StikiCore

@Suite("Size fitting")
struct SizeFittingTests {
    @Test("Scaling to a longest side keeps the aspect ratio")
    func longestSideScaling() {
        #expect(SizeFitting.scaled(PixelSize(width: 4032, height: 3024), longestSideTo: 512)
            == PixelSize(width: 512, height: 384))
        #expect(SizeFitting.scaled(PixelSize(width: 3024, height: 4032), longestSideTo: 512)
            == PixelSize(width: 384, height: 512))
        #expect(SizeFitting.scaled(.square(1000), longestSideTo: 512) == .square(512))
    }

    @Test("Scaling never collapses a dimension to zero")
    func tinyScaling() {
        let size = SizeFitting.scaled(PixelSize(width: 2000, height: 3), longestSideTo: 512)
        #expect(size.width == 512)
        #expect(size.height >= 1)
        #expect(SizeFitting.scaled(.square(10), by: 0.001) == .square(1))
    }

    @Test("Degenerate input yields a usable square")
    func degenerateInput() {
        #expect(SizeFitting.scaled(PixelSize(width: 0, height: 0), longestSideTo: 512) == .square(512))
        #expect(PixelSize(width: 0, height: 10).isEmpty)
        #expect(PixelSize(width: 10, height: 0).aspectRatio == 1)
    }

    @Test("Aspect fit centres content inside the canvas")
    func aspectFitCentres() {
        let placement = SizeFitting.aspectFit(
            content: PixelSize(width: 1000, height: 500),
            in: .square(512)
        )
        #expect(placement.size == PixelSize(width: 512, height: 256))
        #expect(placement.x == 0)
        #expect(placement.y == 128)
    }

    @Test("Padding reserves room on every side for the outline")
    func aspectFitWithPadding() {
        let placement = SizeFitting.aspectFit(
            content: .square(1000),
            in: .square(512),
            paddingFraction: 0.1
        )
        #expect(placement.size == .square(410))
        #expect(placement.x == 51)
        #expect(placement.y == 51)
    }

    @Test("Absurd padding is clamped instead of inverting the layout")
    func paddingIsClamped() {
        let placement = SizeFitting.aspectFit(
            content: .square(1000),
            in: .square(512),
            paddingFraction: 5
        )
        #expect(placement.size.width >= 1)
        #expect(placement.x >= 0)
        #expect(placement.size.width <= 512)
    }

    @Test("Squaring grows the shorter edge, so nothing is distorted")
    func squaring() {
        #expect(SizeFitting.squared(PixelSize(width: 800, height: 600)) == .square(800))
    }

    @Test("Imported assets are capped at 2048 px for processing")
    func processingSize() {
        #expect(SizeFitting.processingSize(for: PixelSize(width: 8064, height: 6048))
            == PixelSize(width: 2048, height: 1536))
        #expect(SizeFitting.processingSize(for: PixelSize(width: 900, height: 1200))
            == PixelSize(width: 900, height: 1200))
    }

    @Test("Render size follows the target canvas rule")
    func renderSize() {
        let source = PixelSize(width: 1200, height: 900)
        #expect(SizeFitting.renderSize(for: .exactSquare(512), sourceSize: source) == .square(512))
        #expect(SizeFitting.renderSize(for: .allowedSquares([300, 408, 618]), sourceSize: source)
            == .square(618))
    }

    @Test("Upscaling can be refused so a small source is not blown up")
    func renderSizeWithoutUpscaling() {
        let source = PixelSize.square(240)
        #expect(SizeFitting.renderSize(for: .exactSquare(512), sourceSize: source, allowUpscaling: false)
            == .square(240))
        #expect(SizeFitting.renderSize(for: .exactSquare(512), sourceSize: source, allowUpscaling: true)
            == .square(512))
    }

    @Test("Canvas rules accept the sizes they advertise")
    func canvasRules() {
        #expect(CanvasRule.exactSquare(512).isSatisfied(by: .square(512)))
        #expect(!CanvasRule.exactSquare(512).isSatisfied(by: PixelSize(width: 512, height: 511)))
        #expect(CanvasRule.longestSideExactly(512).isSatisfied(by: PixelSize(width: 512, height: 200)))
        #expect(!CanvasRule.longestSideExactly(512).isSatisfied(by: PixelSize(width: 400, height: 200)))
        #expect(CanvasRule.allowedSquares([300, 408]).isSatisfied(by: .square(408)))
        #expect(!CanvasRule.allowedSquares([300, 408]).isSatisfied(by: .square(409)))
        #expect(CanvasRule.maxLongestSide(2048).isSatisfied(by: .square(2048)))
        #expect(!CanvasRule.maxLongestSide(2048).isSatisfied(by: .square(2049)))
        #expect(!CanvasRule.maxLongestSide(2048).isSatisfied(by: .square(0)))
    }

    @Test("Allowed-square fitting rounds up, then falls back to the largest size")
    func allowedSquareFitting() {
        let rule = CanvasRule.allowedSquares([300, 408, 618])
        #expect(rule.fittedSize(for: .square(256)) == .square(300))
        #expect(rule.fittedSize(for: .square(500)) == .square(618))
        #expect(rule.fittedSize(for: .square(4000)) == .square(618))
        #expect(rule.nominalLongestSide == 618)
    }
}
