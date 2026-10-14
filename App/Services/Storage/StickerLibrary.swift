import Foundation
import StikiCore
import SwiftData
import os

/// The library: the single writer of stickers, packs and their files.
///
/// Persistence, the rendered-file cache and the App Group manifest the iMessage
/// extension reads must never disagree, so every mutation goes through this
/// type: it writes SwiftData, writes or removes the rendered file, and
/// rewrites the manifest in one step.
@MainActor
@Observable
final class StickerLibrary {
    /// Packs the free tier allows before Pro is required.
    static let freePackLimit = 3

    private(set) var stickers: [StickerSnapshot] = []
    private(set) var packs: [PackSnapshot] = []
    private(set) var isLoading = false
    /// Non-fatal problem from the last operation, surfaced by the UI.
    var lastError: StikiError?

    let modelContext: ModelContext
    let assetStore: AssetStore
    private let logger = Logger(subsystem: "com.stiki.app", category: "Library")

    init(modelContainer: ModelContainer, assetStore: AssetStore) {
        self.modelContext = ModelContext(modelContainer)
        self.assetStore = assetStore
    }

    // MARK: - Reading

    func reload() {
        isLoading = true
        defer { isLoading = false }
        do {
            let stickerEntities = try modelContext.fetch(
                FetchDescriptor<StickerEntity>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            )
            let packEntities = try modelContext.fetch(
                FetchDescriptor<StickerPackEntity>(sortBy: [SortDescriptor(\.sortIndex)])
            )
            stickers = stickerEntities.map(Self.snapshot(of:))
            packs = packEntities.map(Self.snapshot(of:))
        } catch {
            logger.error("Library fetch failed: \(error.localizedDescription, privacy: .public)")
            lastError = .renderFailed(error.localizedDescription)
        }
    }

    var hasContent: Bool { !stickers.isEmpty }

    func sticker(id: UUID) -> StickerSnapshot? { stickers.first { $0.id == id } }
    func pack(id: UUID) -> PackSnapshot? { packs.first { $0.id == id } }

    // MARK: - Stickers

    /// Inserts a new sticker, or replaces the recipe and render of an existing
    /// one. Editing in place is what keeps packs up to date automatically.
    @discardableResult
    func upsertSticker(
        id: UUID? = nil,
        recipe: EditRecipe,
        render: RenderedImage,
        name: String? = nil,
        emojiTags: [String]? = nil
    ) async throws -> UUID {
        let entity: StickerEntity
        if let id, let existing = try fetchStickerEntity(id: id) {
            entity = existing
        } else {
            entity = StickerEntity(
                stickerID: id ?? UUID(),
                recipeData: try recipe.encoded(),
                sourceFileName: recipe.source.fileName
            )
            modelContext.insert(entity)
        }

        let fileName = "\(entity.stickerID.uuidString).\(render.format.fileExtension)"
        _ = try await assetStore.writeRendered(render.data, fileName: fileName)

        if let previous = entity.renderedFileName, previous != fileName {
            await assetStore.deleteRendered(fileName: previous)
        }

        entity.recipeData = try recipe.encoded()
        entity.sourceFileName = recipe.source.fileName
        entity.maskFileName = recipe.mask?.fileName
        entity.isAnimated = render.isAnimated
        entity.frameCount = render.frameCount
        entity.frameDurationMilliseconds = render.frameDurationMilliseconds
        entity.renderedFileName = fileName
        entity.renderedWidth = render.pixelSize.width
        entity.renderedHeight = render.pixelSize.height
        entity.renderedByteCount = render.data.count
        entity.renderedFormatRawValue = render.format.rawValue
        entity.updatedAt = Date()
        if let name { entity.name = name }
        if let emojiTags {
            entity.emojiTags = emojiTags
            // Memberships created before the user picked tags inherit them.
            for membership in entity.memberships where membership.emojiTags.isEmpty {
                membership.emojiTags = emojiTags
            }
        }

        try persist()
        return entity.stickerID
    }

    func rename(stickerID: UUID, to name: String) throws {
        guard let entity = try fetchStickerEntity(id: stickerID) else { return }
        entity.name = name
        entity.updatedAt = Date()
        try persist()
    }

    func setEmojiTags(_ tags: [String], stickerID: UUID, packID: UUID? = nil) throws {
        guard let entity = try fetchStickerEntity(id: stickerID) else { return }
        if let packID {
            entity.memberships
                .filter { $0.pack?.packID == packID }
                .forEach { $0.emojiTags = tags }
        } else {
            entity.emojiTags = tags
            entity.memberships.forEach { $0.emojiTags = tags }
        }
        entity.updatedAt = Date()
        try persist()
    }

    func deleteSticker(id: UUID) async throws {
        guard let entity = try fetchStickerEntity(id: id) else { return }
        let renderedFileName = entity.renderedFileName
        modelContext.delete(entity)
        try persist()
        if let renderedFileName {
            await assetStore.deleteRendered(fileName: renderedFileName)
        }
        await pruneOrphanedAssets()
    }

    /// Duplicates a sticker, including its recipe, so the user can try a
    /// variation without losing the original.
    @discardableResult
    func duplicateSticker(id: UUID) async throws -> UUID? {
        guard let entity = try fetchStickerEntity(id: id) else { return nil }
        let copy = StickerEntity(
            name: entity.name,
            recipeData: entity.recipeData,
            sourceFileName: entity.sourceFileName,
            maskFileName: entity.maskFileName,
            emojiTags: entity.emojiTags,
            isAnimated: entity.isAnimated,
            frameCount: entity.frameCount,
            frameDurationMilliseconds: entity.frameDurationMilliseconds
        )
        modelContext.insert(copy)

        if let sourceFile = entity.renderedFileName {
            let data = try await assetStore.renderedData(fileName: sourceFile)
            let fileName = "\(copy.stickerID.uuidString).\(entity.renderedFormat.fileExtension)"
            _ = try await assetStore.writeRendered(data, fileName: fileName)
            copy.renderedFileName = fileName
            copy.renderedWidth = entity.renderedWidth
            copy.renderedHeight = entity.renderedHeight
            copy.renderedByteCount = entity.renderedByteCount
            copy.renderedFormatRawValue = entity.renderedFormatRawValue
        }

        try persist()
        return copy.stickerID
    }

    // MARK: - Saving

    /// Saves, refreshes snapshots and republishes the extension manifest.
    func persist() throws {
        try modelContext.save()
        reload()
        syncCatalog()
    }

    func fetchStickerEntity(id: UUID) throws -> StickerEntity? {
        var descriptor = FetchDescriptor<StickerEntity>(predicate: #Predicate { $0.stickerID == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchPack(id: UUID) throws -> StickerPackEntity? {
        var descriptor = FetchDescriptor<StickerPackEntity>(predicate: #Predicate { $0.packID == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Rewrites the App Group manifest in the background.
    ///
    /// Fire-and-forget on purpose: the user should never wait on the extension
    /// cache, and the next mutation rewrites it anyway.
    private func syncCatalog() {
        let catalog = CatalogBuilder.build(packs: packs, looseStickers: looseStickers)
        let store = assetStore
        Task.detached(priority: .utility) {
            do {
                try await store.writeCatalog(catalog)
            } catch {
                Logger(subsystem: "com.stiki.app", category: "Library")
                    .error("Catalog write failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Stickers that belong to no pack, shown in the extension as "Unsorted".
    private var looseStickers: [StickerSnapshot] {
        stickers.filter { $0.packNames.isEmpty }
    }

    private func pruneOrphanedAssets() async {
        let referenced = Set(
            stickers.flatMap { snapshot -> [String] in
                guard let recipe = snapshot.recipe else { return [] }
                return [recipe.source.fileName, recipe.mask?.fileName].compactMap { $0 }
            }
        )
        await assetStore.pruneAssets(keeping: referenced)
    }

    // MARK: - Snapshots

    private static func snapshot(of entity: StickerEntity) -> StickerSnapshot {
        StickerSnapshot(
            id: entity.stickerID,
            name: entity.name,
            emojiTags: entity.emojiTags,
            isAnimated: entity.isAnimated,
            frameCount: entity.frameCount,
            frameDurationMilliseconds: entity.frameDurationMilliseconds,
            renderedFileName: entity.renderedFileName,
            renderedPixelSize: entity.renderedPixelSize,
            renderedByteCount: entity.renderedByteCount,
            renderedFormat: entity.renderedFormat,
            recipe: entity.recipe,
            updatedAt: entity.updatedAt,
            packNames: entity.memberships.compactMap { $0.pack?.name }.sorted()
        )
    }

    private static func snapshot(of entity: StickerPackEntity) -> PackSnapshot {
        PackSnapshot(
            id: entity.packID,
            name: entity.name,
            sortIndex: entity.sortIndex,
            trayIconFileName: entity.trayIconFileName,
            trayIconByteCount: entity.trayIconByteCount,
            trayStickerID: entity.trayStickerID,
            updatedAt: entity.updatedAt,
            stickers: entity.orderedMemberships.compactMap { membership in
                guard let sticker = membership.sticker else { return nil }
                var snapshot = Self.snapshot(of: sticker)
                // Inside a pack, the pack's own emoji tags win.
                snapshot.emojiTags = membership.emojiTags.isEmpty
                    ? sticker.emojiTags
                    : membership.emojiTags
                return snapshot
            }
        )
    }
}
