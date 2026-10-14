import StikiCore
import XCTest
@testable import Stiki

/// Pack-level readiness without rendering, which is what the library badges
/// show. WhatsApp still requires three stickers; a single-sticker pack is
/// therefore amber (fixable by duplication), never green.
final class ExportProjectionTests: XCTestCase {
    func testWhatsAppNeedsThreeStickers() {
        let sticker = StickerSnapshot(
            id: UUID(),
            name: "One",
            emojiTags: ["😀"],
            isAnimated: false,
            frameCount: 1,
            frameDurationMilliseconds: 0,
            renderedFileName: "a.png",
            renderedPixelSize: .square(512),
            renderedByteCount: 40_000,
            renderedFormat: .png,
            recipe: nil,
            updatedAt: Date(),
            packNames: ["P"]
        )
        let pack = PackSnapshot(
            id: UUID(),
            name: "P",
            sortIndex: 0,
            trayIconFileName: nil,
            trayIconByteCount: 0,
            trayStickerID: nil,
            updatedAt: Date(),
            stickers: [sticker]
        )
        let readiness = ExportProjection.readiness(for: pack, authorName: "Stiki")
        XCTAssertEqual(readiness[.whatsApp], .fixable)
        XCTAssertEqual(readiness[.telegram], .ready)
        XCTAssertEqual(readiness[.iMessage], .ready)
    }

    func testReadyWhatsAppPack() {
        let stickers = (0..<3).map { index in
            StickerSnapshot(
                id: UUID(),
                name: "S\(index)",
                emojiTags: ["😀"],
                isAnimated: false,
                frameCount: 1,
                frameDurationMilliseconds: 0,
                renderedFileName: "\(index).png",
                renderedPixelSize: .square(512),
                renderedByteCount: 40_000,
                renderedFormat: .png,
                recipe: nil,
                updatedAt: Date(),
                packNames: ["Cats"]
            )
        }
        let pack = PackSnapshot(
            id: UUID(),
            name: "Cats",
            sortIndex: 0,
            trayIconFileName: "tray.png",
            trayIconByteCount: 12_000,
            trayStickerID: stickers[0].id,
            updatedAt: Date(),
            stickers: stickers
        )
        XCTAssertEqual(
            ExportProjection.readiness(for: pack, authorName: "Stiki")[.whatsApp],
            .ready
        )
    }
}
