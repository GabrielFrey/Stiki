import Foundation

/// A single reason a pack is not ready for a target.
public struct ValidationIssue: Hashable, Sendable, Identifiable {
    public enum Severity: Int, Hashable, Sendable, Comparable {
        /// Hand-off will fail until this is resolved.
        case error = 2
        /// Hand-off works, but the result is degraded.
        case warning = 1

        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// What part of the pack the issue belongs to.
    public enum Scope: Hashable, Sendable {
        case pack
        case sticker(id: UUID, name: String)
        case trayIcon
    }

    public var scope: Scope
    public var problem: ValidationProblem

    public init(scope: Scope, problem: ValidationProblem) {
        self.scope = scope
        self.problem = problem
    }

    public var severity: Severity { problem.severity }

    /// Fix the app can perform without asking anything of the user.
    public var autoFix: AutoFix? { problem.autoFix }

    public var id: String {
        switch scope {
        case .pack:
            return "pack-\(problem.identifier)"
        case let .sticker(id, _):
            return "sticker-\(id.uuidString)-\(problem.identifier)"
        case .trayIcon:
            return "tray-\(problem.identifier)"
        }
    }

    /// English sentence for logs and tests; the app renders localized copy.
    public var englishDescription: String {
        switch scope {
        case .pack:
            return problem.englishDescription
        case let .sticker(_, name):
            let label = name.isEmpty ? "Sticker" : name
            return "\(label): \(problem.englishDescription)"
        case .trayIcon:
            return "Tray icon: \(problem.englishDescription)"
        }
    }
}

/// Everything that can be wrong with a pack, with the numbers needed to
/// explain and repair it.
public enum ValidationProblem: Hashable, Sendable {
    case tooFewStickers(count: Int, minimum: Int)
    case tooManyStickers(count: Int, maximum: Int)
    case wrongCanvasSize(actual: PixelSize, expected: PixelSize)
    case fileTooLarge(actualBytes: Int, maxBytes: Int)
    case unsupportedFormat(actual: StickerFormat, allowed: [StickerFormat])
    case animationNotSupported
    case animationTooLong(actualMilliseconds: Int, maxMilliseconds: Int)
    case frameDurationTooShort(actualMilliseconds: Int, minimumMilliseconds: Int)
    case tooFewEmojiTags(count: Int, minimum: Int)
    case tooManyEmojiTags(count: Int, maximum: Int)
    case missingTrayIcon(expected: PixelSize)
    case trayIconWrongSize(actual: PixelSize, expected: PixelSize)
    case trayIconTooLarge(actualBytes: Int, maxBytes: Int)
    case trayIconUnsupportedFormat(actual: StickerFormat, expected: StickerFormat)
    case packNameMissing
    case packNameTooLong(count: Int, maximum: Int)

    public var severity: ValidationIssue.Severity {
        switch self {
        case .packNameTooLong:
            return .warning
        default:
            return .error
        }
    }

    public var autoFix: AutoFix? {
        switch self {
        case let .wrongCanvasSize(_, expected):
            return .resize(to: expected)
        case let .fileTooLarge(_, maxBytes):
            return .recompress(maxBytes: maxBytes)
        case let .unsupportedFormat(_, allowed):
            guard let format = allowed.first else { return nil }
            return .convert(to: format)
        case .animationNotSupported:
            return .flattenAnimation
        case let .animationTooLong(_, maxMilliseconds):
            return .trimAnimation(toMilliseconds: maxMilliseconds)
        case let .frameDurationTooShort(_, minimumMilliseconds):
            return .slowFrames(toMilliseconds: minimumMilliseconds)
        case let .tooFewEmojiTags(count, minimum):
            return .addDefaultEmojiTags(count: minimum - count)
        case let .tooManyEmojiTags(_, maximum):
            return .dropExtraEmojiTags(keeping: maximum)
        case let .missingTrayIcon(expected), let .trayIconWrongSize(_, expected):
            return .generateTrayIcon(size: expected)
        case let .trayIconTooLarge(_, maxBytes):
            return .recompressTrayIcon(maxBytes: maxBytes)
        case let .trayIconUnsupportedFormat(_, expected):
            return .convertTrayIcon(to: expected)
        case let .tooFewStickers(count, minimum):
            return .duplicateStickers(count: minimum - count)
        case let .packNameTooLong(_, maximum):
            return .truncatePackName(maxLength: maximum)
        case .tooManyStickers, .packNameMissing:
            // Which stickers to drop, and what to call a pack, are decisions
            // only the user can make.
            return nil
        }
    }

    /// Stable string used to build issue identifiers.
    public var identifier: String {
        switch self {
        case .tooFewStickers: return "too-few-stickers"
        case .tooManyStickers: return "too-many-stickers"
        case .wrongCanvasSize: return "wrong-canvas-size"
        case .fileTooLarge: return "file-too-large"
        case .unsupportedFormat: return "unsupported-format"
        case .animationNotSupported: return "animation-not-supported"
        case .animationTooLong: return "animation-too-long"
        case .frameDurationTooShort: return "frame-duration-too-short"
        case .tooFewEmojiTags: return "too-few-emoji"
        case .tooManyEmojiTags: return "too-many-emoji"
        case .missingTrayIcon: return "missing-tray-icon"
        case .trayIconWrongSize: return "tray-icon-wrong-size"
        case .trayIconTooLarge: return "tray-icon-too-large"
        case .trayIconUnsupportedFormat: return "tray-icon-unsupported-format"
        case .packNameMissing: return "pack-name-missing"
        case .packNameTooLong: return "pack-name-too-long"
        }
    }

    public var englishDescription: String {
        switch self {
        case let .tooFewStickers(count, minimum):
            return "The pack has \(count) stickers; at least \(minimum) are required."
        case let .tooManyStickers(count, maximum):
            return "The pack has \(count) stickers; at most \(maximum) are allowed."
        case let .wrongCanvasSize(actual, expected):
            return "Size is \(actual); \(expected) is required."
        case let .fileTooLarge(actualBytes, maxBytes):
            return "File is \(ByteFormatting.kilobytes(actualBytes)); the limit is \(ByteFormatting.kilobytes(maxBytes))."
        case let .unsupportedFormat(actual, allowed):
            let names = allowed.map(\.displayName).joined(separator: ", ")
            return "\(actual.displayName) is not supported; use \(names)."
        case .animationNotSupported:
            return "This target does not accept animated stickers."
        case let .animationTooLong(actualMilliseconds, maxMilliseconds):
            return "Animation is \(actualMilliseconds) ms; the limit is \(maxMilliseconds) ms."
        case let .frameDurationTooShort(actualMilliseconds, minimumMilliseconds):
            return "Frames last \(actualMilliseconds) ms; the minimum is \(minimumMilliseconds) ms."
        case let .tooFewEmojiTags(count, minimum):
            return "\(count) emoji assigned; at least \(minimum) required."
        case let .tooManyEmojiTags(count, maximum):
            return "\(count) emoji assigned; at most \(maximum) allowed."
        case let .missingTrayIcon(expected):
            return "A \(expected) tray icon is required."
        case let .trayIconWrongSize(actual, expected):
            return "Tray icon is \(actual); \(expected) is required."
        case let .trayIconTooLarge(actualBytes, maxBytes):
            return "Tray icon is \(ByteFormatting.kilobytes(actualBytes)); the limit is \(ByteFormatting.kilobytes(maxBytes))."
        case let .trayIconUnsupportedFormat(actual, expected):
            return "Tray icon is \(actual.displayName); \(expected.displayName) is required."
        case .packNameMissing:
            return "The pack needs a name."
        case let .packNameTooLong(count, maximum):
            return "The name is \(count) characters; \(maximum) are shown."
        }
    }
}

/// Byte formatting that does not depend on `Foundation`'s locale-aware
/// formatters, so test expectations are stable everywhere.
enum ByteFormatting {
    static func kilobytes(_ bytes: Int) -> String {
        let value = (Double(bytes) / 1024 * 10).rounded() / 10
        return "\(value) KB"
    }
}
