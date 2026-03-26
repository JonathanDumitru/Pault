//
//  DragDropTests.swift
//  PaultTests
//
//  Model-level tests for drag-drop operations:
//  insertOnCanvas, moveBlock, duplicateBlock, removeFromCanvas.
//
//  Uses XCTestCase async + MainActor.run (same pattern as UndoRedoTests)
//  to avoid Swift Concurrency + ObjC crash on macOS 26.
//

import XCTest
import SwiftData
@testable import Pault

final class DragDropTests: XCTestCase {

    // MARK: - Helpers

    @MainActor
    private func makeModel() throws -> (PromptStudioModel, UndoManager) {
        let context = try TestHelpers.makeTestModelContext()
        let prompt = Prompt(title: "DragDrop Test", content: "")
        context.insert(prompt)
        let model = PromptStudioModel(prompt: prompt)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        model.undoManager = undoManager
        return (model, undoManager)
    }

    private func makeBlock(title: String, snippet: String = "TEXT: {{value}}") -> Block {
        Block(title: title, category: .intent, valueType: .string, snippet: snippet)
    }

    // MARK: - insertOnCanvas

    /// insertOnCanvas at index 0 places the block at the start
    func test_insertOnCanvas_atZero_placesBlockAtStart() async throws {
        try await MainActor.run {
            let (model, _) = try makeModel()

            model.addToCanvas(makeBlock(title: "Existing"))
            XCTAssertEqual(model.canvasBlocks.count, 1)

            let newBlock = makeBlock(title: "Inserted")
            model.insertOnCanvas(newBlock, at: 0)

            XCTAssertEqual(model.canvasBlocks.count, 2)
            XCTAssertEqual(model.canvasBlocks[0].title, "Inserted")
            XCTAssertEqual(model.canvasBlocks[1].title, "Existing")
        }
    }

    /// insertOnCanvas at a middle index places the block correctly
    func test_insertOnCanvas_atMiddle_placesBlockCorrectly() async throws {
        try await MainActor.run {
            let (model, _) = try makeModel()

            model.addToCanvas(makeBlock(title: "A"))
            model.addToCanvas(makeBlock(title: "B"))
            model.addToCanvas(makeBlock(title: "C"))
            XCTAssertEqual(model.canvasBlocks.count, 3)

            let newBlock = makeBlock(title: "X")
            model.insertOnCanvas(newBlock, at: 1)

            XCTAssertEqual(model.canvasBlocks.count, 4)
            XCTAssertEqual(model.canvasBlocks[0].title, "A")
            XCTAssertEqual(model.canvasBlocks[1].title, "X")
            XCTAssertEqual(model.canvasBlocks[2].title, "B")
            XCTAssertEqual(model.canvasBlocks[3].title, "C")
        }
    }

    /// insertOnCanvas at the end appends the block
    func test_insertOnCanvas_atEnd_appendsBlock() async throws {
        try await MainActor.run {
            let (model, _) = try makeModel()

            model.addToCanvas(makeBlock(title: "A"))
            model.addToCanvas(makeBlock(title: "B"))

            let newBlock = makeBlock(title: "Z")
            model.insertOnCanvas(newBlock, at: model.canvasBlocks.count)

            XCTAssertEqual(model.canvasBlocks.count, 3)
            XCTAssertEqual(model.canvasBlocks.last?.title, "Z")
        }
    }

    // MARK: - moveBlock

    /// moveBlock(direction: -1) on the first block is a no-op
    func test_moveBlock_directionUp_onFirstBlock_isNoOp() async throws {
        try await MainActor.run {
            let (model, _) = try makeModel()

            model.addToCanvas(makeBlock(title: "A"))
            model.addToCanvas(makeBlock(title: "B"))

            let firstID = model.canvasBlocks[0].id
            model.moveBlock(id: firstID, direction: -1)

            XCTAssertEqual(model.canvasBlocks[0].id, firstID, "First block should not move up")
        }
    }

    /// moveBlock(direction: 1) on the last block is a no-op
    func test_moveBlock_directionDown_onLastBlock_isNoOp() async throws {
        try await MainActor.run {
            let (model, _) = try makeModel()

            model.addToCanvas(makeBlock(title: "A"))
            model.addToCanvas(makeBlock(title: "B"))

            let lastID = model.canvasBlocks[1].id
            model.moveBlock(id: lastID, direction: 1)

            XCTAssertEqual(model.canvasBlocks[1].id, lastID, "Last block should not move down")
        }
    }

    /// moveBlock moves a block up by one position
    func test_moveBlock_directionUp_movesBlockUp() async throws {
        try await MainActor.run {
            let (model, _) = try makeModel()

            model.addToCanvas(makeBlock(title: "A"))
            model.addToCanvas(makeBlock(title: "B"))
            model.addToCanvas(makeBlock(title: "C"))

            let blockBID = model.canvasBlocks[1].id
            model.moveBlock(id: blockBID, direction: -1)

            XCTAssertEqual(model.canvasBlocks[0].id, blockBID)
            XCTAssertEqual(model.canvasBlocks[0].title, "B")
            XCTAssertEqual(model.canvasBlocks[1].title, "A")
        }
    }

    // MARK: - duplicateBlock

    /// duplicateBlock places the duplicate immediately after the original
    func test_duplicateBlock_placedImmediatelyAfterOriginal() async throws {
        try await MainActor.run {
            let (model, _) = try makeModel()

            model.addToCanvas(makeBlock(title: "Alpha"))
            model.addToCanvas(makeBlock(title: "Beta"))
            model.addToCanvas(makeBlock(title: "Gamma"))

            let originalID = model.canvasBlocks[1].id  // Beta
            model.duplicateBlock(id: originalID)

            XCTAssertEqual(model.canvasBlocks.count, 4)
            XCTAssertEqual(model.canvasBlocks[1].title, "Beta")   // original
            XCTAssertEqual(model.canvasBlocks[2].title, "Beta")   // duplicate
            XCTAssertNotEqual(model.canvasBlocks[2].id, originalID)
            XCTAssertEqual(model.canvasBlocks[3].title, "Gamma")   // unchanged
        }
    }

    // MARK: - removeFromCanvas

    /// removeFromCanvas when single block leaves empty canvas
    func test_removeFromCanvas_singleBlock_leavesEmptyCanvas() async throws {
        try await MainActor.run {
            let (model, _) = try makeModel()

            model.addToCanvas(makeBlock(title: "Only Block"))
            XCTAssertEqual(model.canvasBlocks.count, 1)

            model.removeFromCanvas(at: IndexSet(integer: 0))

            XCTAssertTrue(model.canvasBlocks.isEmpty)
        }
    }

    /// insertOnCanvas registers undo — undo removes the inserted block
    func test_insertOnCanvas_undo_removesInsertedBlock() async throws {
        try await MainActor.run {
            let (model, undoManager) = try makeModel()

            model.addToCanvas(makeBlock(title: "A"))
            let newBlock = makeBlock(title: "Inserted")
            model.insertOnCanvas(newBlock, at: 0)

            XCTAssertEqual(model.canvasBlocks.count, 2)

            undoManager.undo()
            XCTAssertEqual(model.canvasBlocks.count, 1)
            XCTAssertEqual(model.canvasBlocks[0].title, "A")
        }
    }
}
