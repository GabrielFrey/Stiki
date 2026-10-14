import Foundation

/// Everything that must change about one sticker for it to pass validation.
///
/// Issues are per-rule, but re-rendering is expensive, so the app collapses a
/// report into one plan per sticker and renders each sticker once.
public struct StickerFixPlan: Hashable, Sendable, Identifiable {
    public var stickerID: UUID
    public var targetSize: PixelSize?
    public var maxBytes: Int?
    public var format: StickerFormat?
    public var flattenAnimation: Bool
    public var maxDurationMilliseconds: Int?
    public var minFrameDurationMilliseconds: Int?
    /// How many emoji to append from the suggestion list.
    public var emojiTagsToAdd: Int
    /// Cap to apply to the emoji list, or `nil` to leave it alone.
    public var emojiTagsLimit: Int?

    public init(
        stickerID: UUID,
        targetSize: PixelSize? = nil,
        maxBytes: Int? = nil,
        format: StickerFormat? = nil,
        flattenAnimation: Bool = false,
        maxDurationMilliseconds: Int? = nil,
        minFrameDurationMilliseconds: Int? = nil,
        emojiTagsToAdd: Int = 0,
        emojiTagsLimit: Int? = nil
    ) {
        self.stickerID = stickerID
        self.targetSize = targetSize
        self.maxBytes = maxBytes
        self.format = format
        self.flattenAnimation = flattenAnimation
        self.maxDurationMilliseconds = maxDurationMilliseconds
        self.minFrameDurationMilliseconds = minFrameDurationMilliseconds
        self.emojiTagsToAdd = emojiTagsToAdd
        self.emojiTagsLimit = emojiTagsLimit
    }

    public var id: UUID { stickerID }

    /// `true` when the plan only changes metadata, so no re-render is needed.
    public var isMetadataOnly: Bool {
        targetSize == nil
            && maxBytes == nil
            && format == nil
            && !flattenAnimation
            && maxDurationMilliseconds == nil
            && minFrameDurationMilliseconds == nil
    }
}

/// Pack-level repairs that do not belong to any single sticker.
public struct PackFixPlan: Hashable, Sendable {
    public var truncateNameTo: Int?
    public var generateTrayIcon: PixelSize?
    public var trayIconMaxBytes: Int?
    public var trayIconFormat: StickerFormat?
    public var duplicateStickers: Int
    public var stickerPlans: [StickerFixPlan]

    public init(
        truncateNameTo: Int? = nil,
        generateTrayIcon: PixelSize? = nil,
        trayIconMaxBytes: Int? = nil,
        trayIconFormat: StickerFormat? = nil,
        duplicateStickers: Int = 0,
        stickerPlans: [StickerFixPlan] = []
    ) {
        self.truncateNameTo = truncateNameTo
        self.generateTrayIcon = generateTrayIcon
        self.trayIconMaxBytes = trayIconMaxBytes
        self.trayIconFormat = trayIconFormat
        self.duplicateStickers = duplicateStickers
        self.stickerPlans = stickerPlans
    }

    public var isEmpty: Bool {
        truncateNameTo == nil
            && generateTrayIcon == nil
            && trayIconMaxBytes == nil
            && trayIconFormat == nil
            && duplicateStickers == 0
            && stickerPlans.isEmpty
    }
}

extension ExportValidator {
    /// Collapses a report into one actionable plan.
    ///
    /// Issues without an ``AutoFix`` are ignored here — the UI surfaces those
    /// separately because they need a human.
    public static func fixPlan(for report: ValidationReport) -> PackFixPlan {
        var pack = PackFixPlan()
        var bySticker: [UUID: StickerFixPlan] = [:]
        var order: [UUID] = []

        for issue in report.issues {
            guard let fix = issue.autoFix else { continue }

            switch issue.scope {
            case .pack:
                switch fix {
                case let .truncatePackName(maxLength):
                    pack.truncateNameTo = maxLength
                case let .duplicateStickers(count):
                    pack.duplicateStickers = max(pack.duplicateStickers, count)
                default:
                    break
                }

            case .trayIcon:
                switch fix {
                case let .generateTrayIcon(size):
                    pack.generateTrayIcon = size
                case let .recompressTrayIcon(maxBytes):
                    pack.trayIconMaxBytes = maxBytes
                case let .convertTrayIcon(format):
                    pack.trayIconFormat = format
                default:
                    break
                }

            case let .sticker(id, _):
                if bySticker[id] == nil {
                    bySticker[id] = StickerFixPlan(stickerID: id)
                    order.append(id)
                }
                guard var plan = bySticker[id] else { continue }
                apply(fix, to: &plan)
                bySticker[id] = plan
            }
        }

        pack.stickerPlans = order.compactMap { bySticker[$0] }
        return pack
    }

    private static func apply(_ fix: AutoFix, to plan: inout StickerFixPlan) {
        switch fix {
        case let .resize(size):
            plan.targetSize = size
        case let .recompress(maxBytes):
            plan.maxBytes = min(plan.maxBytes ?? maxBytes, maxBytes)
        case let .convert(format):
            plan.format = format
        case .flattenAnimation:
            plan.flattenAnimation = true
        case let .trimAnimation(milliseconds):
            plan.maxDurationMilliseconds = milliseconds
        case let .slowFrames(milliseconds):
            plan.minFrameDurationMilliseconds = milliseconds
        case let .addDefaultEmojiTags(count):
            plan.emojiTagsToAdd = max(plan.emojiTagsToAdd, count)
        case let .dropExtraEmojiTags(keeping):
            plan.emojiTagsLimit = keeping
        case .duplicateStickers, .generateTrayIcon, .recompressTrayIcon,
             .convertTrayIcon, .truncatePackName:
            break
        }
    }
}
