//
//  BlockLibraryView.swift
//  Pault
//
//  Collapsible block library panel with categories and search.
//  Works with BlockEditorView's collapsible panel system.
//

import SwiftUI

/// Left panel showing the block library with categories and search
struct BlockLibraryView: View {
    @ObservedObject var model: PromptStudioModel
    @ObservedObject var slashState: SlashCommandState

    @State private var searchQuery: String = ""
    @State private var expandedCategories: Set<ConsolidatedBlockCategory> = Set(ConsolidatedBlockCategory.allCases)
    @FocusState private var isSearchFocused: Bool

    // MARK: - Constants

    private let maxRecentBlocks = 3
    private let maxSuggestedCategories = 2

    // MARK: - Recent & Suggested
    // Note: These computed properties are lightweight (iteration over small arrays)
    // and SwiftUI's diffing handles this efficiently. No caching needed.

    private var recentBlocks: [Block] {
        let allBlocks = model.consolidatedLibrary.values.flatMap { $0 }
        return slashState.recentBlockTitles.prefix(maxRecentBlocks).compactMap { title in
            allBlocks.first { $0.title == title }
        }
    }

    private var suggestedBlocks: [(Block, String)] {
        let categories = model.canvasBlocks.map { ConsolidatedBlockCategory.from(legacy: $0.category) }
        guard let suggestion = BlockSuggestionEngine.suggest(canvasCategories: categories) else {
            return []
        }

        var results: [(Block, String)] = []
        for category in suggestion.suggestedCategories.prefix(maxSuggestedCategories) {
            if let blocks = model.consolidatedLibrary[category], let block = blocks.first {
                results.append((block, category.rawValue))
            }
        }
        return results
    }

    // MARK: - Filtering

    private var filteredLibrary: [(ConsolidatedBlockCategory, [Block])] {
        ConsolidatedBlockCategory.allCases.compactMap { category in
            guard let blocks = model.consolidatedLibrary[category], !blocks.isEmpty else { return nil }

            if searchQuery.isEmpty {
                return (category, blocks)
            }

            let filtered = blocks.filter { block in
                block.title.localizedCaseInsensitiveContains(searchQuery) ||
                category.rawValue.localizedCaseInsensitiveContains(searchQuery)
            }

            return filtered.isEmpty ? nil : (category, filtered)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                TextField("Search blocks...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .focused($isSearchFocused)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Block list
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    // Recent section
                    if searchQuery.isEmpty && !recentBlocks.isEmpty {
                        Section {
                            ForEach(recentBlocks) { block in
                                let category = ConsolidatedBlockCategory.from(legacy: block.category)
                                BlockLibraryRowView(
                                    block: block,
                                    category: category,
                                    compatibilityLevel: model.isLibraryBlockCompatible(block),
                                    onAdd: { model.addToCanvas(block) }
                                )
                            }
                        } header: {
                            recentHeader()
                        }
                    }

                    // Suggested section
                    if searchQuery.isEmpty && !suggestedBlocks.isEmpty {
                        Section {
                            ForEach(suggestedBlocks, id: \.0.id) { block, _ in
                                let category = ConsolidatedBlockCategory.from(legacy: block.category)
                                BlockLibraryRowView(
                                    block: block,
                                    category: category,
                                    compatibilityLevel: model.isLibraryBlockCompatible(block),
                                    onAdd: { model.addToCanvas(block) }
                                )
                            }
                        } header: {
                            suggestedHeader()
                        }
                    }

                    ForEach(filteredLibrary, id: \.0) { category, blocks in
                        Section {
                            if expandedCategories.contains(category) {
                                ForEach(blocks) { block in
                                    BlockLibraryRowView(
                                        block: block,
                                        category: category,
                                        compatibilityLevel: model.isLibraryBlockCompatible(block),
                                        onAdd: { model.addToCanvas(block) }
                                    )
                                }
                            }
                        } header: {
                            categoryHeader(category: category, blockCount: blocks.count)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: AppConstants.Panels.blockLibraryMinWidth)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Category Header

    @ViewBuilder
    private func categoryHeader(category: ConsolidatedBlockCategory, blockCount: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedCategories.contains(category) {
                    expandedCategories.remove(category)
                } else {
                    expandedCategories.insert(category)
                }
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundStyle(category.color)

                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(category.color)

                Text("(\(blockCount))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()

                Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recent Header

    @ViewBuilder
    private func recentHeader() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Recent")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Suggested Header

    @ViewBuilder
    private func suggestedHeader() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(.yellow)

            Text("Suggested")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.yellow)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Block Row View

private struct BlockLibraryRowView: View {
    let block: Block
    let category: ConsolidatedBlockCategory
    let compatibilityLevel: CompatibilityLevel?
    let onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(block.valueType.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let level = compatibilityLevel {
                compatibilityBadge(level: level)
            }

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(category.color)
                    .font(.body)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onAdd() }
        .draggable(block)
    }

    @ViewBuilder
    private func compatibilityBadge(level: CompatibilityLevel) -> some View {
        Text(level.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                level == .high ? Color.green.opacity(0.2) :
                (level == .med ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
            )
            .foregroundStyle(
                level == .high ? Color.green :
                (level == .med ? Color.orange : Color.gray)
            )
            .clipShape(Capsule())
    }
}

#Preview {
    let prompt = Prompt(title: "Test", content: "Test content")
    let model = PromptStudioModel(prompt: prompt)
    let slashState = SlashCommandState()
    return BlockLibraryView(model: model, slashState: slashState)
        .frame(height: 600)
}
