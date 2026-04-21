//
//  CanvasSnapshotTests.swift
//  PaultTests
//
//  Snapshot tests for BlockRowView and canvas states in light/dark mode.
//  Reference images are generated on first run (record mode).
//  These tests are marked optional for CI per testing strategy decision.
//
//  Uses NSHostingView with swift-snapshot-testing's built-in .image strategy
//  for deterministic NSView snapshots on macOS.
//

import XCTest
import SwiftUI
import AppKit
import SnapshotTesting
import SwiftData
@testable import Pault

@MainActor
final class CanvasSnapshotTests: XCTestCase {

    // MARK: - Configuration

    // Set to true to record new reference images. Set back to false after recording.
    // Reference images are stored in __Snapshots__/CanvasSnapshotTests/
    // Note: First run must be done in Xcode (not headless CLI) to enable NSView rendering.
    // Set RECORD_SNAPSHOTS env var or change this to true when running in Xcode.
    private var isRecording: Bool {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] != nil
    }

    /// Returns true when running under the Xcode IDE (not headless xcodebuild CLI).
    /// Snapshot tests require Xcode IDE access to write reference images to the source tree
    /// and to get proper NSView rendering with a display server.
    ///
    /// Detection: Xcode IDE injects XPC_SERVICE_NAME starting with "com.apple.dt.Xcode."
    /// xcodebuild CLI does NOT set this; it uses a simproc launcher instead.
    private var isRunningInXcode: Bool {
        guard let xpc = ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] else {
            return false
        }
        return xpc.hasPrefix("com.apple.dt.Xcode.")
    }

    private let snapshotSize = CGSize(width: 500, height: 600)

    // MARK: - Helpers

    /// Returns false when not running inside the Xcode IDE.
    /// Call at the top of each snapshot test to avoid CLI failures.
    /// Usage: guard shouldRunSnapshot() else { return }
    private func shouldRunSnapshot() -> Bool {
        return isRunningInXcode || isRecording
    }

    private func makeContext() throws -> ModelContext {
        try TestHelpers.makeTestModelContext()
    }

    /// Build a stable NSHostingView for snapshotting at the given size and color scheme.
    private func makeHostingView<V: View>(_ view: V, scheme: ColorScheme = .light) -> NSView {
        let styled = view
            .frame(width: snapshotSize.width, height: snapshotSize.height)
            .environment(\.colorScheme, scheme)

        let hosting = NSHostingView(rootView: styled)
        hosting.frame = CGRect(origin: .zero, size: snapshotSize)
        return hosting
    }

    private func makeBlock(title: String, category: BlockCategory = .intent, snippet: String = "DO: {{task}}") -> Block {
        Block(title: title, category: category, valueType: .string, snippet: snippet)
    }

    // MARK: - Test 1: Empty canvas state (light mode)

    func testEmptyCanvas() throws {
        guard shouldRunSnapshot() else { return }
        let context = try makeContext()
        let prompt = Prompt(title: "Snapshot Test", content: "")
        context.insert(prompt)
        let model = PromptStudioModel(prompt: prompt)
        let slashState = SlashCommandState()

        let view = CompositionCanvasView(model: model, slashState: slashState)
        let hostingView = makeHostingView(view)
        assertSnapshot(of: hostingView, as: .image(size: snapshotSize), record: isRecording)
    }

    // MARK: - Test 2: Single block canvas

    func testSingleBlockCanvas() throws {
        guard shouldRunSnapshot() else { return }
        let context = try makeContext()
        let prompt = Prompt(title: "Snapshot Test", content: "")
        context.insert(prompt)
        let model = PromptStudioModel(prompt: prompt)
        let slashState = SlashCommandState()

        let block = makeBlock(title: "Role", category: .rolePerspective, snippet: "ROLE: {{role}}")
        model.addToCanvas(block)
        model.setBlockInput(blockID: block.id, placeholder: "role", value: "Software Engineer")

        let view = CompositionCanvasView(model: model, slashState: slashState)
        let hostingView = makeHostingView(view)
        assertSnapshot(of: hostingView, as: .image(size: snapshotSize), record: isRecording)
    }

    // MARK: - Test 3: Multi-block canvas (3 blocks)

    func testMultiBlockCanvas() throws {
        guard shouldRunSnapshot() else { return }
        let context = try makeContext()
        let prompt = Prompt(title: "Snapshot Test", content: "")
        context.insert(prompt)
        let model = PromptStudioModel(prompt: prompt)
        let slashState = SlashCommandState()

        let block1 = makeBlock(title: "Role", category: .rolePerspective, snippet: "ROLE: {{role}}")
        let block2 = makeBlock(title: "Objective", category: .intent, snippet: "OBJECTIVE: {{goal}}")
        let block3 = makeBlock(title: "Static Block", category: .constraints, snippet: "STATIC: no placeholders")
        model.addToCanvas(block1)
        model.addToCanvas(block2)
        model.addToCanvas(block3)

        let view = CompositionCanvasView(model: model, slashState: slashState)
        let hostingView = makeHostingView(view)
        assertSnapshot(of: hostingView, as: .image(size: snapshotSize), record: isRecording)
    }

    // MARK: - Test 4: Empty canvas dark mode

    func testEmptyCanvasDarkMode() throws {
        guard shouldRunSnapshot() else { return }
        let context = try makeContext()
        let prompt = Prompt(title: "Snapshot Test", content: "")
        context.insert(prompt)
        let model = PromptStudioModel(prompt: prompt)
        let slashState = SlashCommandState()

        let view = CompositionCanvasView(model: model, slashState: slashState)
        let hostingView = makeHostingView(view, scheme: .dark)
        assertSnapshot(of: hostingView, as: .image(size: snapshotSize), record: isRecording)
    }

    // MARK: - Test 5: Multi-block canvas dark mode

    func testMultiBlockCanvasDarkMode() throws {
        guard shouldRunSnapshot() else { return }
        let context = try makeContext()
        let prompt = Prompt(title: "Snapshot Test", content: "")
        context.insert(prompt)
        let model = PromptStudioModel(prompt: prompt)
        let slashState = SlashCommandState()

        let block1 = makeBlock(title: "Role", category: .rolePerspective, snippet: "ROLE: {{role}}")
        let block2 = makeBlock(title: "Task", category: .instructions, snippet: "DO: {{task}}")
        model.addToCanvas(block1)
        model.addToCanvas(block2)

        let view = CompositionCanvasView(model: model, slashState: slashState)
        let hostingView = makeHostingView(view, scheme: .dark)
        assertSnapshot(of: hostingView, as: .image(size: snapshotSize), record: isRecording)
    }

    // MARK: - Test 6: Expanded block state

    func testExpandedBlockState() throws {
        guard shouldRunSnapshot() else { return }
        let context = try makeContext()
        let prompt = Prompt(title: "Snapshot Test", content: "")
        context.insert(prompt)
        let model = PromptStudioModel(prompt: prompt)
        let slashState = SlashCommandState()

        // Single block with inputs (expanded by default)
        let block = makeBlock(
            title: "Objective",
            category: .intent,
            snippet: "OBJECTIVE: {{goal}}\nPriority: {{priority}}"
        )
        model.addToCanvas(block)
        model.setBlockInput(blockID: block.id, placeholder: "goal", value: "Ship the app")
        model.setBlockInput(blockID: block.id, placeholder: "priority", value: "High")

        let view = CompositionCanvasView(model: model, slashState: slashState)
        let hostingView = makeHostingView(view)
        assertSnapshot(of: hostingView, as: .image(size: snapshotSize), record: isRecording)
    }

    // MARK: - Test 7: Block with validation error (unfilled placeholders → red status indicator)

    func testBlockWithValidationError() throws {
        guard shouldRunSnapshot() else { return }
        let context = try makeContext()
        let prompt = Prompt(title: "Snapshot Test", content: "")
        context.insert(prompt)
        let model = PromptStudioModel(prompt: prompt)
        let slashState = SlashCommandState()

        // Block with unfilled placeholders → shows red/xmark.circle status indicator
        let block = makeBlock(
            title: "Role",
            category: .rolePerspective,
            snippet: "ROLE: {{role}}\nDOMAIN: {{domain}}"
        )
        model.addToCanvas(block)
        // Don't fill inputs — status will be .unfilled (red indicator with xmark icon)

        let view = CompositionCanvasView(model: model, slashState: slashState)
        let hostingView = makeHostingView(view)
        assertSnapshot(of: hostingView, as: .image(size: snapshotSize), record: isRecording)
    }
}
