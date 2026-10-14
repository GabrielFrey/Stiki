import Foundation

/// Typed failures raised by `StikiCore`.
///
/// Every case carries the numbers needed to build a human sentence; the app
/// layer turns them into localized copy so this package stays resource-free.
public enum StikiCoreError: Error, Hashable, Sendable {
    /// A recipe was written by a newer app version than this build understands.
    case unsupportedRecipeVersion(found: Int, supported: Int)
    case recipeDecodingFailed(underlying: String)
    /// A source asset was smaller than the minimum the pipeline can work with.
    case sourceTooSmall(PixelSize, minimum: Int)
    /// Adaptive compression could not reach the target size.
    case cannotReachSizeLimit(achievedBytes: Int, limitBytes: Int)
    /// The requested export format has no encoder on this device.
    case formatUnavailable(StickerFormat)

    /// English text used by tests and logs. User-facing strings live in the
    /// app's string catalog.
    public var englishDescription: String {
        switch self {
        case let .unsupportedRecipeVersion(found, supported):
            return "Recipe version \(found) is newer than the supported version \(supported)."
        case let .recipeDecodingFailed(underlying):
            return "The sticker recipe could not be read: \(underlying)"
        case let .sourceTooSmall(size, minimum):
            return "Source image is \(size); at least \(minimum) px on the shortest side is required."
        case let .cannotReachSizeLimit(achieved, limit):
            return "Compressed to \(achieved) bytes, which still exceeds the \(limit) byte limit."
        case let .formatUnavailable(format):
            return "\(format.displayName) encoding is not available on this device."
        }
    }
}
