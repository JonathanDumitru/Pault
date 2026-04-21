//
//  ReduceMotionUITests.swift
//  PaultUITests
//
//  Verifies that the app launches and functions correctly with Reduce Motion enabled.
//  Reduce Motion is simulated via the -UIAccessibilityIsReduceMotionEnabled launch argument.
//

import XCTest

final class ReduceMotionUITests: XCTestCase {

    @MainActor
    func testAppLaunchesWithReduceMotionEnabled() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIAccessibilityIsReduceMotionEnabled", "1"]
        app.launch()
        _ = app.windows.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
}
