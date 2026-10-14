import Foundation
import StikiCore

/// Every failure the app surfaces to the user, with localized copy.
///
/// The app never shows a raw `NSError`: each case maps to a sentence that says
/// what happened, and where possible a second one that says what to do next.
enum StikiError: LocalizedError, Equatable {
    case imageDecodingFailed
    case imageEncodingFailed(StickerFormat)
    case formatNotSupportedByDevice(StickerFormat)
    case noSubjectFound
    case subjectLiftingFailed(String)
    case assetMissing(String)
    case renderFailed(String)
    case videoHasNoVideoTrack
    case frameExtractionFailed
    case exportFailed(String)
    case sizeLimitUnreachable(achievedBytes: Int, limitBytes: Int)
    case messengerNotInstalled(ExportTarget)
    case photoLibraryAccessDenied
    case cameraAccessDenied
    case purchaseFailed(String)
    case purchaseUnverified
    case proRequired
    case packLimitReached(limit: Int)
    case cancelled
    case core(StikiCoreError)

    var errorDescription: String? {
        switch self {
        case .imageDecodingFailed:
            return String(localized: "That image could not be read.")
        case let .imageEncodingFailed(format):
            return String(
                format: String(localized: "Stiki could not write the sticker as %@."),
                format.displayName
            )
        case let .formatNotSupportedByDevice(format):
            return String(
                format: String(localized: "This device cannot write %@ files."),
                format.displayName
            )
        case .noSubjectFound:
            return String(localized: "No subject found in this photo.")
        case .subjectLiftingFailed:
            return String(localized: "The cutout could not be created.")
        case .assetMissing:
            return String(localized: "The original image for this sticker is missing.")
        case .renderFailed:
            return String(localized: "The sticker could not be rendered.")
        case .videoHasNoVideoTrack:
            return String(localized: "That file has no video to animate.")
        case .frameExtractionFailed:
            return String(localized: "Frames could not be read from that video.")
        case .exportFailed:
            return String(localized: "The export did not finish.")
        case let .sizeLimitUnreachable(achieved, limit):
            return String(
                format: String(localized: "This sticker is %1$@ after compression; the limit is %2$@."),
                ByteFormat.string(achieved),
                ByteFormat.string(limit)
            )
        case let .messengerNotInstalled(target):
            return String(
                format: String(localized: "%@ is not installed on this device."),
                target.englishName
            )
        case .photoLibraryAccessDenied:
            return String(localized: "Stiki needs access to your photos to import them.")
        case .cameraAccessDenied:
            return String(localized: "Stiki needs camera access to take a photo.")
        case .purchaseFailed:
            return String(localized: "The purchase could not be completed.")
        case .purchaseUnverified:
            return String(localized: "The App Store could not verify that purchase.")
        case .proRequired:
            return String(localized: "This is a Stiki Pro feature.")
        case let .packLimitReached(limit):
            return String(format: String(localized: "The free plan includes %lld packs."), limit)
        case .cancelled:
            return String(localized: "Cancelled.")
        case let .core(error):
            return error.localizedMessage
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noSubjectFound:
            return String(localized: "Try a photo with a clearer subject, or keep the whole image instead.")
        case .formatNotSupportedByDevice:
            return String(localized: "Stiki will export a PNG or GIF instead.")
        case .photoLibraryAccessDenied, .cameraAccessDenied:
            return String(localized: "Open Settings to grant access.")
        case .messengerNotInstalled:
            return String(localized: "Install the app, or use Save and share instead.")
        case .proRequired, .packLimitReached:
            return String(localized: "Stiki Pro is a one-time purchase or a yearly plan.")
        case .sizeLimitUnreachable:
            return String(localized: "Try a simpler outline, fewer frames, or a shorter animation.")
        case .assetMissing:
            return String(localized: "Re-import the photo to rebuild this sticker.")
        default:
            return nil
        }
    }

    /// `true` for outcomes the user chose, which must not raise an alert.
    var isSilent: Bool { self == .cancelled }
}

extension StikiCoreError {
    /// Localized copy for domain errors raised inside StikiCore, which is
    /// deliberately resource-free so it can be tested off-device.
    var localizedMessage: String {
        switch self {
        case .unsupportedRecipeVersion:
            return String(localized: "This sticker was made with a newer version of Stiki.")
        case .recipeDecodingFailed:
            return String(localized: "This sticker's settings could not be read.")
        case let .sourceTooSmall(_, minimum):
            return String(
                format: String(localized: "That image is too small; Stiki needs at least %lld px."),
                minimum
            )
        case let .cannotReachSizeLimit(achieved, limit):
            return String(
                format: String(localized: "This sticker is %1$@ after compression; the limit is %2$@."),
                ByteFormat.string(achieved),
                ByteFormat.string(limit)
            )
        case let .formatUnavailable(format):
            return String(
                format: String(localized: "This device cannot write %@ files."),
                format.displayName
            )
        }
    }
}

/// Byte counts formatted for user-facing copy.
enum ByteFormat {
    static func string(_ bytes: Int) -> String {
        bytes.formatted(.byteCount(style: .file, allowedUnits: [.kb, .mb]))
    }
}
