//
//  BlockCompositionSnapshotTests.swift
//  PaultTests
//
//  Tests for BlockCompositionSnapshot encode/decode round-trips,
//  Prompt block editor property accessors, and snapshot conversions.
//

import Testing
import Foundation
import SwiftData
@testable import Pault

@MainActor
struct BlockCompositionSnapshotTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Prompt.self, TemplateVariable.self, Pault.Tag.self, Attachment.self,
                CopyEvent.self, PromptRun.self, PromptVersion.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - Round-trip encode/decode

    @Test func roundTrip_preservesBlocks() throws {
        let blockID = UUID()
        let snapshot = BlockCompositionSnapshot(
            blocks: [
                .init(id: blockID, title: "System Role", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are {{role}}")
            ],
            blockInputs: [blockID.uuidString: ["role": "a helpful assistant"]],
            blockModifiers: [:],
            lastCompiledHash: "abc123"
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BlockCompositionSnapshot.self, from: data)

        #expect(decoded.blocks.count == 1)
        #expect(decoded.blocks[0].id == blockID)
        #expect(decoded.blocks[0].title == "System Role")
        #expect(decoded.blocks[0].categoryRaw == "Role & Perspective")
        #expect(decoded.blocks[0].valueTypeRaw == "string")
        #expect(decoded.blocks[0].snippet == "You are {{role}}")
        #expect(decoded.lastCompiledHash == "abc123")
    }

    @Test func roundTrip_preservesInputs() throws {
        let id1 = UUID()
        let id2 = UUID()
        let snapshot = BlockCompositionSnapshot(
            blocks: [
                .init(id: id1, title: "B1", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "{{x}}"),
                .init(id: id2, title: "B2", categoryRaw: "Instructions", valueTypeRaw: "object", snippet: "{{y}}")
            ],
            blockInputs: [
                id1.uuidString: ["x": "hello"],
                id2.uuidString: ["y": "world"]
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BlockCompositionSnapshot.self, from: data)

        #expect(decoded.blockInputs[id1.uuidString]?["x"] == "hello")
        #expect(decoded.blockInputs[id2.uuidString]?["y"] == "world")
    }

    @Test func roundTrip_preservesModifiers() throws {
        let blockID = UUID()
        let modID = UUID()
        let snapshot = BlockCompositionSnapshot(
            blocks: [
                .init(id: blockID, title: "Block", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "Do X")
            ],
            blockModifiers: [
                blockID.uuidString: [
                    .init(id: modID, name: "Be Concise", categoryRaw: "Quality", snippet: "Keep it brief", description: "Brevity modifier")
                ]
            ]
        )

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BlockCompositionSnapshot.self, from: data)

        let mods = try #require(decoded.blockModifiers[blockID.uuidString])
        #expect(mods.count == 1)
        #expect(mods[0].id == modID)
        #expect(mods[0].name == "Be Concise")
        #expect(mods[0].categoryRaw == "Quality")
        #expect(mods[0].snippet == "Keep it brief")
        #expect(mods[0].description == "Brevity modifier")
    }

    @Test func roundTrip_emptySnapshot() throws {
        let snapshot = BlockCompositionSnapshot()

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BlockCompositionSnapshot.self, from: data)

        #expect(decoded.blocks.isEmpty)
        #expect(decoded.blockInputs.isEmpty)
        #expect(decoded.blockModifiers.isEmpty)
        #expect(decoded.lastCompiledHash == nil)
    }

    // MARK: - BlockSnapshot <-> Block conversion

    @Test func blockSnapshot_convertsFromBlock() throws {
        let block = Block(
            title: "Intent",
            category: .intent,
            valueType: .string,
            snippet: "Summarize {{topic}}"
        )

        let snapshot = BlockCompositionSnapshot.BlockSnapshot(block: block)

        #expect(snapshot.id == block.id)
        #expect(snapshot.title == "Intent")
        #expect(snapshot.categoryRaw == BlockCategory.intent.rawValue)
        #expect(snapshot.valueTypeRaw == BlockValueType.string.rawValue)
        #expect(snapshot.snippet == "Summarize {{topic}}")
    }

    @Test func blockSnapshot_convertsToBlock() throws {
        let id = UUID()
        let snapshot = BlockCompositionSnapshot.BlockSnapshot(
            id: id,
            title: "Role",
            categoryRaw: BlockCategory.rolePerspective.rawValue,
            valueTypeRaw: BlockValueType.object.rawValue,
            snippet: "Act as {{persona}}"
        )

        let block = try #require(snapshot.toBlock())

        #expect(block.id == id)
        #expect(block.title == "Role")
        #expect(block.category == .rolePerspective)
        #expect(block.valueType == .object)
        #expect(block.snippet == "Act as {{persona}}")
    }

    @Test func blockSnapshot_toBlockReturnsNilForInvalidCategory() {
        let snapshot = BlockCompositionSnapshot.BlockSnapshot(
            title: "Bad",
            categoryRaw: "NonExistentCategory",
            valueTypeRaw: "string",
            snippet: ""
        )

        #expect(snapshot.toBlock() == nil)
    }

    @Test func blockSnapshot_toBlockReturnsNilForInvalidValueType() {
        let snapshot = BlockCompositionSnapshot.BlockSnapshot(
            title: "Bad",
            categoryRaw: "Instructions",
            valueTypeRaw: "nonexistent",
            snippet: ""
        )

        #expect(snapshot.toBlock() == nil)
    }

    // MARK: - BlockModifierSnapshot <-> BlockModifier conversion

    @Test func modifierSnapshot_convertsFromModifier() throws {
        let modifier = BlockModifier(
            name: "Concise",
            category: .quality,
            snippet: "Be brief",
            description: "Short answers"
        )

        let snapshot = BlockCompositionSnapshot.BlockModifierSnapshot(modifier: modifier)

        #expect(snapshot.id == modifier.id)
        #expect(snapshot.name == "Concise")
        #expect(snapshot.categoryRaw == ModifierCategory.quality.rawValue)
        #expect(snapshot.snippet == "Be brief")
        #expect(snapshot.description == "Short answers")
    }

    @Test func modifierSnapshot_convertsToModifier() throws {
        let id = UUID()
        let snapshot = BlockCompositionSnapshot.BlockModifierSnapshot(
            id: id,
            name: "Formal",
            categoryRaw: ModifierCategory.tone.rawValue,
            snippet: "Use formal tone",
            description: "Professional language"
        )

        let modifier = try #require(snapshot.toModifier())

        #expect(modifier.id == id)
        #expect(modifier.name == "Formal")
        #expect(modifier.category == .tone)
        #expect(modifier.snippet == "Use formal tone")
        #expect(modifier.description == "Professional language")
    }

    @Test func modifierSnapshot_toModifierReturnsNilForInvalidCategory() {
        let snapshot = BlockCompositionSnapshot.BlockModifierSnapshot(
            name: "Bad",
            categoryRaw: "InvalidCategory",
            snippet: "",
            description: ""
        )

        #expect(snapshot.toModifier() == nil)
    }

    // MARK: - Prompt editingMode

    @Test func prompt_editingModeDefaultsToText() throws {
        let context = try makeContext()
        let prompt = Prompt(title: "Test", content: "Hello")
        context.insert(prompt)

        #expect(prompt.editingMode == .text)
        #expect(prompt.editingModeRaw == nil)
    }

    @Test func prompt_editingModeSetterUpdatesRaw() throws {
        let context = try makeContext()
        let prompt = Prompt(title: "Test", content: "Hello")
        context.insert(prompt)

        prompt.editingMode = .blocks
        #expect(prompt.editingModeRaw == "blocks")
        #expect(prompt.editingMode == .blocks)

        prompt.editingMode = .text
        #expect(prompt.editingModeRaw == "text")
        #expect(prompt.editingMode == .text)
    }

    // MARK: - Prompt blockSyncState

    @Test func prompt_blockSyncStateDefaultsToNil() throws {
        let context = try makeContext()
        let prompt = Prompt(title: "Test", content: "Hello")
        context.insert(prompt)

        #expect(prompt.blockSyncState == nil)
        #expect(prompt.blockSyncStateRaw == nil)
    }

    @Test func prompt_blockSyncStateSetterUpdatesRaw() throws {
        let context = try makeContext()
        let prompt = Prompt(title: "Test", content: "Hello")
        context.insert(prompt)

        prompt.blockSyncState = .synced
        #expect(prompt.blockSyncStateRaw == "synced")
        #expect(prompt.blockSyncState == .synced)

        prompt.blockSyncState = .diverged
        #expect(prompt.blockSyncStateRaw == "diverged")
        #expect(prompt.blockSyncState == .diverged)

        prompt.blockSyncState = nil
        #expect(prompt.blockSyncStateRaw == nil)
        #expect(prompt.blockSyncState == nil)
    }

    // MARK: - Prompt blockComposition getter/setter

    @Test func prompt_blockCompositionNilByDefault() throws {
        let context = try makeContext()
        let prompt = Prompt(title: "Test", content: "Hello")
        context.insert(prompt)

        #expect(prompt.blockComposition == nil)
        #expect(prompt.blockCompositionData == nil)
    }

    @Test func prompt_blockCompositionGetterSetterRoundTrips() throws {
        let context = try makeContext()
        let prompt = Prompt(title: "Test", content: "Hello")
        context.insert(prompt)

        let blockID = UUID()
        let modID = UUID()
        let composition = BlockCompositionSnapshot(
            blocks: [
                .init(id: blockID, title: "Intent", categoryRaw: "Intent & Framing", valueTypeRaw: "string", snippet: "Summarize {{topic}}")
            ],
            blockInputs: [blockID.uuidString: ["topic": "AI safety"]],
            blockModifiers: [
                blockID.uuidString: [
                    .init(id: modID, name: "Concise", categoryRaw: "Quality", snippet: "Be brief", description: "Short")
                ]
            ],
            lastCompiledHash: "hash42"
        )

        prompt.blockComposition = composition

        // Verify data was serialised
        #expect(prompt.blockCompositionData != nil)

        // Read it back
        let restored = try #require(prompt.blockComposition)
        #expect(restored.blocks.count == 1)
        #expect(restored.blocks[0].id == blockID)
        #expect(restored.blocks[0].title == "Intent")
        #expect(restored.blockInputs[blockID.uuidString]?["topic"] == "AI safety")
        #expect(restored.blockModifiers[blockID.uuidString]?.count == 1)
        #expect(restored.blockModifiers[blockID.uuidString]?[0].name == "Concise")
        #expect(restored.lastCompiledHash == "hash42")
    }

    @Test func prompt_blockCompositionSetToNilClearsData() throws {
        let context = try makeContext()
        let prompt = Prompt(title: "Test", content: "Hello")
        context.insert(prompt)

        prompt.blockComposition = BlockCompositionSnapshot(
            blocks: [.init(title: "A", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "X")]
        )
        #expect(prompt.blockCompositionData != nil)

        prompt.blockComposition = nil
        #expect(prompt.blockCompositionData == nil)
        #expect(prompt.blockComposition == nil)
    }

    // MARK: - Init defaults

    @Test func prompt_initNewParamsDefaultToNil() throws {
        let prompt = Prompt(title: "T", content: "C")
        #expect(prompt.blockCompositionData == nil)
        #expect(prompt.editingModeRaw == nil)
        #expect(prompt.blockSyncStateRaw == nil)
    }
}
