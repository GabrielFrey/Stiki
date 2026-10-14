import Foundation
import StikiCore
import SwiftData
import os

/// Builds the SwiftData container.
///
/// The store lives in the App Group container so the library survives app
/// updates and is reachable from extensions. CloudKit is configured but
/// defaults to `.none`: syncing a photo library to a private database is a
/// decision the user makes in Settings, and the privacy promise is that
/// nothing leaves the device until they do.
enum ModelContainerFactory {
    static let schema = Schema([
        StickerEntity.self,
        StickerPackEntity.self,
        PackMembershipEntity.self
    ])

    private static let logger = Logger(subsystem: "com.stiki.app", category: "Storage")

    /// CloudKit container used when a Pro user enables sync.
    static let cloudKitContainerIdentifier = "iCloud.com.stiki.app"

    static func make(cloudSyncEnabled: Bool) -> ModelContainer {
        let (containerURL, isAppGroup) = AssetStore.resolveContainerURL()
        if !isAppGroup {
            logger.warning("App Group container unavailable; using the app sandbox instead.")
        }
        try? FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        let storeURL = containerURL.appending(path: SharedPaths.storeFileName, directoryHint: .notDirectory)

        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: cloudSyncEnabled ? .private(cloudKitContainerIdentifier) : .none
        )

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            logger.error("Persistent store unavailable: \(error.localizedDescription, privacy: .public)")
            // A corrupt or inaccessible store must not be a launch crash: fall
            // back to memory so the user can still work and re-import.
            return makeInMemory()
        }
    }

    /// In-memory container for tests, previews and the degraded launch path.
    static func makeInMemory() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("In-memory SwiftData container could not be created: \(error)")
        }
    }
}
