import Foundation

/// A repair the app can carry out on the user's behalf.
public enum AutoFix: Hashable, Sendable {
    case resize(to: PixelSize)
    case recompress(maxBytes: Int)
    case convert(to: StickerFormat)
    case flattenAnimation
    case trimAnimation(toMilliseconds: Int)
    case slowFrames(toMilliseconds: Int)
    case addDefaultEmojiTags(count: Int)
    case dropExtraEmojiTags(keeping: Int)
    case duplicateStickers(count: Int)
    case generateTrayIcon(size: PixelSize)
    case recompressTrayIcon(maxBytes: Int)
    case convertTrayIcon(to: StickerFormat)
    case truncatePackName(maxLength: Int)

    /// English sentence for logs and tests.
    public var englishDescription: String {
        switch self {
        case let .resize(size):
            return "Resize to \(size)"
        case let .recompress(maxBytes):
            return "Recompress under \(ByteFormatting.kilobytes(maxBytes))"
        case let .convert(format):
            return "Convert to \(format.displayName)"
        case .flattenAnimation:
            return "Export the first frame as a still sticker"
        case let .trimAnimation(milliseconds):
            return "Trim to \(milliseconds) ms"
        case let .slowFrames(milliseconds):
            return "Slow frames to \(milliseconds) ms"
        case let .addDefaultEmojiTags(count):
            return "Add \(count) emoji"
        case let .dropExtraEmojiTags(keeping):
            return "Keep the first \(keeping) emoji"
        case let .duplicateStickers(count):
            return "Duplicate \(count) sticker(s) to reach the minimum"
        case let .generateTrayIcon(size):
            return "Generate a \(size) tray icon"
        case let .recompressTrayIcon(maxBytes):
            return "Recompress the tray icon under \(ByteFormatting.kilobytes(maxBytes))"
        case let .convertTrayIcon(format):
            return "Convert the tray icon to \(format.displayName)"
        case let .truncatePackName(maxLength):
            return "Shorten the name to \(maxLength) characters"
        }
    }
}

/// Traffic-light state of one pack against one target.
public enum Readiness: Int, Hashable, Sendable, Comparable, CaseIterable {
    /// Everything checks out; hand-off will work.
    case ready = 0
    /// Only machine-fixable problems remain — show "Fix automatically".
    case fixable = 1
    /// Needs a human decision before export.
    case blocked = 2

    public static func < (lhs: Readiness, rhs: Readiness) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The result of validating a pack for a target.
public struct ValidationReport: Hashable, Sendable {
    public var target: ExportTarget
    public var issues: [ValidationIssue]

    public init(target: ExportTarget, issues: [ValidationIssue]) {
        self.target = target
        self.issues = issues
    }

    public var readiness: Readiness {
        guard !issues.isEmpty else { return .ready }
        return issues.contains { $0.autoFix == nil } ? .blocked : .fixable
    }

    public var isReady: Bool { readiness == .ready }

    public var errors: [ValidationIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [ValidationIssue] { issues.filter { $0.severity == .warning } }

    /// Issues the app can repair when the user taps "Fix automatically".
    public var automaticallyFixableIssues: [ValidationIssue] {
        issues.filter { $0.autoFix != nil }
    }

    /// Issues the user must resolve by hand.
    public var manualIssues: [ValidationIssue] {
        issues.filter { $0.autoFix == nil }
    }
}
