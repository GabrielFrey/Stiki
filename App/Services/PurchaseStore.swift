import Foundation
import StoreKit

/// Main-actor mirror of ``PurchaseService`` so views can bind to entitlement
/// without hopping off the actor on every body evaluation.
@MainActor
@Observable
final class PurchaseStore {
    private(set) var entitlement: ProEntitlement = .none
    private(set) var products: [Product] = []
    private(set) var lastError: StikiError?
    private(set) var isBusy = false

    var isPro: Bool { entitlement.isPro }

    let service: PurchaseService

    init(service: PurchaseService = PurchaseService()) {
        self.service = service
    }

    func start() {
        Task {
            await service.start()
            products = await service.sortedProducts
            for await value in await service.entitlementUpdates() {
                entitlement = value
                products = await service.sortedProducts
                lastError = await service.lastError
            }
        }
    }

    func refresh() async {
        await service.refresh()
        products = await service.sortedProducts
        lastError = await service.lastError
        entitlement = await service.entitlement
    }

    func purchase(_ product: Product) async throws {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await service.purchase(product)
            await refresh()
        } catch {
            await refresh()
            throw error
        }
    }

    func restore() async throws {
        isBusy = true
        defer { isBusy = false }
        _ = try await service.restore()
        await refresh()
    }
}
