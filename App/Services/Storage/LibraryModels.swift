import Foundation
import StikiCore
import SwiftData

/// A sticker in the library.
///
/// The entity stores the *recipe* plus a cache of the last render. That split
/// is what makes editing non-destructive: the render can be thrown away and
/// rebuilt at any size, and a sticker that already lives in packs can be
/// reopened in the editor because its ingredients were never flattened away.
///
/// Every property has a default value and no `@Attribute(.unique)` constraint,
/// because the same schema is used with `ModelConfiguration(cloudKitDatabase:)`
/// when a Pro user turns on iCloud sync, and CloudKit rejects both unique
/// constraints and non-optional properties without defaults.
@Model
final class StickerEntity {
    var stickerID: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// JSON of an ``EditRecipe``.
    var recipeData: Data = Data()
    /// User-facing name, also used as the VoiceOver description.
    var name: String = ""
    /// Default emoji tags, copied into each pack membership when added.
    var emojiTags: [String] = []
    var isAnimated: Bool = false
    var frameCount: Int = 1
    var frameDurationMilliseconds: Int = 0

    /// Cached render used by the library grid and the iMessage extension.
    var renderedFileName: String?
    var renderedWidth: Int = 0
    var renderedHeight: Int = 0
    var renderedByteCount: Int = 0
    var renderedFormatRawValue: String = StickerFormat.png.rawValue

    /// Denormalised asset names, so unreferenced files can be pruned without
    /// decoding every recipe.
    var sourceFileName: String = ""
    var maskFileName: String?

    @Relationship(deleteRule: .cascade, inverse: \PackMembershipEntity.sticker)
    var memberships: [PackMembershipEntity] = []

    init(
        stickerID: UUID = UUID(),
        name: String = "",
        recipeData: Data,
        sourceFileName: String,
        maskFileName: String? = nil,
        emojiTags: [String] = [],
        isAnimated: Bool = false,
        frameCount: Int = 1,
        frameDurationMilliseconds: Int = 0
    ) {
        self.stickerID = stickerID
        self.name = name
        self.recipeData = recipeData
        self.sourceFileName = sourceFileName
        self.maskFileName = maskFileName
        self.emojiTags = emojiTags
        self.isAnimated = isAnimated
        self.frameCount = frameCount
        self.frameDurationMilliseconds = frameDurationMilliseconds
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var recipe: EditRecipe? {
        try? EditRecipe.decoded(from: recipeData)
    }

    var renderedFormat: StickerFormat {
        StickerFormat(rawValue: renderedFormatRawValue) ?? .png
    }

    var renderedPixelSize: PixelSize {
        PixelSize(width: renderedWidth, height: renderedHeight)
    }
}

/// A named collection of stickers.
@Model
final class StickerPackEntity {
    var packID: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Rendered 96×96 tray image for WhatsApp, if one has been generated.
    var trayIconFileName: String?
    var trayIconByteCount: Int = 0
    /// The sticker whose artwork is used for the tray icon and pack cover.
    var trayStickerID: UUID?
    /// Position in the Packs tab.
    var sortIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \PackMembershipEntity.pack)
    var memberships: [PackMembershipEntity] = []

    init(packID: UUID = UUID(), name: String, sortIndex: Int = 0) {
        self.packID = packID
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Memberships in the order the user arranged them.
    var orderedMemberships: [PackMembershipEntity] {
        memberships.sorted { $0.order < $1.order }
    }
}

/// Join entity between a sticker and a pack.
///
/// A sticker can appear in several packs, and each messenger wants its own
/// emoji tags and ordering, so membership carries that per-pack state. Editing
/// the sticker itself therefore updates every pack at once, which is the
/// behaviour competitors get wrong.
@Model
final class PackMembershipEntity {
    var membershipID: UUID = UUID()
    var order: Int = 0
    /// Emoji the messenger associates with this sticker in this pack.
    var emojiTags: [String] = []
    var pack: StickerPackEntity?
    var sticker: StickerEntity?

    init(
        membershipID: UUID = UUID(),
        order: Int,
        emojiTags: [String] = [],
        pack: StickerPackEntity? = nil,
        sticker: StickerEntity? = nil
    ) {
        self.membershipID = membershipID
        self.order = order
        self.emojiTags = emojiTags
        self.pack = pack
        self.sticker = sticker
    }
}
