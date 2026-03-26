//
//  CompilationCacheTests.swift
//  PaultTests
//
//  Tests for CompilationCache: cache key generation with modifiers, cache invalidation.
//

import Testing
import Foundation
@testable import Pault

@MainActor
struct CompilationCacheTests {

    // MARK: - Helpers

    private func makeBlock(id: UUID = UUID(), snippet: String = "Test snippet") -> BlockData {
        BlockData(id: id, title: "Test Block", category: "intent", valueType: "string", snippet: snippet)
    }

    private func makeModifier(id: UUID = UUID(), snippet: String = "Modifier snippet") -> BlockModifier {
        BlockModifier(id: id, name: "Test Modifier", category: .format, snippet: snippet)
    }

    // MARK: - Cache Key: Same State Produces Same Key

    @Test func generateCacheKey_withSameState_producesSameKey() {
        let blockID = UUID()
        let modifierID = UUID()
        let block = makeBlock(id: blockID, snippet: "DO: {{task}}")
        let modifier = makeModifier(id: modifierID, snippet: "FORMAT: json")

        let blockInputs: [UUID: [String: String]] = [blockID: ["task": "write tests"]]
        let blockModifiers: [UUID: [BlockModifier]] = [blockID: [modifier]]
        let modifierInputs: [UUID: [String: String]] = [:]

        let key1 = CompilationCache.shared.generateCacheKey(
            blocks: [block],
            blockInputs: blockInputs,
            blockModifiers: blockModifiers,
            modifierInputs: modifierInputs
        )
        let key2 = CompilationCache.shared.generateCacheKey(
            blocks: [block],
            blockInputs: blockInputs,
            blockModifiers: blockModifiers,
            modifierInputs: modifierInputs
        )

        #expect(key1 == key2)
    }

    // MARK: - Cache Key: Different Modifiers Produce Different Keys

    @Test func generateCacheKey_differentModifiers_producesDifferentKey() {
        let blockID = UUID()
        let block = makeBlock(id: blockID, snippet: "DO: {{task}}")
        let blockInputs: [UUID: [String: String]] = [blockID: ["task": "write tests"]]
        let modifierInputs: [UUID: [String: String]] = [:]

        let modifier1 = makeModifier(snippet: "FORMAT: json")
        let modifier2 = makeModifier(snippet: "FORMAT: markdown")

        let key1 = CompilationCache.shared.generateCacheKey(
            blocks: [block],
            blockInputs: blockInputs,
            blockModifiers: [blockID: [modifier1]],
            modifierInputs: modifierInputs
        )
        let key2 = CompilationCache.shared.generateCacheKey(
            blocks: [block],
            blockInputs: blockInputs,
            blockModifiers: [blockID: [modifier2]],
            modifierInputs: modifierInputs
        )

        #expect(key1 != key2)
    }

    // MARK: - Cache Key: No Modifiers vs With Modifiers

    @Test func generateCacheKey_noModifiers_vsWithModifiers_producesDifferentKey() {
        let blockID = UUID()
        let block = makeBlock(id: blockID, snippet: "DO: {{task}}")
        let blockInputs: [UUID: [String: String]] = [blockID: ["task": "write tests"]]
        let modifierInputs: [UUID: [String: String]] = [:]

        let modifier = makeModifier(snippet: "LENGTH: short")

        let keyWithout = CompilationCache.shared.generateCacheKey(
            blocks: [block],
            blockInputs: blockInputs,
            blockModifiers: [:],
            modifierInputs: modifierInputs
        )
        let keyWith = CompilationCache.shared.generateCacheKey(
            blocks: [block],
            blockInputs: blockInputs,
            blockModifiers: [blockID: [modifier]],
            modifierInputs: modifierInputs
        )

        #expect(keyWithout != keyWith)
    }

    // MARK: - Cache Key: Modifier Input Changes Produce Different Keys

    @Test func generateCacheKey_modifierInputChange_producesDifferentKey() {
        let blockID = UUID()
        let modifierID = UUID()
        let block = makeBlock(id: blockID, snippet: "DO: {{task}}")
        let modifier = makeModifier(id: modifierID, snippet: "VERBOSITY: {{level}}")

        let blockInputs: [UUID: [String: String]] = [blockID: ["task": "write"]]
        let blockModifiers: [UUID: [BlockModifier]] = [blockID: [modifier]]

        let modifierInputs1: [UUID: [String: String]] = [modifierID: ["level": "concise"]]
        let modifierInputs2: [UUID: [String: String]] = [modifierID: ["level": "verbose"]]

        let key1 = CompilationCache.shared.generateCacheKey(
            blocks: [block],
            blockInputs: blockInputs,
            blockModifiers: blockModifiers,
            modifierInputs: modifierInputs1
        )
        let key2 = CompilationCache.shared.generateCacheKey(
            blocks: [block],
            blockInputs: blockInputs,
            blockModifiers: blockModifiers,
            modifierInputs: modifierInputs2
        )

        #expect(key1 != key2)
    }

    // MARK: - CanvasUndoSnapshot Captures State

    @Test func canvasUndoSnapshot_capturesAllFields() {
        let block = Block(title: "Role", category: .rolePerspective, valueType: .string, snippet: "ROLE: {{role}}")
        let modID = UUID()
        let modifier = makeModifier(id: modID, snippet: "FORMAT: json")
        let inputs: [String: String] = ["role": "developer"]
        let modifiers: [BlockModifier] = [modifier]
        let modifierInputs: [UUID: [String: String]] = [modID: ["level": "verbose"]]

        let snapshot = CanvasUndoSnapshot(
            block: block,
            index: 2,
            inputs: inputs,
            modifiers: modifiers,
            modifierInputs: modifierInputs
        )

        #expect(snapshot.block.id == block.id)
        #expect(snapshot.index == 2)
        #expect(snapshot.inputs == inputs)
        #expect(snapshot.modifiers.count == 1)
        #expect(snapshot.modifiers[0].id == modID)
        #expect(snapshot.modifierInputs[modID]?["level"] == "verbose")
    }
}
