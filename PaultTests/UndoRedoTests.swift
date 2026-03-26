//
//  UndoRedoTests.swift
//  PaultTests
//
//  Comprehensive undo/redo unit tests for PromptStudioModel structural operations.
//  Covers all 6 structural operations: add, remove, reorder, duplicate,
//  modifier add, modifier remove.
//
//  Uses a real UndoManager injected into PromptStudioModel.
//  Text input changes are NOT tested here — those use standard macOS TextField undo.
//
//  Uses async XCTestCase test methods with MainActor.run to ensure proper isolation.
//

import XCTest
import Foundation
import SwiftData
@testable import Pault

final class UndoRedoTests: XCTestCase {

    // MARK: - Helpers

    private func makeBlock(title: String = "Role", snippet: String = "ROLE: {{role}}") -> Block {
        Block(title: title, category: .rolePerspective, valueType: .string, snippet: snippet)
    }

    private func makeModifier(name: String = "Format JSON", snippet: String = "FORMAT: json") -> BlockModifier {
        BlockModifier(name: name, category: .format, snippet: snippet)
    }

    // MARK: - Test 1: addToCanvas — undo removes the added block

    func test_addToCanvas_undo_removesBlock() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            model.addToCanvas(makeBlock())
            XCTAssertEqual(model.canvasBlocks.count, 1)

            undoManager.undo()
            XCTAssertTrue(model.canvasBlocks.isEmpty)
        }
    }

    // MARK: - Test 2: removeFromCanvas — undo restores block at exact original index

    func test_removeFromCanvas_undo_restoresBlockAtOriginalIndex() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            model.addToCanvas(makeBlock(title: "Block A"))
            model.addToCanvas(makeBlock(title: "Block B", snippet: "DO: {{task}}"))
            model.addToCanvas(makeBlock(title: "Block C", snippet: "CONTEXT: {{summary}}"))

            XCTAssertEqual(model.canvasBlocks.count, 3)
            let blockBID = model.canvasBlocks[1].id

            model.removeFromCanvas(at: IndexSet([1]))
            XCTAssertEqual(model.canvasBlocks.count, 2)
            XCTAssertFalse(model.canvasBlocks.contains(where: { $0.id == blockBID }))

            undoManager.undo()

            XCTAssertEqual(model.canvasBlocks.count, 3)
            XCTAssertEqual(model.canvasBlocks[1].id, blockBID)
            XCTAssertEqual(model.canvasBlocks[1].title, "Block B")
        }
    }

    // MARK: - Test 3: removeFromCanvas — undo restores block inputs

    func test_removeFromCanvas_undo_restoresBlockInputs() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            let block = makeBlock(snippet: "ROLE: {{role}}")
            model.addToCanvas(block)
            let blockID = model.canvasBlocks[0].id

            model.setBlockInput(blockID: blockID, placeholder: "role", value: "developer")
            XCTAssertEqual(model.blockInputs[blockID]?["role"], "developer")

            model.removeFromCanvas(at: IndexSet([0]))
            XCTAssertTrue(model.canvasBlocks.isEmpty)

            undoManager.undo()

            let restoredID = model.canvasBlocks[0].id
            XCTAssertEqual(model.blockInputs[restoredID]?["role"], "developer")
        }
    }

    // MARK: - Test 4: moveOnCanvas — undo moves block back to original position

    func test_moveOnCanvas_undo_restoresOriginalOrder() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            model.addToCanvas(makeBlock(title: "Block A"))
            model.addToCanvas(makeBlock(title: "Block B", snippet: "DO: {{task}}"))
            model.addToCanvas(makeBlock(title: "Block C", snippet: "CONTEXT: {{summary}}"))

            XCTAssertEqual(model.canvasBlocks.map { $0.title }, ["Block A", "Block B", "Block C"])

            model.moveOnCanvas(from: IndexSet([0]), to: 3)
            XCTAssertEqual(model.canvasBlocks.map { $0.title }, ["Block B", "Block C", "Block A"])

            undoManager.undo()
            XCTAssertEqual(model.canvasBlocks.map { $0.title }, ["Block A", "Block B", "Block C"])
        }
    }

    // MARK: - Test 5: duplicateBlock — undo removes the duplicate

    func test_duplicateBlock_undo_removesDuplicate() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            let block = makeBlock()
            model.addToCanvas(block)
            XCTAssertEqual(model.canvasBlocks.count, 1)

            let originalID = model.canvasBlocks[0].id
            model.duplicateBlock(id: originalID)
            XCTAssertEqual(model.canvasBlocks.count, 2)

            undoManager.undo()
            XCTAssertEqual(model.canvasBlocks.count, 1)
            XCTAssertEqual(model.canvasBlocks[0].id, originalID)
        }
    }

    // MARK: - Test 6: addModifier — undo removes the modifier

    func test_addModifier_undo_removesModifier() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            let block = makeBlock()
            model.addToCanvas(block)
            let blockID = model.canvasBlocks[0].id

            let modifier = makeModifier()
            model.addModifierToBlock(blockID: blockID, modifier: modifier)
            XCTAssertEqual(model.modifiersForBlock(blockID).count, 1)

            undoManager.undo()
            XCTAssertTrue(model.modifiersForBlock(blockID).isEmpty)
        }
    }

    // MARK: - Test 7: removeModifier — undo restores the modifier

    func test_removeModifier_undo_restoresModifier() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            let block = makeBlock()
            model.addToCanvas(block)
            let blockID = model.canvasBlocks[0].id

            let modifier = makeModifier(name: "Format JSON", snippet: "FORMAT: json")
            model.addModifierToBlock(blockID: blockID, modifier: modifier)
            let modifierID = model.modifiersForBlock(blockID)[0].id

            model.removeModifierFromBlock(blockID: blockID, modifierID: modifierID)
            XCTAssertTrue(model.modifiersForBlock(blockID).isEmpty)

            undoManager.undo()
            let restoredModifiers = model.modifiersForBlock(blockID)
            XCTAssertEqual(restoredModifiers.count, 1)
            XCTAssertEqual(restoredModifiers[0].snippet, "FORMAT: json")
        }
    }

    // MARK: - Test 8: redo after undo re-applies the operation

    func test_redo_afterUndo_reappliesOperation() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            let block = makeBlock()
            model.addToCanvas(block)
            XCTAssertEqual(model.canvasBlocks.count, 1)

            undoManager.undo()
            XCTAssertTrue(model.canvasBlocks.isEmpty)
            XCTAssertTrue(undoManager.canRedo)

            undoManager.redo()
            XCTAssertEqual(model.canvasBlocks.count, 1)
        }
    }

    // MARK: - Test 9: new action after undo clears redo stack

    func test_newAction_afterUndo_clearsRedoStack() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            model.addToCanvas(makeBlock(title: "Block A"))
            model.addToCanvas(makeBlock(title: "Block B", snippet: "DO: {{task}}"))

            undoManager.undo()
            XCTAssertTrue(undoManager.canRedo)

            model.addToCanvas(makeBlock(title: "Block C", snippet: "CONTEXT: {{summary}}"))
            XCTAssertFalse(undoManager.canRedo)
        }
    }

    // MARK: - Test 10: sequential undo/redo chain (add 3 blocks, undo 3, redo 2)

    func test_sequentialUndoRedo_chain() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            model.addToCanvas(makeBlock(title: "Block A"))
            model.addToCanvas(makeBlock(title: "Block B", snippet: "DO: {{task}}"))
            model.addToCanvas(makeBlock(title: "Block C", snippet: "CONTEXT: {{summary}}"))
            XCTAssertEqual(model.canvasBlocks.count, 3)

            undoManager.undo() // removes Block C
            XCTAssertEqual(model.canvasBlocks.count, 2)

            undoManager.undo() // removes Block B
            XCTAssertEqual(model.canvasBlocks.count, 1)

            undoManager.undo() // removes Block A
            XCTAssertTrue(model.canvasBlocks.isEmpty)
            XCTAssertFalse(undoManager.canUndo)

            undoManager.redo() // re-adds Block A
            XCTAssertEqual(model.canvasBlocks.count, 1)
            XCTAssertEqual(model.canvasBlocks[0].title, "Block A")

            undoManager.redo() // re-adds Block B
            XCTAssertEqual(model.canvasBlocks.count, 2)
            XCTAssertEqual(model.canvasBlocks[1].title, "Block B")

            XCTAssertTrue(undoManager.canRedo) // Block C can still be redone
        }
    }

    // MARK: - Test 11: undo sets isDirty to true

    func test_undo_setsDirtyFlag() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            let block = makeBlock()
            model.addToCanvas(block)

            model.saveToPrompt()
            XCTAssertFalse(model.isDirty)

            undoManager.undo()
            XCTAssertTrue(model.isDirty)
        }
    }

    // MARK: - Test 12: clearUndoHistory clears the undo stack

    func test_clearUndoHistory_clearsStack() async throws {
        try await MainActor.run {
            let context = try TestHelpers.makeTestModelContext()
            let prompt = Prompt(title: "Test Prompt", content: "")
            context.insert(prompt)
            let model = PromptStudioModel(prompt: prompt)
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            model.undoManager = undoManager

            model.addToCanvas(makeBlock())
            XCTAssertTrue(undoManager.canUndo)

            model.clearUndoHistory()
            XCTAssertFalse(undoManager.canUndo)
        }
    }
}
