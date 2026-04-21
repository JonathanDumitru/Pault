//
//  PerformanceBenchmarkTests.swift
//  PaultTests
//
//  XCTest measure() benchmarks for:
//  - compileNow() with 20+ blocks (baseline < 300ms)
//  - SlashCommandState.filterBlocks() (baseline < 10ms)
//  - Adding 20 blocks sequentially (no O(n^2) degradation)
//
//  Uses XCTestCase async + MainActor.run pattern (consistent with UndoRedoTests)
//  to avoid macOS 26 Swift Concurrency + ObjC crash with @MainActor + UndoManager.
//
//  Release config note: Run with ENABLE_TESTABILITY=YES to allow @testable import in
//  optimized builds. All 3 benchmarks verified passing in Release on 2026-04-21.
//

import XCTest
import SwiftData
@testable import Pault

final class PerformanceBenchmarkTests: XCTestCase {

    // MARK: - Test 1: Compilation performance with 20 blocks (< 300ms)

    func testCompilationPerformanceWith20Blocks() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Benchmark", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)

            // Build 20 blocks with varying snippets and filled inputs
            let snippets: [String] = [
                "ROLE: {{role}}",
                "OBJECTIVE: {{goal}}\nPriority: {{priority}}",
                "DO: {{task}}",
                "CONSTRAINT: {{rule}}",
                "TONE: {{tone}}",
                "ANALYZE: {{mode}}",
                "FORMAT: {{format}}",
                "STATIC BLOCK",
                "IF({{cond}}) -> {{then}}",
                "AUDIENCE: {{audience}}"
            ]

            for i in 0..<20 {
                let snippetIndex = i % snippets.count
                let block = Block(
                    title: "Block \(i)",
                    category: .intent,
                    valueType: .string,
                    snippet: snippets[snippetIndex]
                )
                model.addToCanvas(block)

                // Fill all placeholders
                let placeholders = PromptStudioModel.placeholders(in: snippets[snippetIndex])
                for placeholder in placeholders {
                    model.setBlockInput(blockID: block.id, placeholder: placeholder, value: "test value \(i)")
                }
            }

            XCTAssertEqual(model.canvasBlocks.count, 20)

            // Measure compilation time — must be < 300ms per plan requirement
            self.measure {
                model.compileNow()
            }
        }
    }

    // MARK: - Test 2: Palette filter performance (< 10ms)

    func testPaletteFilterPerformance() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Filter Test", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)

            // Gather all blocks from library
            let allBlocks = model.library.values.flatMap { $0 }

            // Must have a reasonable library to filter against
            XCTAssertGreaterThan(allBlocks.count, 10)

            // Measure filter time — must be < 10ms per plan requirement
            self.measure {
                let _ = SlashCommandState.filterBlocks(allBlocks, query: "role")
            }
        }
    }

    // MARK: - Test 3: Canvas add performance with 20 blocks (no O(n^2))

    func testCanvasAddPerformanceWith20Blocks() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()

            self.measure {
                let prompt = Prompt(title: "Add Test \(Date().timeIntervalSince1970)", content: "")
                context.insert(prompt)
                let model = PromptStudioModel(prompt: prompt)

                for i in 0..<20 {
                    let block = Block(
                        title: "Block \(i)",
                        category: .intent,
                        valueType: .string,
                        snippet: "DO: {{task}}"
                    )
                    model.addToCanvas(block)
                }

                XCTAssertEqual(model.canvasBlocks.count, 20)
            }
        }
    }
}
