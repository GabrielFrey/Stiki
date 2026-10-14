import Foundation
import Testing
@testable import StikiCore

@Suite("Shared catalog")
struct SharedCatalogTests {
    @Test("The catalog round-trips through the App Group manifest")
    func roundTrip() throws {
        let catalog = SharedStickerCatalog(
            generatedAt: Date(timeIntervalSince1970: 1_760_000_000),
            packs: [
                SharedPack(
                    id: UUID(),
                    name: "Cats",
                    trayFileName: "tray.png",
                    stickers: [
                        SharedSticker(
                            id: UUID(),
                            fileName: "a.png",
                            accessibilityDescription: "Cat waving",
                            emojiTags: ["🐱"],
                            isAnimated: false
                        )
                    ]
                )
            ]
        )
        let decoded = try SharedStickerCatalog.decoded(from: try catalog.encoded())
        #expect(decoded == catalog)
        #expect(decoded.totalStickerCount == 1)
        #expect(decoded.pack(id: catalog.packs[0].id)?.name == "Cats")
    }

    @Test("A sticker without a description falls back to its emoji tags")
    func accessibilityFallback() {
        let described = SharedSticker(
            id: UUID(),
            fileName: "a.png",
            accessibilityDescription: "Dog in sunglasses",
            emojiTags: ["🐶"]
        )
        #expect(described.resolvedAccessibilityLabel == "Dog in sunglasses")

        let untitled = SharedSticker(
            id: UUID(),
            fileName: "b.png",
            accessibilityDescription: "  ",
            emojiTags: ["🔥", "✨"]
        )
        #expect(untitled.resolvedAccessibilityLabel == "🔥 ✨")

        let bare = SharedSticker(id: UUID(), fileName: "c.png", accessibilityDescription: "")
        #expect(bare.resolvedAccessibilityLabel == "Sticker")
    }

    @Test("An empty catalog is a valid starting state")
    func emptyCatalog() throws {
        #expect(SharedStickerCatalog.empty.totalStickerCount == 0)
        let decoded = try SharedStickerCatalog.decoded(from: try SharedStickerCatalog.empty.encoded())
        #expect(decoded.packs.isEmpty)
    }
}

@Suite("WhatsApp pack payload")
struct WhatsAppPackPayloadTests {
    @Test("Keys match WhatsApp's published pasteboard contract")
    func keyNames() throws {
        let payload = WhatsAppPackPayload(
            identifier: "com.stiki.pack.abc",
            name: "Cats",
            publisher: "Stiki",
            trayImageData: "dHJheQ==",
            stickers: [WhatsAppPackPayload.Sticker(imageData: "c3RpY2tlcg==", emojis: ["🐱"])]
        )
        let json = try JSONSerialization.jsonObject(with: try payload.serialized()) as? [String: Any]
        #expect(json?["tray_image"] as? String == "dHJheQ==")
        #expect(json?["image_data_version"] as? String == "1")
        #expect(json?["avoid_cache"] as? Bool == false)
        let stickers = json?["stickers"] as? [[String: Any]]
        #expect(stickers?.first?["image_data"] as? String == "c3RpY2tlcg==")
        #expect(stickers?.first?["emojis"] as? [String] == ["🐱"])
        #expect(WhatsAppPackPayload.pasteboardType == "net.whatsapp.third-party.sticker-pack")
    }

    @Test("Pack identifiers are stable per pack so WhatsApp updates in place")
    func stableIdentifier() {
        let id = UUID()
        #expect(WhatsAppPackPayload.identifier(for: id) == WhatsAppPackPayload.identifier(for: id))
        #expect(WhatsAppPackPayload.identifier(for: id).hasPrefix("com.stiki.pack."))
        #expect(WhatsAppPackPayload.identifier(for: id) != WhatsAppPackPayload.identifier(for: UUID()))
    }

    @Test("Optional store links are omitted rather than sent as null")
    func optionalsOmitted() throws {
        let payload = WhatsAppPackPayload(
            identifier: "id",
            name: "n",
            publisher: "p",
            trayImageData: "",
            stickers: []
        )
        let json = try JSONSerialization.jsonObject(with: try payload.serialized()) as? [String: Any]
        #expect(json?["ios_app_store_link"] == nil)
        #expect(json?["publisher_website"] == nil)
    }
}
