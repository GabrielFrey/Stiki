import Foundation
import StoreKit
import os

/// Product identifiers. Mirrored in `Configuration.storekit` for local testing.
enum StikiProductID: String, CaseIterable, Sendable {
    case lifetime = "com.stiki.pro.lifetime"
    case yearly = "com.stiki.pro.yearly"

    var isSubscription: Bool { self == .yearly }
}

/// Entitlement the rest of the app queries.
enum ProEntitlement: Hashable, Sendable {
    case none
    case yearly(expires: Date?)
    case lifetime

    var isPro: Bool {
        switch self {
        case .none: return false
        case .lifetime: return true
        case let .yearly(expires):
            guard let expires else { return true }
            return expires > Date()
        }
    }
}

/// StoreKit 2 purchases.
///
/// An actor so `Transaction.updates` and `Product.purchase` cannot race the
/// entitlement cache. The listener is started once from `AppEnvironment` and
/// cancelled when the environment goes away.
actor PurchaseService {
    private(set) var entitlement: ProEntitlement = .none {
        didSet { publish() }
    }
    private(set) var products: [Product] = []
    private(set) var lastError: StikiError?
    private var listenerTask: Task<Void, Never>?
    private var continuations: [UUID: AsyncStream<ProEntitlement>.Continuation] = [:]
    private let logger = Logger(subsystem: "com.stiki.app", category: "Purchase")

    /// Lifetime first, then yearly — the honest order the paywall shows.
    var sortedProducts: [Product] {
        products.sorted { lhs, rhs in
            if lhs.id == StikiProductID.lifetime.rawValue { return true }
            if rhs.id == StikiProductID.lifetime.rawValue { return false }
            return lhs.displayName < rhs.displayName
        }
    }

    func start() {
        guard listenerTask == nil else { return }
        listenerTask = Task { [weak self] in
            guard let self else { return }
            await self.listenForTransactions()
        }
        Task { await refresh() }
    }

    func stop() {
        listenerTask?.cancel()
        listenerTask = nil
    }

    func refresh() async {
        do {
            products = try await Product.products(for: StikiProductID.allCases.map(\.rawValue))
            entitlement = await currentEntitlement()
            lastError = nil
        } catch {
            logger.error("Product load failed: \(error.localizedDescription, privacy: .public)")
            lastError = .purchaseFailed(error.localizedDescription)
            entitlement = await currentEntitlement()
        }
    }

    func purchase(_ product: Product) async throws -> ProEntitlement {
        let result = try await product.purchase()
        switch result {
        case let .success(verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            entitlement = await currentEntitlement()
            return entitlement
        case .userCancelled:
            throw StikiError.cancelled
        case .pending:
            throw StikiError.purchaseFailed("pending")
        @unknown default:
            throw StikiError.purchaseFailed("unknown")
        }
    }

    /// Asks the App Store to restore, then re-reads entitlements.
    func restore() async throws -> ProEntitlement {
        try await AppStore.sync()
        entitlement = await currentEntitlement()
        return entitlement
    }

    var isPro: Bool { entitlement.isPro }

    /// Stream of entitlement changes, including the current value first.
    func entitlementUpdates() -> AsyncStream<ProEntitlement> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.yield(entitlement)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    // MARK: - Private

    private func publish() {
        for continuation in continuations.values {
            continuation.yield(entitlement)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            guard !Task.isCancelled else { break }
            do {
                let transaction = try checkVerified(update)
                await transaction.finish()
                entitlement = await currentEntitlement()
            } catch {
                logger.error("Unverified transaction: \(error.localizedDescription, privacy: .public)")
                lastError = .purchaseUnverified
            }
        }
    }

    private func currentEntitlement() async -> ProEntitlement {
        var lifetime = false
        var hasYearly = false
        var yearlyExpiry: Date?
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            if transaction.productID == StikiProductID.lifetime.rawValue {
                lifetime = true
            } else if transaction.productID == StikiProductID.yearly.rawValue {
                hasYearly = true
                yearlyExpiry = transaction.expirationDate
            }
        }
        if lifetime { return .lifetime }
        // A nil expiration is treated as active: StoreKit omits the date in
        // some sandbox states.
        if hasYearly { return .yearly(expires: yearlyExpiry) }
        return .none
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .unverified(_, error):
            throw error
        case let .verified(safe):
            return safe
        }
    }
}
