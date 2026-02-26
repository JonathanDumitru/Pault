//
//  SlashCommandPaletteView.swift
//  Pault
//
//  Floating palette for quick block insertion via slash commands.
//  Shows search, recent blocks, and category-grouped results.
//

import SwiftUI

/// Floating palette for quick block insertion via slash commands
struct SlashCommandPaletteView: View {
    @ObservedObject var state: SlashCommandState
    @ObservedObject var model: PromptStudioModel
    let onSelect: (Block) -> Void

    @FocusState private var isSearchFocused: Bool

    private var filteredBlocks: [Block] {
        let allBlocks = model.library.values.flatMap { $0 }
        return SlashCommandState.filterBlocks(allBlocks, query: state.query)
    }

    private var recentBlocks: [Block] {
        let allBlocks = model.library.values.flatMap { $0 }
        return state.recentBlockTitles.compactMap { title in
            allBlocks.first { $0.title == title }
        }
    }

    private var groupedResults: [(ConsolidatedBlockCategory, [Block])] {
        let filtered = filteredBlocks
        return ConsolidatedBlockCategory.allCases.compactMap { category in
            let blocks = filtered.filter { ConsolidatedBlockCategory.from(legacy: $0.category) == category }
            return blocks.isEmpty ? nil : (category, blocks)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search blocks...", text: $state.query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { selectCurrent() }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Results
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Recent section
                        if state.query.isEmpty && !recentBlocks.isEmpty {
                            sectionHeader("Recent", icon: "clock.fill")
                            ForEach(recentBlocks) { block in
                                blockRow(block, isSelected: isSelected(block))
                            }
                            Divider().padding(.vertical, 4)
                        }

                        // Grouped results
                        ForEach(groupedResults, id: \.0) { category, blocks in
                            sectionHeader(category.rawValue, icon: category.icon, color: category.color)
                            ForEach(blocks) { block in
                                blockRow(block, isSelected: isSelected(block))
                                    .id(block.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: state.selectedIndex) { _, newIndex in
                    if let block = blockAtIndex(newIndex) {
                        proxy.scrollTo(block.id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 320, height: 400)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        .onAppear { isSearchFocused = true }
        .onKeyPress(.upArrow) {
            state.moveSelection(by: -1, maxIndex: totalBlockCount)
            return .handled
        }
        .onKeyPress(.downArrow) {
            state.moveSelection(by: 1, maxIndex: totalBlockCount)
            return .handled
        }
        .onKeyPress(.escape) {
            state.hide()
            return .handled
        }
    }

    // MARK: - Helpers

    private var totalBlockCount: Int {
        (state.query.isEmpty ? recentBlocks.count : 0) + filteredBlocks.count
    }

    private func blockAtIndex(_ index: Int) -> Block? {
        var currentIndex = 0

        if state.query.isEmpty {
            for block in recentBlocks {
                if currentIndex == index { return block }
                currentIndex += 1
            }
        }

        for block in filteredBlocks {
            if currentIndex == index { return block }
            currentIndex += 1
        }

        return nil
    }

    private func isSelected(_ block: Block) -> Bool {
        blockAtIndex(state.selectedIndex)?.id == block.id
    }

    private func selectCurrent() {
        if let block = blockAtIndex(state.selectedIndex) {
            state.recordUsage(block: block)
            onSelect(block)
            state.hide()
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String, color: Color = .secondary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func blockRow(_ block: Block, isSelected: Bool) -> some View {
        Button(action: {
            state.recordUsage(block: block)
            onSelect(block)
            state.hide()
        }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(block.category.color)
                    .frame(width: 8, height: 8)

                Text(block.title)
                    .font(.callout)

                Spacer()

                Text(ConsolidatedBlockCategory.from(legacy: block.category).rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let prompt = Prompt(title: "Test", content: "")
    let model = PromptStudioModel(prompt: prompt)
    let state = SlashCommandState()
    state.isVisible = true

    return SlashCommandPaletteView(state: state, model: model) { block in
        print("Selected: \(block.title)")
    }
}
