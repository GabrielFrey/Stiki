import Foundation
import StikiCore
import os

/// File storage for originals, masks, rendered stickers and staged exports.
///
/// Everything lives in the App Group container so the iMessage extension can
/// read rendered stickers without talking to the app. The store is an actor:
/// file IO is serialised off the main thread, and callers hand over plain
/// `Data`, which keeps `Sendable` correctness trivial.
actor AssetStore {
    private let containerURL: URL
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "com.stiki.app", category: "AssetStore")

    init(containerURL: URL, fileManager: FileManager = .default) {
        self.containerURL = containerURL
        self.fileManager = fileManager
    }

    /// The App Group container, or a local fallback.
    ///
    /// A missing container means the App Group entitlement is not in the
    /// provisioning profile. That must not crash the app: Stiki keeps working
    /// against its own sandbox and only the iMessage extension goes empty,
    /// which Settings reports.
    static func resolveContainerURL(
        fileManager: FileManager = .default,
        groupIdentifier: String = SharedPaths.appGroupIdentifier
    ) -> (url: URL, isAppGroup: Bool) {
        if let url = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) {
            return (url, true)
        }
        let fallback = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return (fallback.appending(path: "Stiki", directoryHint: .isDirectory), false)
    }

    // MARK: - Directories

    private var assetsURL: URL {
        containerURL.appending(path: SharedPaths.assetsDirectory, directoryHint: .isDirectory)
    }

    private var renderedURL: URL {
        containerURL.appending(path: SharedPaths.renderedDirectory, directoryHint: .isDirectory)
    }

    private var exportsURL: URL {
        containerURL.appending(path: SharedPaths.exportsDirectory, directoryHint: .isDirectory)
    }

    var catalogURL: URL {
        containerURL.appending(path: SharedPaths.catalogFileName, directoryHint: .notDirectory)
    }

    func prepareDirectories() throws {
        for url in [assetsURL, renderedURL, exportsURL] {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - Assets

    /// Stores an immutable original or mask and returns its reference.
    func writeAsset(_ data: Data, kind: AssetRef.Kind, pixelSize: PixelSize, fileExtension: String) throws -> AssetRef {
        try prepareDirectories()
        let name = "\(UUID().uuidString.prefix(8))-\(kind.rawValue).\(fileExtension)"
        let url = assetsURL.appending(path: name, directoryHint: .notDirectory)
        try data.write(to: url, options: .atomic)
        return AssetRef(fileName: name, kind: kind, pixelSize: pixelSize)
    }

    /// Overwrites an existing asset, used when the user refines a mask.
    func replaceAsset(_ data: Data, ref: AssetRef) throws {
        try prepareDirectories()
        let url = assetsURL.appending(path: ref.fileName, directoryHint: .notDirectory)
        try data.write(to: url, options: .atomic)
    }

    func assetData(_ ref: AssetRef) throws -> Data {
        let url = assetsURL.appending(path: ref.fileName, directoryHint: .notDirectory)
        guard let data = fileManager.contents(atPath: url.path(percentEncoded: false)) else {
            throw StikiError.assetMissing(ref.fileName)
        }
        return data
    }

    func assetExists(_ ref: AssetRef) -> Bool {
        fileManager.fileExists(
            atPath: assetsURL.appending(path: ref.fileName, directoryHint: .notDirectory)
                .path(percentEncoded: false)
        )
    }

    func deleteAsset(_ ref: AssetRef) {
        let url = assetsURL.appending(path: ref.fileName, directoryHint: .notDirectory)
        try? fileManager.removeItem(at: url)
    }

    /// Deletes assets no longer referenced by any recipe.
    ///
    /// Originals are the largest files Stiki keeps, and non-destructive editing
    /// means they outlive the edit session, so they need explicit collection.
    func pruneAssets(keeping referencedFileNames: Set<String>) {
        guard let names = try? fileManager.contentsOfDirectory(atPath: assetsURL.path(percentEncoded: false)) else {
            return
        }
        for name in names where !referencedFileNames.contains(name) {
            try? fileManager.removeItem(at: assetsURL.appending(path: name, directoryHint: .notDirectory))
            logger.debug("Pruned unreferenced asset")
        }
    }

    // MARK: - Rendered stickers

    func writeRendered(_ data: Data, fileName: String) throws -> URL {
        try prepareDirectories()
        let url = renderedURL.appending(path: fileName, directoryHint: .notDirectory)
        try data.write(to: url, options: .atomic)
        return url
    }

    func renderedData(fileName: String) throws -> Data {
        let url = renderedURL.appending(path: fileName, directoryHint: .notDirectory)
        guard let data = fileManager.contents(atPath: url.path(percentEncoded: false)) else {
            throw StikiError.assetMissing(fileName)
        }
        return data
    }

    func deleteRendered(fileName: String) {
        try? fileManager.removeItem(at: renderedURL.appending(path: fileName, directoryHint: .notDirectory))
    }

    func renderedFileURL(fileName: String) -> URL {
        renderedURL.appending(path: fileName, directoryHint: .notDirectory)
    }

    // MARK: - Catalog

    func writeCatalog(_ catalog: SharedStickerCatalog) throws {
        try prepareDirectories()
        try catalog.encoded().write(to: catalogURL, options: .atomic)
    }

    func readCatalog() -> SharedStickerCatalog {
        guard let data = fileManager.contents(atPath: catalogURL.path(percentEncoded: false)),
              let catalog = try? SharedStickerCatalog.decoded(from: data) else {
            return .empty
        }
        return catalog
    }

    // MARK: - Exports

    /// Writes a file into a fresh per-export directory and returns its URL,
    /// ready for `ShareLink` or a messenger hand-off.
    func stageExport(_ data: Data, fileName: String, inFolder folder: String) throws -> URL {
        let directory = exportsURL.appending(path: folder, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: fileName, directoryHint: .notDirectory)
        try data.write(to: url, options: .atomic)
        return url
    }

    func exportFolderURL(_ folder: String) throws -> URL {
        let directory = exportsURL.appending(path: folder, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Removes a staged export directory once it has been handed off.
    func clearExportFolder(_ folder: String) {
        try? fileManager.removeItem(at: exportsURL.appending(path: folder, directoryHint: .isDirectory))
    }

    func clearAllExports() {
        try? fileManager.removeItem(at: exportsURL)
        try? fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
    }

    /// Bytes used by originals, masks and rendered output, shown in Settings.
    func storageFootprint() -> Int {
        [assetsURL, renderedURL, exportsURL].reduce(0) { total, directory in
            total + directorySize(directory)
        }
    }

    private func directorySize(_ directory: URL) -> Int {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var total = 0
        for case let url as URL in enumerator {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return total
    }
}
