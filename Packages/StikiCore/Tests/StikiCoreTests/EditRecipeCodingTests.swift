import Foundation
import Testing
@testable import StikiCore

@Suite("Edit recipe coding")
struct EditRecipeCodingTests {
    @Test("A full recipe survives a round trip unchanged")
    func roundTrip() throws {
        let recipe = Fixtures.recipe(animated: true)
        let decoded = try EditRecipe.decoded(from: try recipe.encoded())
        #expect(decoded == recipe)
    }

    @Test("Encoding always stamps the current version")
    func encodesCurrentVersion() throws {
        var recipe = Fixtures.recipe()
        recipe.version = 1
        let json = try JSONSerialization.jsonObject(with: try recipe.encoded()) as? [String: Any]
        #expect(json?["version"] as? Int == EditRecipe.currentVersion)
    }

    @Test("Version 1 payloads migrate: single filter becomes an array")
    func migratesVersionOne() throws {
        let legacy = """
        {
          "version": 1,
          "source": {
            "fileName": "old.png",
            "kind": "image",
            "pixelSize": { "width": 1024, "height": 768 }
          },
          "mask": {
            "fileName": "old-mask.png",
            "kind": "mask",
            "pixelSize": { "width": 1024, "height": 768 }
          },
          "outline": {
            "style": "solid",
            "relativeWidth": 0.04,
            "color": { "red": 1, "green": 1, "blue": 1, "alpha": 1 },
            "feather": 0.002
          },
          "filter": { "id": "9F2C2A8E-2B0E-4D4B-8F53-36F1C1E1B5A1", "kind": "mono", "intensity": 0.5 },
          "textLayers": []
        }
        """
        let recipe = try EditRecipe.decoded(from: Data(legacy.utf8))
        #expect(recipe.version == EditRecipe.currentVersion)
        #expect(recipe.filters.count == 1)
        #expect(recipe.filters.first?.kind == .mono)
        #expect(recipe.emojiLayers.isEmpty)
        #expect(recipe.background == .transparent)
        #expect(recipe.transform == .identity)
        #expect(recipe.source.pixelSize == PixelSize(width: 1024, height: 768))
    }

    @Test("A payload with no version field is treated as version 1")
    func versionlessPayload() throws {
        let json = """
        {
          "source": { "fileName": "a.png", "kind": "image", "pixelSize": { "width": 10, "height": 10 } }
        }
        """
        let recipe = try EditRecipe.decoded(from: Data(json.utf8))
        #expect(recipe.mask == nil)
        #expect(recipe.outline == nil)
        #expect(recipe.filters.isEmpty)
    }

    @Test("A recipe from a future version is rejected with a typed error")
    func futureVersionRejected() throws {
        let json = """
        {
          "version": 99,
          "source": { "fileName": "a.png", "kind": "image", "pixelSize": { "width": 10, "height": 10 } }
        }
        """
        #expect(throws: StikiCoreError.unsupportedRecipeVersion(found: 99, supported: EditRecipe.currentVersion)) {
            try EditRecipe.decoded(from: Data(json.utf8))
        }
    }

    @Test("Corrupt JSON surfaces as a decoding failure, not a crash")
    func corruptPayload() {
        #expect(throws: StikiCoreError.self) {
            try EditRecipe.decoded(from: Data("{ not json".utf8))
        }
    }

    @Test("Background cases round-trip, including the meme-mode original")
    func backgroundRoundTrip() throws {
        for background in [
            BackgroundSpec.transparent,
            .solid(RecipeColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.8)),
            .originalImage
        ] {
            var recipe = Fixtures.recipe()
            recipe.background = background
            let decoded = try EditRecipe.decoded(from: try recipe.encoded())
            #expect(decoded.background == background)
        }
    }

    @Test("Pro-only effects are detected from the recipe alone")
    func proDetection() {
        var recipe = Fixtures.recipe()
        recipe.outline = OutlineSpec(style: .solid)
        recipe.filters = [FilterSpec(kind: .vivid)]
        recipe.animation = nil
        #expect(!recipe.requiresPro)

        recipe.filters = [FilterSpec(kind: .comic)]
        #expect(recipe.requiresPro)

        recipe.filters = []
        recipe.outline = OutlineSpec(style: .glow)
        #expect(recipe.requiresPro)

        recipe.outline = OutlineSpec(style: .solid)
        recipe.animation = AnimationSpec()
        #expect(recipe.requiresPro)
    }

    @Test("Encoded output is key-sorted so repeated saves do not churn files")
    func stableEncoding() throws {
        let recipe = Fixtures.recipe()
        #expect(try recipe.encoded() == (try recipe.encoded()))
    }

    @Test("Hebrew text layers survive encoding")
    func unicodeText() throws {
        var recipe = Fixtures.recipe()
        recipe.textLayers = [TextLayer(text: "שלום עולם"), TextLayer(text: "Привет 👋")]
        let decoded = try EditRecipe.decoded(from: try recipe.encoded())
        #expect(decoded.textLayers.map(\.text) == ["שלום עולם", "Привет 👋"])
    }
}

@Suite("Animation spec")
struct AnimationSpecTests {
    @Test("Frame count and duration follow the sampling rate")
    func frameMath() {
        let spec = AnimationSpec(startSeconds: 1, durationSeconds: 2, framesPerSecond: 24)
        #expect(spec.frameCount == 48)
        #expect(spec.frameDurationMilliseconds == 42)
        #expect(spec.frameTimestamps().count == 48)
    }

    @Test("Timestamps stay inside the trimmed range")
    func timestampsInRange() {
        let spec = AnimationSpec(startSeconds: 1.5, durationSeconds: 1, framesPerSecond: 10)
        let stamps = spec.frameTimestamps()
        #expect(stamps.allSatisfy { $0 >= 1.5 && $0 <= 2.5 })
        #expect(stamps.count == 10)
    }

    @Test("A zero-length trim still yields one frame")
    func degenerateAnimation() {
        let spec = AnimationSpec(durationSeconds: 0, framesPerSecond: 0)
        #expect(spec.frameCount == 1)
        #expect(spec.frameDurationMilliseconds >= 1)
    }
}
