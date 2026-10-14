import Foundation
import StikiCore

/// Builds the manifest the iMessage extension reads from the App Group.
///
/// The extension shows one tab per pack. Stickers that belong to no pack would
/// otherwise be invisible there, so they are gathered into a trailing
/// "Unsorted" group — a user who never made a pack still gets their stickers
/// in Messages.
enum CatalogBuilder {
    /// Identifier of the synthetic group holding pack-less stickers.
    static let unsortedPackID = UUID(uuidString: "00000000-0000-0000-0000-00000000F1FE") ?? UUID()

    static func build(packs: [PackSnapshot], looseStickers: [StickerSnapshot]) -> SharedStickerCatalog {
        var sharedPacks = packs.map { pack in
            SharedPack(
                id: pack.id,
                name: pack.name,
                trayFileName: pack.trayIconFileName ?? pack.coverSticker?.renderedFileName,
                stickers: pack.stickers.compactMap(sharedSticker(from:))
            )
        }

        let unsorted = looseStickers.compactMap(sharedSticker(from:))
        if !unsorted.isEmpty {
            sharedPacks.append(
                SharedPack(
                    id: unsortedPackID,
                    name: String(localized: "Unsorted"),
                    trayFileName: unsorted.first?.fileName,
                    stickers: unsorted
                )
            )
        }

        return SharedStickerCatalog(packs: sharedPacks.filter { !$0.stickers.isEmpty })
    }

    private static func sharedSticker(from snapshot: StickerSnapshot) -> SharedSticker? {
        guard let fileName = snapshot.renderedFileName else { return nil }
        return SharedSticker(
            id: snapshot.id,
            fileName: fileName,
            accessibilityDescription: snapshot.accessibilityDescription,
            emojiTags: snapshot.emojiTags,
            isAnimated: snapshot.isAnimated
        )
    }
}
