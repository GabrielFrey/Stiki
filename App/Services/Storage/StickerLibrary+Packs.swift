import Foundation
import StikiCore
import SwiftData

extension StickerLibrary {
    // MARK: - Packs

    /// Creates a pack, enforcing the free-tier ceiling.
    ///
    /// The limit is checked here rather than in the paywall so no UI path can
    /// bypass it, and it throws a typed error the caller turns into the
    /// paywall prompt.
    @discardableResult
    func createPack(name: String, isPro: Bool) throws -> UUID {
        if !isPro, packs.count >= Self.freePackLimit {
            throw StikiError.packLimitReached(limit: Self.freePackLimit)
        }
        let nextIndex = (packs.map(\.sortIndex).max() ?? -1) + 1
        let entity = StickerPackEntity(name: name, sortIndex: nextIndex)
        modelContext.insert(entity)
        try persist()
        return entity.packID
    }

    func renamePack(id: UUID, to name: String) throws {
        guard let entity = try fetchPack(id: id) else { return }
        entity.name = name
        entity.updatedAt = Date()
        try persist()
    }

    /// Deletes a pack. Stickers survive: they live in the library, and a pack
    /// is only an arrangement of them.
    func deletePack(id: UUID) async throws {
        guard let entity = try fetchPack(id: id) else { return }
        let trayFileName = entity.trayIconFileName
        modelContext.delete(entity)
        try persist()
        if let trayFileName {
            await assetStore.deleteRendered(fileName: trayFileName)
        }
    }

    @discardableResult
    func duplicatePack(id: UUID, isPro: Bool) throws -> UUID? {
        guard let source = try fetchPack(id: id) else { return nil }
        if !isPro, packs.count >= Self.freePackLimit {
            throw StikiError.packLimitReached(limit: Self.freePackLimit)
        }
        let nextIndex = (packs.map(\.sortIndex).max() ?? -1) + 1
        let copyName = String(
            format: String(localized: "%@ copy"),
            source.name
        )
        let copy = StickerPackEntity(name: copyName, sortIndex: nextIndex)
        copy.trayStickerID = source.trayStickerID
        modelContext.insert(copy)

        for membership in source.orderedMemberships {
            let duplicate = PackMembershipEntity(
                order: membership.order,
                emojiTags: membership.emojiTags,
                pack: copy,
                sticker: membership.sticker
            )
            modelContext.insert(duplicate)
        }

        try persist()
        return copy.packID
    }

    func reorderPacks(fromOffsets source: IndexSet, toOffset destination: Int) throws {
        var ordered = packs
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, snapshot) in ordered.enumerated() {
            if let entity = try fetchPack(id: snapshot.id) {
                entity.sortIndex = index
            }
        }
        try persist()
    }

    // MARK: - Membership

    /// Adds a sticker to a pack, or does nothing if it is already there.
    func addSticker(_ stickerID: UUID, toPack packID: UUID, emojiTags: [String]? = nil) throws {
        guard let pack = try fetchPack(id: packID),
              let sticker = try fetchStickerEntity(id: stickerID) else { return }
        guard !pack.memberships.contains(where: { $0.sticker?.stickerID == stickerID }) else { return }

        let nextOrder = (pack.memberships.map(\.order).max() ?? -1) + 1
        let tags = emojiTags ?? (sticker.emojiTags.isEmpty
            ? EmojiTagSuggestions.suggestions(excluding: [], count: 1)
            : sticker.emojiTags)
        let membership = PackMembershipEntity(
            order: nextOrder,
            emojiTags: tags,
            pack: pack,
            sticker: sticker
        )
        modelContext.insert(membership)
        pack.updatedAt = Date()
        try persist()
    }

    func removeSticker(_ stickerID: UUID, fromPack packID: UUID) throws {
        guard let pack = try fetchPack(id: packID) else { return }
        for membership in pack.memberships where membership.sticker?.stickerID == stickerID {
            modelContext.delete(membership)
        }
        pack.updatedAt = Date()
        try persist()
    }

    /// Reorders stickers inside a pack; order is what messengers display.
    func moveStickers(inPack packID: UUID, fromOffsets source: IndexSet, toOffset destination: Int) throws {
        guard let pack = try fetchPack(id: packID) else { return }
        var ordered = pack.orderedMemberships
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, membership) in ordered.enumerated() {
            membership.order = index
        }
        pack.updatedAt = Date()
        try persist()
    }

    /// Picks which sticker's artwork represents the pack.
    func setTraySticker(_ stickerID: UUID?, forPack packID: UUID) throws {
        guard let pack = try fetchPack(id: packID) else { return }
        pack.trayStickerID = stickerID
        // The rendered tray file is now stale.
        pack.trayIconFileName = nil
        pack.trayIconByteCount = 0
        pack.updatedAt = Date()
        try persist()
    }

    /// Records the tray icon the exporter generated, so the validator can see
    /// its real weight next time.
    func updateTrayIcon(fileName: String, byteCount: Int, forPack packID: UUID) throws {
        guard let pack = try fetchPack(id: packID) else { return }
        pack.trayIconFileName = fileName
        pack.trayIconByteCount = byteCount
        try persist()
    }

    /// Packs a sticker is not yet in, for the "Add to pack" menu.
    func packsNotContaining(stickerID: UUID) -> [PackSnapshot] {
        packs.filter { pack in !pack.stickers.contains { $0.id == stickerID } }
    }
}
