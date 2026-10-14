import Foundation
import StikiCore
import SwiftUI

/// User preferences that survive launches.
///
/// Stored in UserDefaults (privacy reason CA92.1: app-only settings). Nothing
/// here is a photo, a recipe or a sticker — those live in the App Group.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let defaultExportTarget = "defaultExportTarget"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let preferredAuthorName = "preferredAuthorName"
    }

    var defaultExportTarget: ExportTarget {
        didSet { defaults.set(defaultExportTarget.rawValue, forKey: Key.defaultExportTarget) }
    }

    /// CloudKit sync. The container is rebuilt when this flips, which is why
    /// it is also read at launch before the environment is constructed.
    var iCloudSyncEnabled: Bool {
        didSet { defaults.set(iCloudSyncEnabled, forKey: Key.iCloudSyncEnabled) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    var authorName: String {
        didSet { defaults.set(authorName, forKey: Key.preferredAuthorName) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedTarget = defaults.string(forKey: Key.defaultExportTarget) ?? ""
        self.defaultExportTarget = ExportTarget(rawValue: storedTarget) ?? .whatsApp
        self.iCloudSyncEnabled = defaults.bool(forKey: Key.iCloudSyncEnabled)
        self.hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        self.authorName = defaults.string(forKey: Key.preferredAuthorName) ?? "Stiki"
    }

    static var isCloudSyncEnabledAtLaunch: Bool {
        UserDefaults.standard.bool(forKey: Key.iCloudSyncEnabled)
    }
}
