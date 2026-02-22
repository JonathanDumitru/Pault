import Testing
@testable import Pault

struct DiffEngineTests {

    // MARK: - Identical texts

    @Test func diff_identicalTexts_allUnchanged() {
        let result = DiffEngine.diff(old: "hello\nworld", new: "hello\nworld")
        #expect(result.allSatisfy { $0.kind == .unchanged })
        #expect(result.count == 2)
    }

    // MARK: - Empty inputs

    @Test func diff_emptyOldText_allAdded() {
        let result = DiffEngine.diff(old: "", new: "line one\nline two")
        #expect(result.filter { $0.kind == .added }.count == 2)
        #expect(result.filter { $0.kind == .removed }.count == 0)
    }

    @Test func diff_emptyNewText_allRemoved() {
        let result = DiffEngine.diff(old: "line one\nline two", new: "")
        #expect(result.filter { $0.kind == .removed }.count == 2)
        #expect(result.filter { $0.kind == .added }.count == 0)
    }

    @Test func diff_bothEmpty_noResults() {
        let result = DiffEngine.diff(old: "", new: "")
        #expect(result.isEmpty)
    }

    // MARK: - Single line change

    @Test func diff_singleLineChanged_hasCharacterDiffs() {
        let result = DiffEngine.diff(old: "hello world", new: "hello earth")
        // Should produce a removed + added pair with character-level diffs
        let removed = result.filter { $0.kind == .removed }
        let added = result.filter { $0.kind == .added }
        #expect(removed.count == 1)
        #expect(added.count == 1)
        #expect(removed[0].characterDiffs != nil)
        #expect(added[0].characterDiffs != nil)
    }

    // MARK: - Multi-line changes

    @Test func diff_addedLine_detectedCorrectly() {
        let old = "line one\nline three"
        let new = "line one\nline two\nline three"
        let result = DiffEngine.diff(old: old, new: new)
        let added = result.filter { $0.kind == .added }
        #expect(added.count == 1)
        #expect(added[0].text == "line two")
    }

    @Test func diff_removedLine_detectedCorrectly() {
        let old = "line one\nline two\nline three"
        let new = "line one\nline three"
        let result = DiffEngine.diff(old: old, new: new)
        let removed = result.filter { $0.kind == .removed }
        #expect(removed.count == 1)
        #expect(removed[0].text == "line two")
    }

    // MARK: - Character-level refinement

    @Test func characterDiff_identifiesChangedWord() {
        let charDiffs = DiffEngine.characterDiff(old: "the quick brown fox", new: "the slow brown fox")
        let changed = charDiffs.filter { $0.kind != .unchanged }
        #expect(!changed.isEmpty)
    }

    // MARK: - Per-side character diff filtering

    @Test func diff_modifiedLine_removedSideHasNoAddedCharDiffs() throws {
        let result = DiffEngine.diff(old: "hello world", new: "hello earth")
        let removed = result.filter { $0.kind == .removed }
        #expect(removed.count == 1)

        let removedCharDiffs = try #require(removed[0].characterDiffs)
        let addedSegments = removedCharDiffs.filter { $0.kind == .added }
        #expect(addedSegments.isEmpty, "Removed line should contain no .added character diffs")
    }

    @Test func diff_modifiedLine_addedSideHasNoRemovedCharDiffs() throws {
        let result = DiffEngine.diff(old: "hello world", new: "hello earth")
        let added = result.filter { $0.kind == .added }
        #expect(added.count == 1)

        let addedCharDiffs = try #require(added[0].characterDiffs)
        let removedSegments = addedCharDiffs.filter { $0.kind == .removed }
        #expect(removedSegments.isEmpty, "Added line should contain no .removed character diffs")
    }

    // MARK: - Coalescing

    @Test func characterDiff_coalescesConsecutiveSameKindSegments() {
        // "hello world" -> "hello earth" produces 18 individual character segments
        // before coalescing; after coalescing they should be merged into far fewer
        let charDiffs = DiffEngine.characterDiff(old: "hello world", new: "hello earth")

        // Without coalescing we'd have 18 segments (one per character).
        // Coalescing should merge consecutive same-kind segments into 3 total.
        #expect(charDiffs.count < 18, "Coalescing should reduce segment count significantly")

        // Consecutive removed characters should be merged into one segment
        let removedSegments = charDiffs.filter { $0.kind == .removed }
        #expect(removedSegments.count == 1, "Consecutive removed chars should be coalesced into one segment")

        // Consecutive added characters should be merged into one segment
        let addedSegments = charDiffs.filter { $0.kind == .added }
        #expect(addedSegments.count == 1, "Consecutive added chars should be coalesced into one segment")

        // Consecutive unchanged characters should be merged into one segment
        let unchangedSegments = charDiffs.filter { $0.kind == .unchanged }
        #expect(unchangedSegments.count == 1, "Consecutive unchanged chars should be coalesced into one segment")
    }

    @Test func characterDiff_coalescesPreservesAllText() {
        // Verify that coalescing doesn't lose any text content
        let charDiffs = DiffEngine.characterDiff(old: "hello world", new: "hello earth")

        let removedText = charDiffs.filter { $0.kind == .removed }.map(\.text).joined()
        let addedText = charDiffs.filter { $0.kind == .added }.map(\.text).joined()

        // Both sides should have non-empty changed text
        #expect(!removedText.isEmpty, "Should have removed text")
        #expect(!addedText.isEmpty, "Should have added text")
        #expect(addedText == "eath", "Added text should be 'eath'")
    }
}
