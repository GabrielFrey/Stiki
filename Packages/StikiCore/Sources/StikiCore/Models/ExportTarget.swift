import Foundation

/// A destination the app can deliver a pack to.
public enum ExportTarget: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case iMessage
    case whatsApp
    case telegram
    /// Photos, Files and the share sheet — the no-rules escape hatch.
    case photosAndFiles

    public var id: String { rawValue }

    /// English name, used for logs and tests. The app localizes separately.
    public var englishName: String {
        switch self {
        case .iMessage: return "iMessage"
        case .whatsApp: return "WhatsApp"
        case .telegram: return "Telegram"
        case .photosAndFiles: return "Photos & Files"
        }
    }

    /// URL the app opens to hand the pack over, if the target has one.
    public var handoffURLString: String? {
        switch self {
        case .iMessage:
            return nil
        case .whatsApp:
            return "whatsapp://stickerPack"
        case .telegram:
            return "tg://resolve?domain=Stickers"
        case .photosAndFiles:
            return nil
        }
    }

    /// Scheme to declare in `LSApplicationQueriesSchemes` and probe with
    /// `UIApplication.canOpenURL(_:)`.
    public var applicationQueryScheme: String? {
        switch self {
        case .iMessage: return nil
        case .whatsApp: return "whatsapp"
        case .telegram: return "tg"
        case .photosAndFiles: return nil
        }
    }

    /// The three targets whose readiness is shown as a badge on every pack.
    public static var badgedTargets: [ExportTarget] { [.iMessage, .whatsApp, .telegram] }

    public var limits: ExportLimits { ExportLimits.limits(for: self) }
}
