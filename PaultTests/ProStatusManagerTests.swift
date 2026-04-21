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
            // Allow StoreKit to propagate the cleared state before each test.
            // Without this delay, residual entitlements from prior tests can bleed through.
            // macOS 26 beta needs ~2s for clearTransactions to propagate reliably
            // when the full test suite runs (cross-process StoreKit state contention).
            try await Task.sleep(nanoseconds: 2_000_000_000)
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

    /// Polls refreshStatus up to maxAttempts times until isProUnlocked matches expected value.
    /// Required on macOS 26 beta where StoreKit entitlement propagation has variable latency.
    private func waitForProStatus(_ manager: ProStatusManager, expected: Bool, attempts: Int = 5) async throws {
        for attempt in 1...attempts {
            await manager.refreshStatus()
            if manager.isProUnlocked == expected { return }
            if attempt < attempts {
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms between attempts
            }
        }
    }

    func test_purchase_grantsProAccess() async throws {
        guard let s = session else {
            throw XCTSkip("SKTestSession unavailable")
        }
        try await s.buyProduct(identifier: "com.pault.pro.annual")
        let manager = ProStatusManager()
        // Poll until entitlements propagate (macOS 26 beta has variable StoreKit latency)
        try await waitForProStatus(manager, expected: true)
        XCTAssertTrue(manager.isProUnlocked, "Pro should be unlocked after purchase")
    }

    func test_expiredSubscription_revokesProAccess() async throws {
        guard let s = session else {
            throw XCTSkip("SKTestSession unavailable")
        }
        try await s.buyProduct(identifier: "com.pault.pro.annual")
        let manager = ProStatusManager()
        // Poll until purchase propagates
        try await waitForProStatus(manager, expected: true)
        XCTAssertTrue(manager.isProUnlocked, "Pro should be unlocked after purchase")

        try s.expireSubscription(productIdentifier: "com.pault.pro.annual")
        // Expiration propagation is slower than purchase on macOS 26 beta —
        // initial delay before polling avoids wasting attempts during the lag window.
        try await Task.sleep(nanoseconds: 1_000_000_000)
        // Poll until expiration propagates (more attempts than purchase)
        try await waitForProStatus(manager, expected: false, attempts: 10)
        XCTAssertFalse(manager.isProUnlocked, "Pro should be revoked after subscription expires")
    }

    func test_restore_grantsProAccess() async throws {
        guard let s = session else {
            throw XCTSkip("SKTestSession unavailable")
        }
        // Purchase, then verify restorePurchases() explicitly syncs and unlocks
        try await s.buyProduct(identifier: "com.pault.pro.annual")
        let manager = ProStatusManager()
        // Poll until purchase propagates
        try await waitForProStatus(manager, expected: true)
        XCTAssertTrue(manager.isProUnlocked, "Pro should be unlocked after purchase")

        // Explicitly call restore (AppStore.sync + refreshStatus) — simulates
        // user tapping "Restore Purchases" after reinstall
        await manager.restorePurchases()

        XCTAssertTrue(manager.isProUnlocked, "Pro should remain unlocked after restore")
    }
}
