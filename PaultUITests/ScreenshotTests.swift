//
//  ScreenshotTests.swift
//  PaultUITests
//
//  XCUITest screenshot capture suite for App Store submission.
//  Captures 6 screenshots covering the locked lineup:
//    01. AI Assist (Improve tab mid-stream)
//    02. Block editor canvas
//    03. API Runner with response history
//    04. Library split view
//    05. Menu bar popover
//    06. Analytics dashboard
//
//  USAGE:
//    xcodebuild test \
//      -project Pault.xcodeproj \
//      -scheme Pault \
//      -destination 'platform=macOS' \
//      -only-testing:PaultUITests/ScreenshotTests
//
//  PREREQUISITES:
//    - Run on a 2x Retina display (produces 2560x1600 from 1280x800 logical points)
//    - Disable display sleep: `caffeinate -d &`
//    - macOS Light Mode only
//    - No personal data in the app (seed data is injected via --screenshot-mode)
//
//  NOTE: Navigation queries use .accessibilityIdentifier values defined in production SwiftUI views.
//  If a query fails, verify the identifier exists in the corresponding view file.
//  Identifiers: sidebar-toggle (ContentView), ai-assist-panel (AIAssistPanel),
//  block-canvas (CompositionCanvasView), analytics-view (AnalyticsView),
//  menu-bar-content (MenuBarContentView).

import XCTest

final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!
    /// False when the test environment lacks the prerequisites for screenshot capture.
    /// Tests check this flag and return early (passing) if not authorized.
    private var screenshotEnvironmentAvailable = false

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        // ScreenshotTests require an interactive environment with:
        //   - Accessibility permissions granted to the test runner
        //   - A connected Retina display (for 2x resolution output)
        //   - macOS Light Mode
        // Skip automatically when accessibility access is unavailable (CI / automated runs).
        guard AXIsProcessTrusted() else {
            // In automated CLI runs, skip gracefully rather than failing with
            // "Not authorized for performing UI testing actions".
            // Grant access in System Preferences → Privacy & Security → Accessibility → xctest
            screenshotEnvironmentAvailable = false
            throw XCTSkip("ScreenshotTests require Accessibility permission. Grant access in System Preferences → Privacy & Security → Accessibility for the xctest process, then re-run.")
        }

        screenshotEnvironmentAvailable = true
        app = XCUIApplication()
        // Inject screenshot seed data and AI streaming mid-state
        app.launchArguments = ["--screenshot-mode", "--screenshot-mode-ai-streaming"]
        app.launch()

        // Allow app to finish launching and seed data to populate
        _ = app.windows.firstMatch.waitForExistence(timeout: 15)
    }

    override func tearDown() {
        app?.terminate()
        super.tearDown()
    }

    // MARK: - Screenshot Helper

    /// Captures a full-window PNG and attaches it to the test result with .keepAlways lifetime.
    /// Screenshots are extracted from Xcode's test result bundle (.xcresult) or via xcresulttool.
    private func captureScreenshot(name: String) {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10),
                      "Main window must be visible before capturing '\(name)'")

        let screenshot = window.screenshot()
        let attachment = XCTAttachment(
            uniformTypeIdentifier: "public.png",
            name: name,
            payload: screenshot.pngRepresentation,
            userInfo: nil
        )
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Captures the entire screen (used for menu bar popover which floats outside the window).
    private func captureScreenScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(
            uniformTypeIdentifier: "public.png",
            name: name,
            payload: screenshot.pngRepresentation,
            userInfo: nil
        )
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Window Sizing Note
    //
    // XCUITest does not provide a direct window resize API. To achieve 2560x1600 output:
    //   1. Run tests on a 2x Retina display (all modern MacBook Pro/Air and Retina iMac).
    //   2. The app's default window size (AppConstants.Windows.mainDefault) should be ≥ 1280x800
    //      logical points. Verify with:
    //        sips -g pixelWidth -g pixelHeight <screenshot.png>   → should report 2560x1600.
    //   3. If the default window size is smaller, resize manually before running tests,
    //      or use the AppleScript approach below as a setUp step:
    //
    //      let script = """
    //        tell application "Pault"
    //          set bounds of front window to {0, 0, 1280, 800}
    //        end tell
    //        """
    //      var error: NSDictionary?
    //      NSAppleScript(source: script)?.executeAndReturnError(&error)

    // MARK: - Shot 01: AI Assist

    /// Captures the AI Assist panel in Improve tab with mid-stream output visible.
    ///
    /// Navigation path:
    ///   1. Select "Code Review Assistant" in the prompt list (sidebar or main list)
    ///   2. Open AI Assist panel — Cmd+Shift+I or toolbar AI Assist button
    ///   3. Navigate to the "Improve" tab
    ///   4. The --screenshot-mode-ai-streaming flag seeds a mid-stream state via UserDefaults
    ///      "screenshot_ai_streaming_active" — AIAssistViewModel reads this to show partial output
    ///
    @MainActor
    func testShot01_AIAssist() throws {
        // Navigate to Code Review Assistant
        let promptCell = app.cells.staticTexts["Code Review Assistant"]
        if promptCell.waitForExistence(timeout: 10) {
            promptCell.click()
        } else {
            // Fallback: try outline/table cells
            let outlineCell = app.outlines.cells.staticTexts["Code Review Assistant"]
            if outlineCell.waitForExistence(timeout: 5) {
                outlineCell.click()
            }
        }

        // Open AI Assist panel via Cmd+Shift+I
        app.typeKey("i", modifierFlags: [.command, .shift])

        // Wait for AI Assist panel to appear
        let aiAssistPanel = app.groups["ai-assist-panel"]
        _ = aiAssistPanel.waitForExistence(timeout: 5)

        // Navigate to Improve tab if not already active
        let improveTab = app.buttons["Improve"]
        if improveTab.waitForExistence(timeout: 3) {
            improveTab.click()
        }

        // Allow streaming state to render (seeded by UserDefaults flag)
        Thread.sleep(forTimeInterval: 1.5)

        captureScreenshot(name: "01-ai-assist")
    }

    // MARK: - Shot 02: Block Editor

    /// Captures the block editor canvas for "API Documentation Generator" (editingModeRaw: "blocks").
    ///
    /// Navigation path:
    ///   1. Select "API Documentation Generator" in the prompt list
    ///   2. Block editor canvas should load automatically (editingMode == .blocks)
    ///   3. Wait for canvas and blocks to render
    @MainActor
    func testShot02_BlockEditor() throws {
        let promptCell = app.cells.staticTexts["API Documentation Generator"]
        if promptCell.waitForExistence(timeout: 10) {
            promptCell.click()
        } else {
            let outlineCell = app.outlines.cells.staticTexts["API Documentation Generator"]
            if outlineCell.waitForExistence(timeout: 5) {
                outlineCell.click()
            }
        }

        // Wait for block editor canvas to render (5 blocks from seed data)
        let blockCanvas = app.scrollViews["block-canvas"]
        XCTAssertTrue(blockCanvas.waitForExistence(timeout: 5), "Block canvas must be visible")

        captureScreenshot(name: "02-block-editor")
    }

    // MARK: - Shot 03: API Runner

    /// Captures the API Runner tab for "SQL Query Optimizer" showing run history.
    ///
    /// Navigation path:
    ///   1. Select "SQL Query Optimizer" in the prompt list
    ///   2. Open the Run tab — Cmd+Return or click "Run" tab button
    ///   3. Wait for run history (2 seeded PromptRun entries) to load
    @MainActor
    func testShot03_APIRunner() throws {
        let promptCell = app.cells.staticTexts["SQL Query Optimizer"]
        if promptCell.waitForExistence(timeout: 10) {
            promptCell.click()
        } else {
            let outlineCell = app.outlines.cells.staticTexts["SQL Query Optimizer"]
            if outlineCell.waitForExistence(timeout: 5) {
                outlineCell.click()
            }
        }

        // Open Run tab via Cmd+Return shortcut
        app.typeKey("\r", modifierFlags: .command)

        // Wait for run history panel to appear
        // Adjust identifier to match actual RunTabView accessibility label
        let runTab = app.buttons["Run"]
        if runTab.waitForExistence(timeout: 3) {
            runTab.click()
        }

        // Allow run history to populate from seeded PromptRun entries
        Thread.sleep(forTimeInterval: 1.5)

        captureScreenshot(name: "03-api-runner")
    }

    // MARK: - Shot 04: Library Split View

    /// Captures the full 3-panel library layout: sidebar + prompt list + detail pane.
    ///
    /// Navigation path:
    ///   1. Ensure sidebar is visible
    ///   2. Select a prompt to show the full split view composition
    ///   3. The seeded library (10 prompts, 8 tags) provides a rich list
    @MainActor
    func testShot04_LibrarySplitView() throws {
        // Ensure sidebar is visible — toggle via toolbar button if needed
        let sidebarToggle = app.buttons["sidebar-toggle"]
        if sidebarToggle.waitForExistence(timeout: 2) {
            // Sidebar should already be visible in screenshot mode, but ensure toggle is available
        }

        // Select "Email Draft: Client Follow-up" to show a populated detail pane
        let promptCell = app.cells.staticTexts["Email Draft: Client Follow-up"]
        if promptCell.waitForExistence(timeout: 10) {
            promptCell.click()
        } else {
            // Fallback: select first available prompt
            let firstCell = app.cells.firstMatch
            if firstCell.waitForExistence(timeout: 5) {
                firstCell.click()
            }
        }

        // Allow full split view to render
        Thread.sleep(forTimeInterval: 1.0)

        captureScreenshot(name: "04-library-split-view")
    }

    // MARK: - Shot 05: Menu Bar Popover

    /// Captures the menu bar popover floating above the desktop.
    /// Uses XCUIScreen.main.screenshot() to capture the popover which renders outside the window.
    ///
    /// Navigation path:
    ///   1. Click the Pault status bar item in the system menu bar
    ///   2. Wait for popover to appear and populate with recent prompts
    ///   3. Capture full screen (popover is outside the main window bounds)
    ///
    @MainActor
    func testShot05_MenuBarPopover() throws {
        // Click the Pault menu bar icon to open the popover
        // The menu bar item is in the system status bar, accessible via app.menuBars
        let menuBarItem = app.menuBars.buttons["Pault"]
        if menuBarItem.waitForExistence(timeout: 5) {
            menuBarItem.click()
        }

        // Wait for popover content to render
        Thread.sleep(forTimeInterval: 2.0)

        // Use full screen capture — popover floats above the desktop outside the main window
        captureScreenScreenshot(name: "05-menu-bar-popover")
    }

    // MARK: - Shot 06: Analytics Dashboard

    /// Captures the Analytics view with usage charts populated from seeded CopyEvent data.
    ///
    /// Navigation path:
    ///   1. Click Analytics in the sidebar navigation
    ///   2. Wait for charts to render with the 18 seeded copy events
    @MainActor
    func testShot06_AnalyticsDashboard() throws {
        // Navigate to Analytics via toolbar button or sidebar
        let analyticsButton = app.buttons["Analytics"]
        if analyticsButton.waitForExistence(timeout: 5) {
            analyticsButton.click()
        } else {
            // Fallback: try sidebar outline cell
            let analyticsCell = app.outlines.cells.staticTexts["Analytics"]
            if analyticsCell.waitForExistence(timeout: 3) {
                analyticsCell.click()
            }
        }

        // Verify analytics view loaded
        let analyticsView = app.groups["analytics-view"]
        XCTAssertTrue(analyticsView.waitForExistence(timeout: 5), "Analytics view must be visible")

        // Allow charts to render with copy event data
        Thread.sleep(forTimeInterval: 2.5)

        captureScreenshot(name: "06-analytics-dashboard")
    }
}
