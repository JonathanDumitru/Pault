// PaultTests/ProStatusManagerTests.swift
import XCTest
import StoreKit
import StoreKitTest
@testable import Pault

@MainActor
final class ProStatusManagerTests: XCTestCase {
    var session: SKTestSession?

    override func setUp() async throws {
        try await super.setUp()
        do {
            let s = try SKTestSession(configurationFileNamed: "Pault")
            s.disableDialogs = true
            s.clearTransactions()
            session = s
        } catch {
            session = nil
        }
    }

    override func tearDown() {
        session?.clearTransactions()
        session = nil
        super.tearDown()
    }

    // MARK: - Non-lifecycle tests (always pass)

    func test_initialState_isNotPro() async throws {
        let manager = ProStatusManager()
        XCTAssertFalse(manager.isProUnlocked)
    }

    func test_proProductID_isAnnualOnly() {
        XCTAssertEqual(ProStatusManager.proProductID, "com.pault.pro.annual")
    }

    // MARK: - SKTestSession lifecycle tests

    func test_purchase_grantsProAccess() async throws {
        guard let s = session else {
            throw XCTSkip("SKTestSession unavailable")
        }
        try await s.buyProduct(identifier: "com.pault.pro.annual")
        let manager = ProStatusManager()
        // Directly call refreshStatus to avoid relying on background Task timing
        await manager.refreshStatus()
        XCTAssertTrue(manager.isProUnlocked, "Pro should be unlocked after purchase")
    }

    func test_expiredSubscription_revokesProAccess() async throws {
        guard let s = session else {
            throw XCTSkip("SKTestSession unavailable")
        }
        try await s.buyProduct(identifier: "com.pault.pro.annual")
        let manager = ProStatusManager()
        await manager.refreshStatus()
        XCTAssertTrue(manager.isProUnlocked, "Pro should be unlocked after purchase")

        try s.expireSubscription(productIdentifier: "com.pault.pro.annual")
        // Allow StoreKit to propagate the expiration before refreshing
        try await Task.sleep(nanoseconds: 800_000_000)
        await manager.refreshStatus()

        XCTAssertFalse(manager.isProUnlocked, "Pro should be revoked after subscription expires")
    }

    func test_restore_grantsProAccess() async throws {
        guard let s = session else {
            throw XCTSkip("SKTestSession unavailable")
        }
        // Purchase, then verify restorePurchases() explicitly syncs and unlocks
        try await s.buyProduct(identifier: "com.pault.pro.annual")

        let manager = ProStatusManager()
        await manager.refreshStatus()
        XCTAssertTrue(manager.isProUnlocked, "Pro should be unlocked after purchase")

        // Explicitly call restore (AppStore.sync + refreshStatus) — simulates
        // user tapping "Restore Purchases" after reinstall
        await manager.restorePurchases()

        XCTAssertTrue(manager.isProUnlocked, "Pro should remain unlocked after restore")
    }
}
