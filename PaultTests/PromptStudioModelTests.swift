//
//  PromptStudioModelTests.swift
//  PaultTests
//
//  Tests for PromptStudioModel: loading, compilation, saving, canvas ops.
//

import Testing
import Foundation
import SwiftData
@testable import Pault

@MainActor
struct PromptStudioModelTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Prompt.self, TemplateVariable.self, Pault.Tag.self, Attachment.self,
                CopyEvent.self, PromptRun.self, PromptVersion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makePrompt(in context: ModelContext, title: String = "Test", content: String = "") -> Prompt {
        let prompt = Prompt(title: title, content: content)
        context.insert(prompt)
        return prompt
    }

    // MARK: - Loading from Empty Prompt

    @Test func initWithEmptyPrompt_startsWithBlankCanvas() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)

        let model = PromptStudioModel(prompt: prompt)

        #expect(model.canvasBlocks.isEmpty)
        #expect(model.blockInputs.isEmpty)
        #expect(model.blockModifiers.isEmpty)
        #expect(model.compiledTemplate.isEmpty)
        #expect(model.rawTemplate.isEmpty)
        #expect(model.filledExample.isEmpty)
    }

    @Test func initWithEmptyPrompt_seedsLibrary() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)

        let model = PromptStudioModel(prompt: prompt)

        // Library should have blocks in multiple categories
        #expect(!model.library.isEmpty)
        #expect(model.library[.rolePerspective] != nil)
        #expect(model.library[.intent] != nil)
        #expect(model.library[.instructions] != nil)
    }

    @Test func initWithEmptyPrompt_seedsModifierLibrary() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)

        let model = PromptStudioModel(prompt: prompt)

        #expect(!model.modifierLibrary.isEmpty)
        #expect(model.modifierLibrary[.quality] != nil)
        #expect(model.modifierLibrary[.tone] != nil)
    }

    @Test func initWithEmptyPrompt_syncStateIsSynced() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)

        // init calls compileNow() which calls saveToPrompt()
        let _ = PromptStudioModel(prompt: prompt)

        #expect(prompt.blockSyncState == .synced)
    }

    // MARK: - Loading from Prompt with Block Data

    @Test func initWithExistingBlockData_restoresCanvas() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)

        // Pre-populate the prompt with a block composition
        let blockID = UUID()
        let snapshot = BlockCompositionSnapshot(
            blocks: [
                .init(id: blockID, title: "Role", categoryRaw: BlockCategory.rolePerspective.rawValue, valueTypeRaw: BlockValueType.string.rawValue, snippet: "ROLE: {{role}}")
            ],
            blockInputs: [blockID.uuidString: ["role": "assistant"]],
            blockModifiers: [:]
        )
        prompt.blockComposition = snapshot

        let model = PromptStudioModel(prompt: prompt)

        #expect(model.canvasBlocks.count == 1)
        #expect(model.canvasBlocks[0].title == "Role")
        #expect(model.canvasBlocks[0].snippet == "ROLE: {{role}}")
        #expect(model.blockInputs[blockID]?["role"] == "assistant")
    }

    // MARK: - Compilation

    @Test func compileNow_producesCorrectOutput() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        // Add a block with a placeholder
        let roleBlock = Block(title: "Role", category: .rolePerspective, valueType: .string, snippet: "ROLE: {{role}}")
        model.addToCanvas(roleBlock)

        // Fill in the placeholder
        let addedBlock = model.canvasBlocks[0]
        model.setBlockInput(blockID: addedBlock.id, placeholder: "role", value: "senior engineer")

        // Trigger immediate compilation
        model.compileNow()

        #expect(model.compiledTemplate.contains("ROLE: senior engineer"))
        #expect(model.filledExample.contains("ROLE: senior engineer"))
        #expect(model.rawTemplate.contains("ROLE: {{role}}"))
    }

    @Test func compileNow_multipleBlocks_joinsWithDoubleNewline() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block1 = Block(title: "Role", category: .rolePerspective, valueType: .string, snippet: "ROLE: {{role}}")
        let block2 = Block(title: "Task", category: .instructions, valueType: .string, snippet: "DO: {{task}}")

        model.addToCanvas(block1)
        model.addToCanvas(block2)

        let b1 = model.canvasBlocks[0]
        let b2 = model.canvasBlocks[1]
        model.setBlockInput(blockID: b1.id, placeholder: "role", value: "writer")
        model.setBlockInput(blockID: b2.id, placeholder: "task", value: "write a poem")
        model.compileNow()

        // Blocks should be separated by double newline
        #expect(model.compiledTemplate.contains("ROLE: writer\n\nDO: write a poem"))
    }

    @Test func compileNow_estimatesTokens() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Task", category: .instructions, valueType: .string, snippet: "DO: {{task}}")
        model.addToCanvas(block)
        let added = model.canvasBlocks[0]
        model.setBlockInput(blockID: added.id, placeholder: "task", value: "something")
        model.compileNow()

        // Token estimate should be roughly chars / 4
        #expect(model.tokenEstimate > 0)
        #expect(model.tokenEstimate == max(1, model.compiledTemplate.count / 4))
    }

    // MARK: - Saving to Prompt

    @Test func saveToPrompt_updatesPromptContent() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context, content: "old content")
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Task", category: .instructions, valueType: .string, snippet: "DO: {{task}}")
        model.addToCanvas(block)
        let added = model.canvasBlocks[0]
        model.setBlockInput(blockID: added.id, placeholder: "task", value: "test it")
        model.compileNow()

        #expect(prompt.content.contains("DO: test it"))
        #expect(prompt.blockSyncState == .synced)
    }

    @Test func saveToPrompt_storesBlockComposition() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Role", category: .rolePerspective, valueType: .string, snippet: "ROLE: {{role}}")
        model.addToCanvas(block)
        model.compileNow()

        let composition = prompt.blockComposition
        #expect(composition != nil)
        #expect(composition?.blocks.count == 1)
        #expect(composition?.blocks[0].title == "Role")
    }

    @Test func saveToPrompt_setsUpdatedAt() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let before = Date()

        let model = PromptStudioModel(prompt: prompt)
        let block = Block(title: "Task", category: .instructions, valueType: .string, snippet: "DO: test")
        model.addToCanvas(block)
        model.compileNow()

        #expect(prompt.updatedAt >= before)
    }

    @Test func saveToPrompt_clearsDirtyFlag() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        model.markDirty()
        #expect(model.isDirty == true)

        model.compileNow() // calls saveToPrompt
        #expect(model.isDirty == false)
    }

    // MARK: - Canvas Operations

    @Test func addToCanvas_appendsBlock() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Tone", category: .toneStyle, valueType: .string, snippet: "TONE: {{tone}}")
        model.addToCanvas(block)

        #expect(model.canvasBlocks.count == 1)
        #expect(model.canvasBlocks[0].title == "Tone")
        // Each add creates a new block with a new ID (not the library block's ID)
        #expect(model.canvasBlocks[0].id != block.id)
    }

    @Test func addToCanvas_extractsPlaceholders() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Persona", category: .rolePerspective, valueType: .object, snippet: "PERSONA:\nTone={{tone}}\nValues={{values}}")
        model.addToCanvas(block)

        let added = model.canvasBlocks[0]
        let inputs = model.blockInputs[added.id]
        #expect(inputs != nil)
        #expect(inputs?["tone"] == "")
        #expect(inputs?["values"] == "")
    }

    @Test func addToCanvas_triggersCompilation() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Use Case", category: .intent, valueType: .string, snippet: "USE_CASE: testing")
        model.addToCanvas(block)

        #expect(model.compiledTemplate.contains("USE_CASE: testing"))
    }

    @Test func removeFromCanvas_removesBlock() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block1 = Block(title: "Block1", category: .instructions, valueType: .string, snippet: "A")
        let block2 = Block(title: "Block2", category: .instructions, valueType: .string, snippet: "B")
        model.addToCanvas(block1)
        model.addToCanvas(block2)
        #expect(model.canvasBlocks.count == 2)

        model.removeFromCanvas(at: IndexSet(integer: 0))

        #expect(model.canvasBlocks.count == 1)
        #expect(model.canvasBlocks[0].title == "Block2")
    }

    @Test func removeFromCanvas_cleansUpInputsAndModifiers() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Role", category: .rolePerspective, valueType: .string, snippet: "ROLE: {{role}}")
        model.addToCanvas(block)
        let addedID = model.canvasBlocks[0].id

        // Verify inputs exist
        #expect(model.blockInputs[addedID] != nil)

        model.removeFromCanvas(at: IndexSet(integer: 0))

        // Inputs should be cleaned up
        #expect(model.blockInputs[addedID] == nil)
        #expect(model.blockModifiers[addedID] == nil)
    }

    @Test func removeFromCanvas_clearsSelectedIfRemoved() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Role", category: .rolePerspective, valueType: .string, snippet: "ROLE: test")
        model.addToCanvas(block)
        let addedID = model.canvasBlocks[0].id
        model.selectedCanvasBlockID = addedID

        model.removeFromCanvas(at: IndexSet(integer: 0))

        #expect(model.selectedCanvasBlockID == nil)
    }

    @Test func removeFromCanvas_updatesCompilation() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block1 = Block(title: "Block1", category: .instructions, valueType: .string, snippet: "FIRST")
        let block2 = Block(title: "Block2", category: .instructions, valueType: .string, snippet: "SECOND")
        model.addToCanvas(block1)
        model.addToCanvas(block2)

        model.removeFromCanvas(at: IndexSet(integer: 0))

        #expect(!model.compiledTemplate.contains("FIRST"))
        #expect(model.compiledTemplate.contains("SECOND"))
    }

    @Test func moveOnCanvas_reordersBlocks() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block1 = Block(title: "A", category: .instructions, valueType: .string, snippet: "AAA")
        let block2 = Block(title: "B", category: .instructions, valueType: .string, snippet: "BBB")
        let block3 = Block(title: "C", category: .instructions, valueType: .string, snippet: "CCC")
        model.addToCanvas(block1)
        model.addToCanvas(block2)
        model.addToCanvas(block3)

        // Move first block to end
        model.moveOnCanvas(from: IndexSet(integer: 0), to: 3)

        #expect(model.canvasBlocks[0].title == "B")
        #expect(model.canvasBlocks[1].title == "C")
        #expect(model.canvasBlocks[2].title == "A")
    }

    // MARK: - Modifier Management

    @Test func addModifier_attachesToBlock() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Task", category: .instructions, valueType: .string, snippet: "DO: test")
        model.addToCanvas(block)
        let blockID = model.canvasBlocks[0].id

        guard let formalModifier = model.modifierLibrary[.tone]?.first(where: { $0.name == "+Formal" }) else {
            #expect(Bool(false), "Expected +Formal modifier in tone library")
            return
        }

        model.addModifierToBlock(blockID: blockID, modifier: formalModifier)

        let attached = model.modifiersForBlock(blockID)
        #expect(attached.count == 1)
        #expect(attached[0].name == "+Formal")
    }

    @Test func removeModifier_removesFromBlock() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        let block = Block(title: "Task", category: .instructions, valueType: .string, snippet: "DO: test")
        model.addToCanvas(block)
        let blockID = model.canvasBlocks[0].id

        guard let modifier = model.modifierLibrary[.format]?.first(where: { $0.name == "+Concise" }) else {
            #expect(Bool(false), "Expected +Concise modifier in format library")
            return
        }

        model.addModifierToBlock(blockID: blockID, modifier: modifier)
        let modID = model.modifiersForBlock(blockID)[0].id

        model.removeModifierFromBlock(blockID: blockID, modifierID: modID)

        #expect(model.modifiersForBlock(blockID).isEmpty)
    }

    // MARK: - Placeholder Extraction

    @Test func placeholders_extractsCorrectNames() {
        let placeholders = PromptStudioModel.placeholders(in: "Hello {{name}}, welcome to {{place}}")
        #expect(placeholders.count == 2)
        #expect(placeholders.contains("name"))
        #expect(placeholders.contains("place"))
    }

    @Test func placeholders_handlesEmptySnippet() {
        let placeholders = PromptStudioModel.placeholders(in: "")
        #expect(placeholders.isEmpty)
    }

    @Test func placeholders_handlesNoPlaceholders() {
        let placeholders = PromptStudioModel.placeholders(in: "No placeholders here")
        #expect(placeholders.isEmpty)
    }

    // MARK: - Compatibility

    @Test func isLibraryBlockCompatible_returnsLevelWhenSelected() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        // Add an Objective block and select it
        guard let objectiveBlock = model.library[.intent]?.first(where: { $0.title == "Objective" }) else {
            #expect(Bool(false), "Expected Objective in library")
            return
        }
        model.addToCanvas(objectiveBlock)
        model.selectedCanvasBlockID = model.canvasBlocks[0].id

        // Success Criteria should be highly compatible with Objective
        guard let successBlock = model.library[.intent]?.first(where: { $0.title == "Success Criteria" }) else {
            #expect(Bool(false), "Expected Success Criteria in library")
            return
        }

        let level = model.isLibraryBlockCompatible(successBlock)
        #expect(level == .high)
    }

    @Test func isLibraryBlockCompatible_returnsNilWithNoSelection() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        guard let block = model.library[.intent]?.first else {
            #expect(Bool(false), "Expected blocks in intent category")
            return
        }

        let level = model.isLibraryBlockCompatible(block)
        #expect(level == nil)
    }

    // MARK: - Dirty State

    @Test func markDirty_setsFlag() throws {
        let context = try makeContext()
        let prompt = makePrompt(in: context)
        let model = PromptStudioModel(prompt: prompt)

        // After init, compileNow is called which calls saveToPrompt and clears dirty
        #expect(model.isDirty == false)

        model.markDirty()
        #expect(model.isDirty == true)
    }
}
