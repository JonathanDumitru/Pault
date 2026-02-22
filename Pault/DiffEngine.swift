import Foundation

enum DiffEngine {

    enum DiffKind: Equatable {
        case unchanged
        case removed
        case added
    }

    struct LineDiff: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let kind: DiffKind
        let characterDiffs: [CharacterDiff]?

        static func == (lhs: LineDiff, rhs: LineDiff) -> Bool {
            lhs.text == rhs.text && lhs.kind == rhs.kind && lhs.characterDiffs == rhs.characterDiffs
        }
    }

    struct CharacterDiff: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let kind: DiffKind

        static func == (lhs: CharacterDiff, rhs: CharacterDiff) -> Bool {
            lhs.text == rhs.text && lhs.kind == rhs.kind
        }
    }

    // MARK: - Line-level diff with character refinement

    static func diff(old: String, new: String) -> [LineDiff] {
        let oldLines = old.isEmpty ? [] : old.components(separatedBy: "\n")
        let newLines = new.isEmpty ? [] : new.components(separatedBy: "\n")

        let changes = newLines.difference(from: oldLines).inferringMoves()

        // Build sets of removed and inserted offsets
        var removals: [Int: String] = [:]    // old offset -> old text
        var insertions: [Int: String] = [:]  // new offset -> new text

        for change in changes {
            switch change {
            case .remove(let offset, let element, _):
                removals[offset] = element
            case .insert(let offset, let element, _):
                insertions[offset] = element
            }
        }

        // Walk through producing unified diff output
        var result: [LineDiff] = []
        var oldIdx = 0
        var newIdx = 0

        while oldIdx < oldLines.count || newIdx < newLines.count {
            if removals[oldIdx] != nil && insertions[newIdx] != nil {
                // Modified line: pair the removal and insertion for character-level diff
                let oldText = oldLines[oldIdx]
                let newText = newLines[newIdx]
                let charDiffs = characterDiff(old: oldText, new: newText)
                let removedCharDiffs = charDiffs.filter { $0.kind != .added }
                let addedCharDiffs = charDiffs.filter { $0.kind != .removed }
                result.append(LineDiff(text: oldText, kind: .removed, characterDiffs: removedCharDiffs))
                result.append(LineDiff(text: newText, kind: .added, characterDiffs: addedCharDiffs))
                oldIdx += 1
                newIdx += 1
            } else if removals[oldIdx] != nil {
                // Pure removal
                result.append(LineDiff(text: oldLines[oldIdx], kind: .removed, characterDiffs: nil))
                oldIdx += 1
            } else if insertions[newIdx] != nil {
                // Pure insertion
                result.append(LineDiff(text: newLines[newIdx], kind: .added, characterDiffs: nil))
                newIdx += 1
            } else if oldIdx < oldLines.count && newIdx < newLines.count {
                // Unchanged line
                result.append(LineDiff(text: oldLines[oldIdx], kind: .unchanged, characterDiffs: nil))
                oldIdx += 1
                newIdx += 1
            } else if oldIdx < oldLines.count {
                result.append(LineDiff(text: oldLines[oldIdx], kind: .removed, characterDiffs: nil))
                oldIdx += 1
            } else {
                result.append(LineDiff(text: newLines[newIdx], kind: .added, characterDiffs: nil))
                newIdx += 1
            }
        }

        return result
    }

    // MARK: - Character-level diff

    static func characterDiff(old: String, new: String) -> [CharacterDiff] {
        let oldChars = Array(old)
        let newChars = Array(new)
        let changes = newChars.difference(from: oldChars)

        var result: [CharacterDiff] = []
        var oIdx = 0

        for change in changes {
            switch change {
            case .remove(let offset, let element, _):
                // Add unchanged chars before this removal
                while oIdx < offset {
                    result.append(CharacterDiff(text: String(oldChars[oIdx]), kind: .unchanged))
                    oIdx += 1
                }
                result.append(CharacterDiff(text: String(element), kind: .removed))
                oIdx += 1
            case .insert(_, let element, _):
                result.append(CharacterDiff(text: String(element), kind: .added))
            }
        }
        // Remaining unchanged characters
        while oIdx < oldChars.count {
            result.append(CharacterDiff(text: String(oldChars[oIdx]), kind: .unchanged))
            oIdx += 1
        }

        return coalesce(result)
    }

    // MARK: - Coalesce consecutive same-kind segments

    private static func coalesce(_ diffs: [CharacterDiff]) -> [CharacterDiff] {
        guard var current = diffs.first else { return [] }
        var coalesced: [CharacterDiff] = []

        for diff in diffs.dropFirst() {
            if diff.kind == current.kind {
                current = CharacterDiff(text: current.text + diff.text, kind: current.kind)
            } else {
                coalesced.append(current)
                current = diff
            }
        }
        coalesced.append(current)
        return coalesced
    }
}
