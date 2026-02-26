//
//  BlockLibraryView.swift
//  Pault
//
//  Block library sidebar with categories and search.
//  Adapted from Schemap for Pault's block editor integration.
//

import SwiftUI

/// Left sidebar showing the block library with categories and search
struct BlockLibraryView: View {
    @ObservedObject var model: PromptStudioModel

    @State private var searchQuery: String = ""
    @State private var expandedCategories: Set<BlockCategory> = Set(BlockCategory.allCases)
    @FocusState private var isSearchFocused: Bool

    // MARK: - Filtering

    private var filteredLibrary: [(BlockCategory, [Block])] {
        BlockCategory.allCases.compactMap { category in
            guard let blocks = model.library[category], !blocks.isEmpty else { return nil }

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
                    ForEach(filteredLibrary, id: \.0) { category, blocks in
                        Section {
                            ForEach(blocks) { block in
                                BlockLibraryRowView(
                                    block: block,
                                    category: category,
                                    compatibilityLevel: model.isLibraryBlockCompatible(block),
                                    onAdd: { model.addToCanvas(block) }
                                )
                            }
                        } header: {
                            categoryHeader(category: category)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Category Header

    @ViewBuilder
    private func categoryHeader(category: BlockCategory) -> some View {
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
                Circle()
                    .fill(category.color)
                    .frame(width: 8, height: 8)

                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(category.color)

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
}

// MARK: - Block Row View

private struct BlockLibraryRowView: View {
    let block: Block
    let category: BlockCategory
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
    return BlockLibraryView(model: model)
        .frame(height: 600)
}
