import Foundation

/// Names of the directories and files the app and the iMessage extension share
/// through the App Group container.
public enum SharedPaths {
    public static let appGroupIdentifier = "group.com.stiki.shared"
    /// Immutable originals and masks referenced by recipes.
    public static let assetsDirectory = "Assets"
    /// Rendered sticker images, one subdirectory per pack.
    public static let renderedDirectory = "Rendered"
    /// Files staged for a share sheet or a messenger hand-off.
    public static let exportsDirectory = "Exports"
    /// Manifest the iMessage extension reads.
    public static let catalogFileName = "catalog.json"
    /// SwiftData store, kept in the group so the app and any future extension
    /// see the same library.
    public static let storeFileName = "Stiki.store"
}

/// The sticker catalog the iMessage extension renders from.
///
/// The extension deliberately does not open SwiftData: a message extension is
/// memory constrained and is launched by Messages at unpredictable times, so it
/// reads one small JSON manifest plus PNG files the app has already rendered.
/// The app rewrites the manifest after every library change.
public struct SharedStickerCatalog: Codable, Hashable, Sendable {
    public var generatedAt: Date
    public var packs: [SharedPack]

    public init(generatedAt: Date = Date(), packs: [SharedPack]) {
        self.generatedAt = generatedAt
        self.packs = packs
    }

    public static let empty = SharedStickerCatalog(generatedAt: .distantPast, packs: [])

    public var totalStickerCount: Int { packs.reduce(0) { $0 + $1.stickers.count } }

    public func pack(id: UUID) -> SharedPack? { packs.first { $0.id == id } }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decoded(from data: Data) throws -> SharedStickerCatalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SharedStickerCatalog.self, from: data)
    }
}

public struct SharedPack: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    /// Tray image relative to the rendered directory, used as the pack's tab.
    public var trayFileName: String?
    public var stickers: [SharedSticker]

    public init(id: UUID, name: String, trayFileName: String? = nil, stickers: [SharedSticker]) {
        self.id = id
        self.name = name
        self.trayFileName = trayFileName
        self.stickers = stickers
    }
}

public struct SharedSticker: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    /// Path relative to the rendered directory.
    public var fileName: String
    /// VoiceOver description; Messages also uses it as the sticker's
    /// accessibility label, so emoji tags are folded into it.
    public var accessibilityDescription: String
    public var emojiTags: [String]
    public var isAnimated: Bool

    public init(
        id: UUID,
        fileName: String,
        accessibilityDescription: String,
        emojiTags: [String] = [],
        isAnimated: Bool = false
    ) {
        self.id = id
        self.fileName = fileName
        self.accessibilityDescription = accessibilityDescription
        self.emojiTags = emojiTags
        self.isAnimated = isAnimated
    }

    /// Label Messages reads aloud: the sticker's own description, falling back
    /// to its emoji tags when the user never named it.
    public var resolvedAccessibilityLabel: String {
        let trimmed = accessibilityDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !emojiTags.isEmpty { return emojiTags.joined(separator: " ") }
        return "Sticker"
    }
}
