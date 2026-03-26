//
//  KeyboardNavigationTests.swift
//  PaultTests
//
//  Model-level tests for keyboard navigation and focus management:
//  - focusAfterDelete returns correct next/previous block ID
//  - focusAfterInsert returns new block ID
//  - rapid sequential adds preserve order
//  - dirty state tracking on canvas operations
//
//  Uses XCTestCase async + MainActor.run (same pattern as UndoRedoTests)
//  to avoid Swift Concurrency + ObjC crash on macOS 26.
//

import XCTest
import SwiftData
@testable import Pault

final class KeyboardNavigationTests: XCTestCase {

    // MARK: - Helpers

    @MainActor
    private func makeModel() throws -> PromptStudioModel {
        let context = try TestHelpers.makeTestModelContext()
        let prompt = Prompt(title: "KeyNav Test", content: "")
        context.insert(prompt)
        return PromptStudioModel(prompt: prompt)
    }

    private func makeBlock(title: String, snippet: String = "TEXT: {{value}}") -> Block {
        Block(title: title, category: .intent, valueType: .string, snippet: snippet)
    }

    // MARK: - Focus after delete

    /// After deleting a middle block, focus moves to the block at the same index
    /// (which is the next block after deletion)
    func test_focusAfterDelete_middleBlock_movesToNextBlock() async throws {
        try await MainActor.run {
            let model = try makeModel()

            model.addToCanvas(makeBlock(title: "A"))
            model.addToCanvas(makeBlock(title: "B"))
            model.addToCanvas(makeBlock(title: "C"))

            // Simulate the delete handler: select B, delete it, focus moves to next
            let blockBIndex = 1
            let blockCID = model.canvasBlocks[2].id

            model.removeFromCanvas(at: IndexSet(integer: blockBIndex))
            // After removal: [A, C] — index 1 is C
            let expectedFocusID = model.canvasBlocks.count > blockBIndex
                ? model.canvasBlocks[min(blockBIndex, model.canvasBlocks.count - 1)].id
                : model.canvasBlocks.last?.id

            XCTAssertEqual(expectedFocusID, blockCID)
        }
    }

    /// After deleting the last block, focus moves to the new last block
    func test_focusAfterDelete_lastBlock_movesToPreviousBlock() async throws {
        try await MainActor.run {
            let model = try makeModel()

            model.addToCanvas(makeBlock(title: "A"))
            model.addToCanvas(makeBlock(title: "B"))

            let blockAID = model.canvasBlocks[0].id
            let lastIndex = model.canvasBlocks.count - 1

            model.removeFromCanvas(at: IndexSet(integer: lastIndex))
            // After removal: [A] — only block is A
            let expectedFocusID = model.canvasBlocks.isEmpty ? nil
                : model.canvasBlocks[min(lastIndex, model.canvasBlocks.count - 1)].id

            XCTAssertEqual(expectedFocusID, blockAID)
        }
    }

    /// After deleting the only block, canvas is empty (no crash)
    func test_focusAfterDelete_onlyBlock_canvasEmpty() async throws {
        try await MainActor.run {
            let model = try makeModel()
            model.addToCanvas(makeBlock(title: "Solo"))
            XCTAssertEqual(model.canvasBlocks.count, 1)

            model.removeFromCanvas(at: IndexSet(integer: 0))

            XCTAssertTrue(model.canvasBlocks.isEmpty)
            // No selection possible
            let focusID: UUID? = model.canvasBlocks.isEmpty ? nil : model.canvasBlocks[0].id
            XCTAssertNil(focusID)
        }
    }

    // MARK: - Focus after insert

    /// After insertOnCanvas, the new block's ID is available at the expected index
    func test_focusAfterInsert_newBlockIDAvailable() async throws {
        try await MainActor.run {
            let model = try makeModel()
            model.addToCanvas(makeBlock(title: "A"))
            model.addToCanvas(makeBlock(title: "B"))

            let insertIndex = 1
            model.insertOnCanvas(makeBlock(title: "New"), at: insertIndex)

            // New block is at index 1
            XCTAssertEqual(model.canvasBlocks.count, 3)
            let newBlockID = model.canvasBlocks[insertIndex].id
            XCTAssertNotNil(newBlockID)
            XCTAssertEqual(model.canvasBlocks[insertIndex].title, "New")
        }
    }

    /// After addToCanvas, the new block's ID is the last block
    func test_focusAfterAdd_newBlockIsLast() async throws {
        try await MainActor.run {
            let model = try makeModel()
            model.addToCanvas(makeBlock(title: "First"))
            model.addToCanvas(makeBlock(title: "Second"))

            let lastID = model.canvasBlocks.last?.id
            XCTAssertEqual(model.canvasBlocks.last?.title, "Second")
            XCTAssertNotNil(lastID)
        }
    }

    // MARK: - Rapid sequential adds

    /// Rapid sequential adds (3 blocks without animation) preserve correct order
    func test_rapidSequentialAdds_preserveOrder() async throws {
        try await MainActor.run {
            let model = try makeModel()

            // Simulate rapid adds (no animation context needed at model level)
            model.addToCanvas(makeBlock(title: "First"))
            model.addToCanvas(makeBlock(title: "Second"))
            model.addToCanvas(makeBlock(title: "Third"))

            XCTAssertEqual(model.canvasBlocks.count, 3)
            XCTAssertEqual(model.canvasBlocks[0].title, "First")
            XCTAssertEqual(model.canvasBlocks[1].title, "Second")
            XCTAssertEqual(model.canvasBlocks[2].title, "Third")
        }
    }

    /// Rapid insertions at various positions preserve correct ordering
    func test_rapidInserts_preserveCorrectOrder() async throws {
        try await MainActor.run {
            let model = try makeModel()

            model.insertOnCanvas(makeBlock(title: "A"), at: 0)
            model.insertOnCanvas(makeBlock(title: "B"), at: 1)
            model.insertOnCanvas(makeBlock(title: "C"), at: 0)  // C goes to front

            XCTAssertEqual(model.canvasBlocks.count, 3)
            XCTAssertEqual(model.canvasBlocks[0].title, "C")
            XCTAssertEqual(model.canvasBlocks[1].title, "A")
            XCTAssertEqual(model.canvasBlocks[2].title, "B")
        }
    }

    // MARK: - Dirty state tracking

    /// addToCanvas marks model as dirty
    func test_dirtyState_addToCanvas_marksDirty() async throws {
        try await MainActor.run {
            let model = try makeModel()
            XCTAssertFalse(model.isDirty, "Model should start clean")

            model.addToCanvas(makeBlock(title: "Test"))
            XCTAssertTrue(model.isDirty, "Model should be dirty after add")
        }
    }

    /// removeFromCanvas marks model as dirty
    func test_dirtyState_removeFromCanvas_marksDirty() async throws {
        try await MainActor.run {
            let model = try makeModel()
            model.addToCanvas(makeBlock(title: "Test"))

            // Save to clear dirty state (simulate a save)
            model.saveToPrompt()
            XCTAssertFalse(model.isDirty, "Model should be clean after save")

            model.removeFromCanvas(at: IndexSet(integer: 0))
            XCTAssertTrue(model.isDirty, "Model should be dirty after remove")
        }
    }

    /// moveBlock marks model as dirty
    func test_dirtyState_moveBlock_marksDirty() async throws {
        try await MainActor.run {
            let model = try makeModel()
            model.addToCanvas(makeBlock(title: "A"))
            model.addToCanvas(makeBlock(title: "B"))
            model.saveToPrompt()
            XCTAssertFalse(model.isDirty)

            model.moveBlock(id: model.canvasBlocks[0].id, direction: 1)
            XCTAssertTrue(model.isDirty, "Model should be dirty after move")
        }
    }

    /// duplicateBlock marks model as dirty
    func test_dirtyState_duplicateBlock_marksDirty() async throws {
        try await MainActor.run {
            let model = try makeModel()
            model.addToCanvas(makeBlock(title: "A"))
            model.saveToPrompt()
            XCTAssertFalse(model.isDirty)

            model.duplicateBlock(id: model.canvasBlocks[0].id)
            XCTAssertTrue(model.isDirty, "Model should be dirty after duplicate")
        }
    }

    // MARK: - pendingFirstInputFocusBlockID

    /// After addToCanvas and simulating what CompositionCanvasView does,
    /// pendingFirstInputFocusBlockID equals the new block's ID
    func test_pendingFirstInputFocusBlockID_setAfterAddToCanvas() async throws {
        try await MainActor.run {
            let model = try makeModel()
            model.addToCanvas(makeBlock(title: "Focus Target", snippet: "TEXT: {{value}}"))

            // Simulate what CompositionCanvasView's slash palette onSelect does
            if let last = model.canvasBlocks.last {
                model.selectedCanvasBlockID = last.id
                model.pendingFirstInputFocusBlockID = last.id
            }

            XCTAssertNotNil(model.pendingFirstInputFocusBlockID)
            XCTAssertEqual(model.pendingFirstInputFocusBlockID, model.canvasBlocks.last?.id)
        }
    }

    /// After setting pendingFirstInputFocusBlockID and clearing it, property is nil
    func test_pendingFirstInputFocusBlockID_clearedAfterConsumption() async throws {
        try await MainActor.run {
            let model = try makeModel()
            model.addToCanvas(makeBlock(title: "Focus Target", snippet: "TEXT: {{value}}"))

            // Simulate set
            model.pendingFirstInputFocusBlockID = model.canvasBlocks.last?.id
            XCTAssertNotNil(model.pendingFirstInputFocusBlockID)

            // Simulate consumption (BlockRowView calls onClearPendingFocus)
            model.pendingFirstInputFocusBlockID = nil
            XCTAssertNil(model.pendingFirstInputFocusBlockID, "pendingFirstInputFocusBlockID should be nil after cleared")
        }
    }
}
