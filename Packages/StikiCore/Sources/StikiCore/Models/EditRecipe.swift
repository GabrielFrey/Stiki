import Foundation

/// The complete, replayable description of one sticker.
///
/// A recipe is the heart of non-destructive editing: it holds references to the
/// untouched source and mask plus every effect the user picked, so the renderer
/// can rebuild the sticker at any size, and the editor can reopen it later —
/// including for stickers that already live inside a pack.
///
/// Recipes are versioned. ``init(from:)`` accepts every historical layout, so an
/// old library keeps opening after an app update.
public struct EditRecipe: Codable, Hashable, Sendable {
    /// Version written by this build.
    ///
    /// - 1: initial layout, single `filter`, no emoji layers, no background.
    /// - 2: `filters` array, `emojiLayers`, `background`, `animation`.
    public static let currentVersion = 2

    public var version: Int
    public var source: AssetRef
    /// Grayscale mask produced by subject lifting, or `nil` for "keep whole
    /// image" (meme mode).
    public var mask: AssetRef?
    public var transform: LayerTransform
    public var outline: OutlineSpec?
    public var dropShadow: DropShadowSpec?
    public var filters: [FilterSpec]
    public var textLayers: [TextLayer]
    public var emojiLayers: [EmojiLayer]
    public var background: BackgroundSpec
    /// Present only for animated stickers.
    public var animation: AnimationSpec?

    public init(
        version: Int = EditRecipe.currentVersion,
        source: AssetRef,
        mask: AssetRef? = nil,
        transform: LayerTransform = .identity,
        outline: OutlineSpec? = .default,
        dropShadow: DropShadowSpec? = nil,
        filters: [FilterSpec] = [],
        textLayers: [TextLayer] = [],
        emojiLayers: [EmojiLayer] = [],
        background: BackgroundSpec = .transparent,
        animation: AnimationSpec? = nil
    ) {
        self.version = version
        self.source = source
        self.mask = mask
        self.transform = transform
        self.outline = outline
        self.dropShadow = dropShadow
        self.filters = filters
        self.textLayers = textLayers
        self.emojiLayers = emojiLayers
        self.background = background
        self.animation = animation
    }

    public var isAnimated: Bool { animation != nil }

    /// `true` when the recipe uses an effect gated behind Pro.
    public var requiresPro: Bool {
        if isAnimated { return true }
        if filters.contains(where: { $0.kind.requiresPro }) { return true }
        if let outline, outline.style == .glow || outline.style == .puffy { return true }
        return false
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case version
        case source
        case mask
        case transform
        case outline
        case dropShadow
        case filters
        case textLayers
        case emojiLayers
        case background
        case animation
        /// Version 1 stored at most one filter under this key.
        case filter
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard decodedVersion <= EditRecipe.currentVersion else {
            throw StikiCoreError.unsupportedRecipeVersion(
                found: decodedVersion,
                supported: EditRecipe.currentVersion
            )
        }

        source = try container.decode(AssetRef.self, forKey: .source)
        mask = try container.decodeIfPresent(AssetRef.self, forKey: .mask)
        transform = try container.decodeIfPresent(LayerTransform.self, forKey: .transform) ?? .identity
        outline = try container.decodeIfPresent(OutlineSpec.self, forKey: .outline)
        dropShadow = try container.decodeIfPresent(DropShadowSpec.self, forKey: .dropShadow)
        textLayers = try container.decodeIfPresent([TextLayer].self, forKey: .textLayers) ?? []
        emojiLayers = try container.decodeIfPresent([EmojiLayer].self, forKey: .emojiLayers) ?? []
        background = try container.decodeIfPresent(BackgroundSpec.self, forKey: .background) ?? .transparent
        animation = try container.decodeIfPresent(AnimationSpec.self, forKey: .animation)

        if let filters = try container.decodeIfPresent([FilterSpec].self, forKey: .filters) {
            self.filters = filters
        } else if let legacyFilter = try container.decodeIfPresent(FilterSpec.self, forKey: .filter) {
            self.filters = [legacyFilter]
        } else {
            self.filters = []
        }

        // Older payloads are upgraded in place; the next save writes v2.
        version = EditRecipe.currentVersion
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(EditRecipe.currentVersion, forKey: .version)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(mask, forKey: .mask)
        try container.encode(transform, forKey: .transform)
        try container.encodeIfPresent(outline, forKey: .outline)
        try container.encodeIfPresent(dropShadow, forKey: .dropShadow)
        try container.encode(filters, forKey: .filters)
        try container.encode(textLayers, forKey: .textLayers)
        try container.encode(emojiLayers, forKey: .emojiLayers)
        try container.encode(background, forKey: .background)
        try container.encodeIfPresent(animation, forKey: .animation)
    }
}

extension EditRecipe {
    /// Encoder shared by the app and the iMessage extension so recipe files
    /// stay byte-stable between writes.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public func encoded() throws -> Data {
        try EditRecipe.makeEncoder().encode(self)
    }

    public static func decoded(from data: Data) throws -> EditRecipe {
        do {
            return try makeDecoder().decode(EditRecipe.self, from: data)
        } catch let error as StikiCoreError {
            throw error
        } catch {
            throw StikiCoreError.recipeDecodingFailed(underlying: String(describing: error))
        }
    }
}
