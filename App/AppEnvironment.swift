import Foundation
import StikiCore
import SwiftData
import SwiftUI

/// The composition root.
///
/// Views talk to view models; view models talk to services through this
/// container. Protocols (`SubjectLifting`, `WebPEncoding`) are what make
/// previews and tests injectable without spinning up Vision or StoreKit.
@MainActor
@Observable
final class AppEnvironment {
    let modelContainer: ModelContainer
    let assetStore: AssetStore
    let library: StickerLibrary
    let renderer: RenderService
    let animation: AnimationService
    let subjectLifting: any SubjectLifting
    let exporter: ExportService
    let purchases: PurchaseStore
    let settings: AppSettings
    let isAppGroupAvailable: Bool

    var isPro: Bool { purchases.isPro }

    init(
        modelContainer: ModelContainer,
        assetStore: AssetStore,
        isAppGroupAvailable: Bool,
        subjectLifting: any SubjectLifting = VisionSubjectLiftingService(),
        webPEncoder: any WebPEncoding = ImageIOWebPEncoder(),
        purchases: PurchaseStore = PurchaseStore(),
        settings: AppSettings = AppSettings()
    ) {
        self.modelContainer = modelContainer
        self.assetStore = assetStore
        self.isAppGroupAvailable = isAppGroupAvailable
        self.subjectLifting = subjectLifting
        self.purchases = purchases
        self.settings = settings
        self.renderer = RenderService()
        self.animation = AnimationService()
        self.library = StickerLibrary(modelContainer: modelContainer, assetStore: assetStore)
        self.exporter = ExportService(
            renderer: renderer,
            assetStore: assetStore,
            webPEncoder: webPEncoder
        )
        library.reload()
        purchases.start()
    }

    /// Production environment: App Group store, Vision, ImageIO WebP, StoreKit.
    static func live() -> AppEnvironment {
        let (url, isAppGroup) = AssetStore.resolveContainerURL()
        let store = AssetStore(containerURL: url)
        let container = ModelContainerFactory.make(
            cloudSyncEnabled: AppSettings.isCloudSyncEnabledAtLaunch
        )
        return AppEnvironment(
            modelContainer: container,
            assetStore: store,
            isAppGroupAvailable: isAppGroup
        )
    }

    /// In-memory environment for previews and UI tests.
    static func preview(isPro: Bool = false) -> AppEnvironment {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "stiki-preview-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let environment = AppEnvironment(
            modelContainer: ModelContainerFactory.makeInMemory(),
            assetStore: AssetStore(containerURL: url),
            isAppGroupAvailable: true,
            subjectLifting: PreviewSubjectLifting(),
            purchases: PurchaseStore()
        )
        return environment
    }

    /// Loads the original and mask for a sticker from the asset store.
    func loadSource(for sticker: StickerSnapshot) async throws -> (Data, Data?) {
        guard let recipe = sticker.recipe else { throw StikiError.assetMissing("recipe") }
        let source = try await assetStore.assetData(recipe.source)
        let mask: Data?
        if let maskRef = recipe.mask {
            mask = try await assetStore.assetData(maskRef)
        } else {
            mask = nil
        }
        return (source, mask)
    }
}

/// No-op subject lifting used by SwiftUI previews. Never used in the app.
struct PreviewSubjectLifting: SubjectLifting {
    func analyze(imageData: Data, maxPixelSide: Int) async throws -> SubjectAnalysis {
        SubjectAnalysis(
            token: UUID(),
            instances: [],
            imagePixelSize: PixelSize(width: 512, height: 512),
            usedPersonSegmentationFallback: false
        )
    }

    func mask(
        imageData: Data,
        token: UUID?,
        instances: Set<Int>,
        maxPixelSide: Int
    ) async throws -> Data {
        throw StikiError.noSubjectFound
    }
}

private enum AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = .preview()
}

extension EnvironmentValues {
    var stiki: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
