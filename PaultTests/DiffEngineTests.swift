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
}
