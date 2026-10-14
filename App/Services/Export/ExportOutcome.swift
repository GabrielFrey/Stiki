import Foundation
import StikiCore

/// What the export UI does after the files are ready.
enum ExportHandoff: Hashable, Sendable {
    /// Files staged for a share sheet.
    case share(urls: [URL], message: String?)
    /// WhatsApp pasteboard payload plus the URL to open.
    case whatsApp(payload: Data, url: URL)
    /// Telegram zip plus the @Stickers bot URL and the instructions to show.
    case telegram(zipURL: URL, botURL: URL, instructions: String)
    /// Saved to the photo library.
    case savedToPhotos
    /// Copied to the pasteboard as an image.
    case copiedToClipboard
}

/// Result of validating then (optionally) repairing a pack for one target.
struct PreparedExport: Sendable {
    var target: ExportTarget
    var report: ValidationReport
    var files: [URL]
    var trayIcon: RenderedImage?
    var renderedStickers: [UUID: RenderedImage]
}

/// Adaptive compression notes surfaced when we had to fall back a format.
struct ExportLimitation: Hashable, Sendable {
    var title: String
    var detail: String

    /// Telegram has no on-device VP9 encoder in this build, so animated
    /// stickers go out as GIF and the user is told to convert them in
    /// @Stickers if they need WebM.
    static let telegramWebMUnavailable = ExportLimitation(
        title: String(localized: "Animated Telegram stickers ship as GIF"),
        detail: String(localized: "This device cannot write WebM. Stiki packs the animation as a GIF you can send to @Stickers, or as a still WebP.")
    )

    static let webPUnavailable = ExportLimitation(
        title: String(localized: "WebP encoding is unavailable"),
        detail: String(localized: "This device cannot write WebP. Stiki will export PNG or GIF instead.")
    )
}
