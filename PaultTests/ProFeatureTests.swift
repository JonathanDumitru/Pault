// PaultTests/ProFeatureTests.swift
import XCTest
import StoreKitTest
@testable import Pault

final class ProFeatureTests: XCTestCase {

    /// Reset ProStatusManager.shared before the StoreKit-sensitive test.
    /// ProStatusManagerTests may leave the shared instance in a "pro unlocked" state
    /// if their SKTestSession teardown doesn't propagate before this test runs.
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        // Clear any residual StoreKit transactions from prior test classes
        if let session = try? SKTestSession(configurationFileNamed: "Pault") {
            session.clearTransactions()
            // Brief propagation delay
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        // Refresh the shared manager so it reads the now-empty entitlements
        await ProStatusManager.shared.refreshStatus()
    }

    func test_allCases_count() {
        XCTAssertEqual(ProFeature.allCases.count, 6)
    }

    func test_displayNames_notEmpty() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(feature.displayName.isEmpty, "\(feature) has empty displayName")
        }
    }

    func test_sfSymbols_notEmpty() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(feature.sfSymbol.isEmpty, "\(feature) has empty sfSymbol")
        }
    }

    func test_descriptions_notEmpty() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(feature.description.isEmpty, "\(feature) has empty description")
        }
    }

    func test_freeBlockLimit_isFive() {
        XCTAssertEqual(ProFeature.freeBlockLimit, 5)
    }

    @MainActor
    func test_isUnlocked_defaultsFalse() {
        // Without any purchase (StoreKit cleared in setUp), all features should be locked
        for feature in ProFeature.allCases {
            XCTAssertFalse(ProFeature.isUnlocked(feature), "\(feature) should be locked by default")
        }
    }
}
