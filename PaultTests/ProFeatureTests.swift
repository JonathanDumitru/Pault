// PaultTests/ProFeatureTests.swift
import XCTest
@testable import Pault

final class ProFeatureTests: XCTestCase {

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
        // Without any purchase, all features should be locked
        for feature in ProFeature.allCases {
            XCTAssertFalse(ProFeature.isUnlocked(feature), "\(feature) should be locked by default")
        }
    }
}
