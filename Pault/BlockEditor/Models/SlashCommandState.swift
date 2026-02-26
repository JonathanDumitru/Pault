//
//  SlashCommandState.swift
//  Pault
//
//  State management for the slash command palette.
//

import SwiftUI
import Combine

/// State management for the slash command palette
@MainActor
final class SlashCommandState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var query: String = ""
    @Published var selectedIndex: Int = 0

    /// Recent blocks (persisted)
    @AppStorage("recentBlockTitles") private var recentBlockTitlesData: Data = Data()

    var recentBlockTitles: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: recentBlockTitlesData)) ?? []
        }
        set {
            recentBlockTitlesData = (try? JSONEncoder().encode(Array(newValue.prefix(5)))) ?? Data()
        }
    }

    func show() {
        query = ""
        selectedIndex = 0
        isVisible = true
    }

    func hide() {
        isVisible = false
        query = ""
    }

    func recordUsage(block: Block) {
        var recent = recentBlockTitles
        recent.removeAll { $0 == block.title }
        recent.insert(block.title, at: 0)
        recentBlockTitles = Array(recent.prefix(5))
    }

    func moveSelection(by delta: Int, maxIndex: Int) {
        let newIndex = selectedIndex + delta
        selectedIndex = max(0, min(maxIndex - 1, newIndex))
    }

    /// Filter blocks by fuzzy matching query against title and category
    nonisolated static func filterBlocks(_ blocks: [Block], query: String) -> [Block] {
        guard !query.isEmpty else { return blocks }

        let lowercasedQuery = query.lowercased()
        return blocks.filter { block in
            block.title.lowercased().contains(lowercasedQuery) ||
            block.category.rawValue.lowercased().contains(lowercasedQuery)
        }
    }
}
