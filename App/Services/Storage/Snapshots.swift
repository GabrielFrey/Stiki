import Foundation
import StikiCore

/// An immutable, `Sendable` view of a stored sticker.
///
/// Views and background services never touch `@Model` objects, which belong to
/// the main actor's `ModelContext`. They work with snapshots instead, so
/// rendering and exporting can run on their own actors without smuggling a
/// managed object across an isolation boundary.
struct StickerSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var emojiTags: [String]
    var isAnimated: Bool
    var frameCount: Int
    var frameDurationMilliseconds: Int
    var renderedFileName: String?
    var renderedPixelSize: PixelSize
    var renderedByteCount: Int
    var renderedFormat: StickerFormat
    var recipe: EditRecipe?
    var updatedAt: Date
    /// Names of the packs this sticker belongs to, for the library's context
    /// menu and the "edit updates every pack" message.
    var packNames: [String]

    /// Label VoiceOver reads for the sticker tile.
    var accessibilityDescription: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if !emojiTags.isEmpty { return emojiTags.joined(separator: " ") }
        return String(localized: "Untitled sticker")
    }

    var animationDurationMilliseconds: Int {
        isAnimated ? frameCount * frameDurationMilliseconds : 0
    }
}

/// An immutable view of a pack and its ordered stickers.
struct PackSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var sortIndex: Int
    var trayIconFileName: String?
    var trayIconByteCount: Int
    var trayStickerID: UUID?
    var updatedAt: Date
    /// Stickers in user order; `emojiTags` are this pack's tags, which may
    /// differ from the sticker's defaults.
    var stickers: [StickerSnapshot]

    var isEmpty: Bool { stickers.isEmpty }
    var containsAnimated: Bool { stickers.contains(where: \.isAnimated) }

    /// Cover sticker: the one the user picked, else the first.
    var coverSticker: StickerSnapshot? {
        if let trayStickerID, let match = stickers.first(where: { $0.id == trayStickerID }) {
            return match
        }
        return stickers.first
    }
}

/// Projects stored stickers into the specs the validator checks.
///
/// Readiness badges must not accuse the user of problems the exporter fixes on
/// its own. The library caches one master render (a large PNG), while each
/// target gets its own canvas and format at export time, so the projection
/// substitutes the target's canvas and format and leaves byte counts at the
/// measured value from the last real export — zero when there has not been
/// one. Structural rules (pack size, name, emoji tags, animation length,
/// frame timing) are fully decidable up front, and those are exactly the ones
/// that silently break hand-off today.
enum ExportProjection {
    static func projectedSticker(
        _ sticker: StickerSnapshot,
        target: ExportTarget,
        measuredBytes: Int = 0
    ) -> StickerSpec {
        let limits = ExportLimits.limits(for: target)
        let isAnimated = sticker.isAnimated && limits.supportsAnimation
        let canvas = limits.canvas.fittedSize(for: SizeFitting.squared(sticker.renderedPixelSize))
        let frameDuration = max(
            sticker.frameDurationMilliseconds,
            isAnimated ? (limits.minFrameDurationMilliseconds ?? 0) : 0
        )

        return StickerSpec(
            id: sticker.id,
            name: sticker.accessibilityDescription,
            pixelSize: canvas,
            byteCount: measuredBytes,
            format: limits.preferredFormat(isAnimated: isAnimated),
            emojiTags: sticker.emojiTags,
            frameCount: isAnimated ? sticker.frameCount : 1,
            frameDurationMilliseconds: isAnimated ? frameDuration : 0
        )
    }

    static func projectedPack(
        _ pack: PackSnapshot,
        target: ExportTarget,
        authorName: String,
        measuredBytes: [UUID: Int] = [:],
        trayIcon: TrayIconSpec? = nil
    ) -> PackSpec {
        let limits = ExportLimits.limits(for: target)
        let resolvedTray: TrayIconSpec? = {
            if let trayIcon { return trayIcon }
            guard let rule = limits.trayIcon else { return nil }
            // The exporter always generates the tray icon from the cover
            // sticker, so a pack with any sticker can satisfy the rule.
            guard pack.coverSticker != nil else { return nil }
            return TrayIconSpec(
                pixelSize: rule.size,
                byteCount: pack.trayIconByteCount,
                format: rule.format
            )
        }()

        return PackSpec(
            id: pack.id,
            name: pack.name,
            authorName: authorName,
            stickers: pack.stickers.map {
                projectedSticker($0, target: target, measuredBytes: measuredBytes[$0.id] ?? 0)
            },
            trayIcon: resolvedTray
        )
    }

    /// Readiness for all badged targets, used by the library and pack grids.
    static func readiness(
        for pack: PackSnapshot,
        authorName: String
    ) -> [ExportTarget: Readiness] {
        var result: [ExportTarget: Readiness] = [:]
        for target in ExportTarget.badgedTargets {
            let spec = projectedPack(pack, target: target, authorName: authorName)
            result[target] = ExportValidator.validate(pack: spec, target: target).readiness
        }
        return result
    }
}
