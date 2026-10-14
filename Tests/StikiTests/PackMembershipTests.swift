import StikiCore
import SwiftData
import XCTest
@testable import Stiki

/// Editing a sticker must update every pack it belongs to, which is the
/// behaviour competitors get wrong by flattening on insert.
final class PackMembershipTests: XCTestCase {
    @MainActor
    func testEditingAStickerUpdatesEveryPack() async throws {
        let environment = makeEnvironment()
        let recipe = try await sampleRecipe(in: environment)
        let render = RenderedImage(
            data: SampleImage.circlePNG(),
            pixelSize: .square(64),
            format: .png
        )
        let stickerID = try await environment.library.upsertSticker(
            recipe: recipe,
            render: render,
            name: "Cat",
            emojiTags: ["🐱"]
        )
        let packA = try environment.library.createPack(name: "A", isPro: true)
        let packB = try environment.library.createPack(name: "B", isPro: true)
        try environment.library.addSticker(stickerID, toPack: packA)
        try environment.library.addSticker(stickerID, toPack: packB)

        var updated = recipe
        updated.outline = OutlineSpec(style: .dashed)
        _ = try await environment.library.upsertSticker(
            id: stickerID,
            recipe: updated,
            render: render,
            name: "Cat dashed"
        )

        let inA = try XCTUnwrap(environment.library.pack(id: packA)?.stickers.first)
        let inB = try XCTUnwrap(environment.library.pack(id: packB)?.stickers.first)
        XCTAssertEqual(inA.name, "Cat dashed")
        XCTAssertEqual(inB.name, "Cat dashed")
        XCTAssertEqual(inA.recipe?.outline?.style, .dashed)
        XCTAssertEqual(inB.recipe?.outline?.style, .dashed)
        XCTAssertEqual(inA.id, inB.id)
    }

    @MainActor
    func testFreeTierPackLimit() throws {
        let environment = makeEnvironment()
        for index in 1...StickerLibrary.freePackLimit {
            _ = try environment.library.createPack(name: "P\(index)", isPro: false)
        }
        XCTAssertThrowsError(try environment.library.createPack(name: "Over", isPro: false)) { error in
            XCTAssertEqual(error as? StikiError, .packLimitReached(limit: StickerLibrary.freePackLimit))
        }
        XCTAssertNoThrow(try environment.library.createPack(name: "Pro pack", isPro: true))
    }

    @MainActor
    func testDeletingAPackKeepsTheSticker() async throws {
        let environment = makeEnvironment()
        let recipe = try await sampleRecipe(in: environment)
        let render = RenderedImage(
            data: SampleImage.circlePNG(),
            pixelSize: .square(64),
            format: .png
        )
        let stickerID = try await environment.library.upsertSticker(recipe: recipe, render: render, name: "Keep")
        let packID = try environment.library.createPack(name: "Temp", isPro: true)
        try environment.library.addSticker(stickerID, toPack: packID)
        try await environment.library.deletePack(id: packID)
        XCTAssertNotNil(environment.library.sticker(id: stickerID))
        XCTAssertTrue(environment.library.packs.isEmpty)
    }

    @MainActor
    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment.preview()
    }

    @MainActor
    private func sampleRecipe(in environment: AppEnvironment) async throws -> EditRecipe {
        let data = SampleImage.circlePNG()
        let ref = try await environment.assetStore.writeAsset(
            data,
            kind: .image,
            pixelSize: .square(64),
            fileExtension: "png"
        )
        return EditRecipe(source: ref)
    }
}
