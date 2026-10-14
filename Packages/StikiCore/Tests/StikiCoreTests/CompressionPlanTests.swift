import Foundation
import Testing
@testable import StikiCore

@Suite("Compression plan")
struct CompressionPlanTests {
    @Test("Targets with an exact canvas never offer a smaller size")
    func exactCanvasKeepsDimensions() {
        let attempts = CompressionPlan.attempts(
            canvas: .exactSquare(512),
            baseSize: .square(512),
            isAnimated: false
        )
        #expect(!attempts.isEmpty)
        #expect(attempts.allSatisfy { $0.pixelSize == .square(512) })
    }

    @Test("Permissive targets fall back to smaller canvases")
    func permissiveCanvasScalesDown() {
        let attempts = CompressionPlan.attempts(
            canvas: .maxLongestSide(2048),
            baseSize: .square(1024),
            isAnimated: false
        )
        #expect(attempts.contains { $0.pixelSize.longestSide < 1024 })
    }

    @Test("Quality is spent before pixels or frames are")
    func qualityIsTriedFirst() {
        let attempts = CompressionPlan.attempts(
            canvas: .maxLongestSide(2048),
            baseSize: .square(1024),
            isAnimated: true,
            frameCount: 30
        )
        let firstScaleChange = attempts.firstIndex { $0.pixelSize != .square(1024) } ?? attempts.count
        #expect(firstScaleChange >= CompressionPlan.qualityLadder.count)
        #expect(attempts.first?.quality == CompressionPlan.qualityLadder.first)
        #expect(attempts.first?.frameStride == 1)
    }

    @Test("Short animations are never thinned")
    func shortAnimationsKeepEveryFrame() {
        let attempts = CompressionPlan.attempts(
            canvas: .exactSquare(512),
            baseSize: .square(512),
            isAnimated: true,
            frameCount: 8
        )
        #expect(attempts.allSatisfy { $0.frameStride == 1 })
    }

    @Test("Long animations get frame thinning as a last resort")
    func longAnimationsAreThinned() {
        let attempts = CompressionPlan.attempts(
            canvas: .exactSquare(512),
            baseSize: .square(512),
            isAnimated: true,
            frameCount: 72
        )
        #expect(attempts.contains { $0.frameStride == 2 })
        #expect(attempts.contains { $0.frameStride == 3 })
        #expect(attempts.last?.frameStride == 3)
    }

    @Test("Thinning keeps a sane frame count")
    func frameCountAfterThinning() {
        #expect(CompressionPlan.frameCount(24, stride: 1) == 24)
        #expect(CompressionPlan.frameCount(24, stride: 2) == 12)
        #expect(CompressionPlan.frameCount(25, stride: 2) == 13)
        #expect(CompressionPlan.frameCount(1, stride: 4) == 1)
    }

    @Test("Thinning stretches frame duration so playback speed is preserved")
    func frameDurationAfterThinning() {
        #expect(CompressionPlan.frameDuration(42, stride: 2, minimumMilliseconds: nil) == 84)
        #expect(CompressionPlan.frameDuration(42, stride: 1, minimumMilliseconds: nil) == 42)
        // WhatsApp's 8 ms floor wins over an impossibly fast frame rate.
        #expect(CompressionPlan.frameDuration(3, stride: 1, minimumMilliseconds: 8) == 8)
    }

    @Test("Duration caps translate into a frame budget")
    func framesFittingDuration() {
        #expect(CompressionPlan.framesFitting(
            durationMilliseconds: 3_000,
            frameDurationMilliseconds: 42,
            frameCount: 120
        ) == 71)
        #expect(CompressionPlan.framesFitting(
            durationMilliseconds: 10_000,
            frameDurationMilliseconds: 42,
            frameCount: 48
        ) == 48)
        #expect(CompressionPlan.framesFitting(
            durationMilliseconds: 1,
            frameDurationMilliseconds: 42,
            frameCount: 48
        ) == 1)
        #expect(CompressionPlan.framesFitting(
            durationMilliseconds: 1_000,
            frameDurationMilliseconds: 0,
            frameCount: 10
        ) == 10)
    }
}

@Suite("Outline geometry")
struct OutlineGeometryTests {
    @Test("Dilation scales with the canvas's shortest side")
    func dilationScales() {
        #expect(OutlineGeometry.dilationRadius(relativeWidth: 0.04, canvas: .square(512)) == 20.48)
        #expect(OutlineGeometry.dilationRadius(
            relativeWidth: 0.04,
            canvas: PixelSize(width: 1024, height: 512)
        ) == 20.48)
    }

    @Test("Dilation is clamped so an outline cannot swallow the canvas")
    func dilationIsClamped() {
        #expect(OutlineGeometry.dilationRadius(relativeWidth: 5, canvas: .square(100)) == 25)
        #expect(OutlineGeometry.dilationRadius(relativeWidth: -1, canvas: .square(100)) == 0)
        #expect(OutlineGeometry.dilationRadius(relativeWidth: 0.1, canvas: .square(0)) == 0)
    }

    @Test("Glow outlines feather well past their nominal width")
    func glowFeathersWide() {
        let canvas = PixelSize.square(512)
        let solid = OutlineGeometry.featherRadius(
            for: OutlineSpec(style: .solid, relativeWidth: 0.05, feather: 0.002),
            canvas: canvas
        )
        let glow = OutlineGeometry.featherRadius(
            for: OutlineSpec(style: .glow, relativeWidth: 0.05, feather: 0.002),
            canvas: canvas
        )
        #expect(glow > solid)
    }

    @Test("Safe padding grows with the effects in play and stays under 40%")
    func safePadding() {
        let none = OutlineGeometry.safePaddingFraction(outline: nil, shadow: nil)
        let solid = OutlineGeometry.safePaddingFraction(
            outline: OutlineSpec(style: .solid, relativeWidth: 0.05),
            shadow: nil
        )
        let glowAndShadow = OutlineGeometry.safePaddingFraction(
            outline: OutlineSpec(style: .glow, relativeWidth: 0.05),
            shadow: .default
        )
        #expect(none > 0)
        #expect(solid > none)
        #expect(glowAndShadow > solid)
        #expect(OutlineGeometry.safePaddingFraction(
            outline: OutlineSpec(style: .glow, relativeWidth: 10, feather: 10),
            shadow: DropShadowSpec(offset: UnitPoint2D(x: 5, y: 5), blur: 5)
        ) <= 0.4)
    }

    @Test("Shadow offset and blur are resolved in pixels")
    func shadowGeometry() {
        let offset = OutlineGeometry.shadowOffset(
            for: DropShadowSpec(offset: UnitPoint2D(x: 0.1, y: 0.25)),
            canvas: PixelSize(width: 500, height: 400)
        )
        #expect(offset.x == 50)
        #expect(OutlineGeometry.shadowBlurRadius(
            for: DropShadowSpec(blur: 0.02),
            canvas: .square(512)
        ) == 10.24)
    }

    @Test("Dashed outlines produce a two-part pattern")
    func dashPattern() {
        let pattern = OutlineGeometry.dashPattern(relativeWidth: 0.04, canvas: .square(512))
        #expect(pattern.count == 2)
        #expect(pattern[0] > pattern[1])
        #expect(pattern.allSatisfy { $0 > 0 })
    }

    @Test("Meme mode rounds corners relative to the canvas")
    func memeCornerRadius() {
        #expect(OutlineGeometry.memeModeCornerRadius(canvas: .square(512)) == 40.96)
    }
}

@Suite("Emoji tags")
struct EmojiTagSuggestionTests {
    @Test("Suggestions skip emoji the user already picked")
    func suggestionsAreFresh() {
        let suggestions = EmojiTagSuggestions.suggestions(excluding: ["😀", "✨"], count: 2)
        #expect(suggestions == ["❤️", "😂"])
        #expect(EmojiTagSuggestions.suggestions(excluding: [], count: 0).isEmpty)
    }

    @Test("Normalising pads up to WhatsApp's minimum and trims to its maximum")
    func normalisation() {
        #expect(EmojiTagSuggestions.normalized([], to: 1...3).count == 1)
        #expect(EmojiTagSuggestions.normalized(["😀", "😅", "😂", "🤣"], to: 1...3) == ["😀", "😅", "😂"])
        #expect(EmojiTagSuggestions.normalized(["😀", "😀", " "], to: 1...3) == ["😀"])
        #expect(EmojiTagSuggestions.normalized(["😀", "😀"], to: nil) == ["😀"])
    }
}
