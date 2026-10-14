import StoreKit
import StoreKitTest
import XCTest
@testable import Stiki

/// StoreKitTest session against `Configuration.storekit`.
///
/// These tests compile everywhere the app tests run. They execute only on a
/// Mac/simulator with StoreKitTest; on Linux they are not part of `swift test`.
final class PurchaseServiceTests: XCTestCase {
    var session: SKTestSession?

    override func setUp() async throws {
        try await super.setUp()
        let session = try SKTestSession(configurationFileNamed: "Configuration")
        session.disableDialogs = true
        session.clearTransactions()
        self.session = session
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
        try await super.tearDown()
    }

    func testProductsLoad() async throws {
        let service = PurchaseService()
        await service.refresh()
        let ids = await service.sortedProducts.map(\.id)
        XCTAssertTrue(ids.contains(StikiProductID.lifetime.rawValue))
        XCTAssertTrue(ids.contains(StikiProductID.yearly.rawValue))
        XCTAssertFalse(ids.contains(where: { $0.contains("week") }))
    }

    func testLifetimePurchaseGrantsPro() async throws {
        let service = PurchaseService()
        await service.refresh()
        let products = await service.sortedProducts
        guard let lifetime = products.first(where: { $0.id == StikiProductID.lifetime.rawValue }) else {
            return XCTFail("lifetime product missing from Configuration.storekit")
        }
        let entitlement = try await service.purchase(lifetime)
        XCTAssertTrue(entitlement.isPro)
        XCTAssertEqual(entitlement, .lifetime)
    }
}
