// PaultTests/ProStatusManagerTests.swift
import XCTest
import StoreKit
@testable import Pault

@MainActor
final class ProStatusManagerTests: XCTestCase {
    func test_initialState_isNotPro() {
        let manager = ProStatusManager()
        XCTAssertFalse(manager.isProUnlocked)
    }

    func test_proProductIDs_matchConfiguration() {
        XCTAssertEqual(ProStatusManager.proProductIDs, [
            "com.pault.pro.monthly",
            "com.pault.pro.annual"
        ])
    }
}
