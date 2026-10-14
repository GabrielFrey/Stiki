import Foundation

/// The JSON WhatsApp expects on the pasteboard for a third-party sticker pack.
///
/// WhatsApp reads a single pasteboard item of type
/// ``WhatsAppPackPayload/pasteboardType`` and then the app opens
/// `whatsapp://stickerPack`. Key names are fixed by WhatsApp's iOS sticker
/// specification, so they are spelled out in `CodingKeys` and covered by a
/// test — a silent typo here is exactly the kind of bug that produces a
/// "nothing happened" hand-off.
public struct WhatsAppPackPayload: Codable, Hashable, Sendable {
    public static let pasteboardType = "net.whatsapp.third-party.sticker-pack"
    /// WhatsApp drops pasteboard contents after this long.
    public static let pasteboardLifetime: TimeInterval = 60

    public var identifier: String
    public var name: String
    public var publisher: String
    /// Base64-encoded 96×96 PNG.
    public var trayImageData: String
    public var imageDataVersion: String
    public var avoidCache: Bool
    public var publisherWebsite: String?
    public var privacyPolicyWebsite: String?
    public var licenseAgreementWebsite: String?
    public var iosAppStoreLink: String?
    public var androidPlayStoreLink: String?
    public var stickers: [Sticker]

    public struct Sticker: Codable, Hashable, Sendable {
        /// Base64-encoded 512×512 WebP.
        public var imageData: String
        public var emojis: [String]

        public init(imageData: String, emojis: [String]) {
            self.imageData = imageData
            self.emojis = emojis
        }

        private enum CodingKeys: String, CodingKey {
            case imageData = "image_data"
            case emojis
        }
    }

    public init(
        identifier: String,
        name: String,
        publisher: String,
        trayImageData: String,
        imageDataVersion: String = "1",
        avoidCache: Bool = false,
        publisherWebsite: String? = nil,
        privacyPolicyWebsite: String? = nil,
        licenseAgreementWebsite: String? = nil,
        iosAppStoreLink: String? = nil,
        androidPlayStoreLink: String? = nil,
        stickers: [Sticker]
    ) {
        self.identifier = identifier
        self.name = name
        self.publisher = publisher
        self.trayImageData = trayImageData
        self.imageDataVersion = imageDataVersion
        self.avoidCache = avoidCache
        self.publisherWebsite = publisherWebsite
        self.privacyPolicyWebsite = privacyPolicyWebsite
        self.licenseAgreementWebsite = licenseAgreementWebsite
        self.iosAppStoreLink = iosAppStoreLink
        self.androidPlayStoreLink = androidPlayStoreLink
        self.stickers = stickers
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case name
        case publisher
        case trayImageData = "tray_image"
        case imageDataVersion = "image_data_version"
        case avoidCache = "avoid_cache"
        case publisherWebsite = "publisher_website"
        case privacyPolicyWebsite = "privacy_policy_website"
        case licenseAgreementWebsite = "license_agreement_website"
        case iosAppStoreLink = "ios_app_store_link"
        case androidPlayStoreLink = "android_play_store_link"
        case stickers
    }

    /// WhatsApp identifies a pack by this string; reusing it updates the pack
    /// in place instead of adding a duplicate, which is what users expect
    /// after they fix a sticker.
    public static func identifier(for packID: UUID) -> String {
        "com.stiki.pack.\(packID.uuidString.lowercased())"
    }

    public func serialized() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
