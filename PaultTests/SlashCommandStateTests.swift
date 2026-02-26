//
//  SlashCommandStateTests.swift
//  PaultTests
//
//  Tests for SlashCommandState: filtering, visibility, selection, and recent blocks.
//

import Testing
@testable import Pault

struct SlashCommandStateTests {

    @Test func filterBlocks_returnsAllWhenQueryEmpty() {
        let blocks = [
            Block(title: "Expert", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "")

        #expect(results.count == 2)
    }

    @Test func filterBlocks_fuzzyMatchesByTitle() {
        let blocks = [
            Block(title: "Expert Advisor", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task Definition", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "exp")

        #expect(results.count == 1)
        #expect(results.first?.title == "Expert Advisor")
    }

    @Test func filterBlocks_matchesByCategory() {
        let blocks = [
            Block(title: "Expert", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "role")

        #expect(results.count == 1)
        #expect(results.first?.title == "Expert")
    }

    @Test func filterBlocks_caseInsensitiveMatch() {
        let blocks = [
            Block(title: "Expert Advisor", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task Definition", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "EXPERT")

        #expect(results.count == 1)
        #expect(results.first?.title == "Expert Advisor")
    }

    @Test @MainActor func show_setsVisibleAndResetsState() {
        let state = SlashCommandState()
        state.query = "old query"
        state.selectedIndex = 5

        state.show()

        #expect(state.isVisible == true)
        #expect(state.query == "")
        #expect(state.selectedIndex == 0)
    }

    @Test @MainActor func hide_clearsVisibilityAndQuery() {
        let state = SlashCommandState()
        state.isVisible = true
        state.query = "some query"

        state.hide()

        #expect(state.isVisible == false)
        #expect(state.query == "")
    }

    @Test @MainActor func moveSelection_incrementsWithinBounds() {
        let state = SlashCommandState()
        state.selectedIndex = 2

        state.moveSelection(by: 1, maxIndex: 10)

        #expect(state.selectedIndex == 3)
    }

    @Test @MainActor func moveSelection_decrementsWithinBounds() {
        let state = SlashCommandState()
        state.selectedIndex = 5

        state.moveSelection(by: -1, maxIndex: 10)

        #expect(state.selectedIndex == 4)
    }

    @Test @MainActor func moveSelection_clampsToZero() {
        let state = SlashCommandState()
        state.selectedIndex = 0

        state.moveSelection(by: -5, maxIndex: 10)

        #expect(state.selectedIndex == 0)
    }

    @Test @MainActor func moveSelection_clampsToMaxIndexMinusOne() {
        let state = SlashCommandState()
        state.selectedIndex = 8

        state.moveSelection(by: 5, maxIndex: 10)

        #expect(state.selectedIndex == 9)
    }

    @Test @MainActor func recordUsage_addsBlockToRecent() {
        let state = SlashCommandState()
        let block = Block(title: "Test Block", category: .instructions, valueType: .string, snippet: "")

        state.recordUsage(block: block)

        #expect(state.recentBlockTitles.contains("Test Block"))
    }

    @Test @MainActor func recordUsage_movesExistingToFront() {
        let state = SlashCommandState()
        let block1 = Block(title: "First", category: .instructions, valueType: .string, snippet: "")
        let block2 = Block(title: "Second", category: .instructions, valueType: .string, snippet: "")

        state.recordUsage(block: block1)
        state.recordUsage(block: block2)
        state.recordUsage(block: block1)  // Use first again

        #expect(state.recentBlockTitles.first == "First")
    }

    @Test @MainActor func recordUsage_limitsToFiveRecent() {
        let state = SlashCommandState()

        for i in 1...7 {
            let block = Block(title: "Block \(i)", category: .instructions, valueType: .string, snippet: "")
            state.recordUsage(block: block)
        }

        #expect(state.recentBlockTitles.count == 5)
        #expect(state.recentBlockTitles.first == "Block 7")
    }
}
