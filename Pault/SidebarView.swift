//
//  SidebarView.swift
//  Pault
//

import SwiftUI
import SwiftData

enum SidebarFilter: Hashable {
    case all
    case recent
    case archived
    case tag(Tag)
}

struct SidebarView: View {
    @Environment(\.openWindow) private var openWindow
    @Query(sort: [SortDescriptor(\Prompt.updatedAt, order: .reverse)]) private var allPrompts: [Prompt]
    @Query(sort: [SortDescriptor(\Tag.name, order: .forward)]) private var allTags: [Tag]

    @Binding var selectedPrompt: Prompt?
    @Binding var selectedFilter: SidebarFilter
    @Binding var searchText: String

    var onDelete: ((Prompt) -> Void)?
    var onToggleFavorite: ((Prompt) -> Void)?
    var onToggleArchive: ((Prompt) -> Void)?
    var onCopy: ((Prompt) -> Void)?

    private var filteredPrompts: [Prompt] {
        var prompts = allPrompts

        // Apply filter
        switch selectedFilter {
        case .all:
            prompts = prompts.filter { !$0.isArchived }
        case .recent:
            prompts = prompts
                .filter { !$0.isArchived && $0.lastUsedAt != nil }
                .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            prompts = Array(prompts.prefix(10))
        case .archived:
            prompts = prompts.filter { $0.isArchived }
        case .tag(let tag):
            prompts = prompts.filter { $0.tags.contains(where: { $0.id == tag.id }) && !$0.isArchived }
        }

        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            prompts = prompts.filter {
                $0.title.lowercased().contains(query) ||
                $0.content.lowercased().contains(query) ||
                $0.tags.contains(where: { $0.name.lowercased().contains(query) })
            }
        }

        return prompts
    }

    private var recentCount: Int {
        allPrompts.filter { !$0.isArchived && $0.lastUsedAt != nil }.prefix(10).count
    }

    private var allCount: Int {
        allPrompts.filter { !$0.isArchived }.count
    }

    private var archivedCount: Int {
        allPrompts.filter { $0.isArchived }.count
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all: return "No prompts yet"
        case .recent: return "No recently used prompts"
        case .archived: return "No archived prompts"
        case .tag(let tag): return "No prompts tagged \"\(tag.name)\""
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Filters
            VStack(spacing: 2) {
                FilterRow(title: "Recently Used", icon: "clock", count: recentCount, isSelected: selectedFilter == .recent) {
                    selectedFilter = .recent
                }
                .accessibilityLabel("Recently Used, \(recentCount) prompts")
                FilterRow(title: "All Prompts", icon: "doc.text", count: allCount, isSelected: selectedFilter == .all) {
                    selectedFilter = .all
                }
                .accessibilityLabel("All Prompts, \(allCount) prompts")
                FilterRow(title: "Archived", icon: "archivebox", count: archivedCount, isSelected: selectedFilter == .archived) {
                    selectedFilter = .archived
                }
                .accessibilityLabel("Archived, \(archivedCount) prompts")
            }
            .padding(.horizontal, 8)

            Divider()
                .padding(.vertical, 8)

            // Prompt list
            if filteredPrompts.isEmpty {
                if !searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No matching prompts", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try a different search term")
                    }
                } else {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text(emptyStateMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if selectedFilter == .all {
                            Text("Press ⌘N to create one")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else if selectedFilter == .recent {
                            Text("Copy a prompt to see it here.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                List(selection: $selectedPrompt) {
                    ForEach(filteredPrompts) { prompt in
                        PromptRowView(prompt: prompt) {
                            onToggleFavorite?(prompt)
                        } onTagTap: { tag in
                            selectedFilter = .tag(tag)
                        }
                        .tag(prompt)
                        .help("Double-click to edit")
                        .accessibilityLabel(prompt.title.isEmpty ? "Untitled prompt" : prompt.title)
                        .onTapGesture(count: 2) {
                            openWindow(value: prompt.id)
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { openWindow(value: prompt.id) }
                            Button("Copy", systemImage: "doc.on.doc") { onCopy?(prompt) }
                            Button(prompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: "star") { onToggleFavorite?(prompt) }
                            Button(prompt.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") { onToggleArchive?(prompt) }
                            Divider()
                            Button("Delete", systemImage: "trash", role: .destructive) { onDelete?(prompt) }
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(minWidth: 220)
    }
}

private struct FilterRow: View {
    let title: String
    let icon: String
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                Spacer()
                if let count = count {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct PromptRowView: View {
    let prompt: Prompt
    var onFavoriteTap: (() -> Void)?
    var onTagTap: ((Tag) -> Void)?

    private var displayTitle: String {
        if !prompt.title.isEmpty {
            return prompt.title
        }
        let preview = prompt.content.prefix(30)
        return preview.isEmpty ? "Untitled" : String(preview)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(displayTitle)
                        .font(.headline)
                        .lineLimit(1)

                    if prompt.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favorited")
                    }
                }

                if !prompt.tags.isEmpty {
                    let tags = prompt.tags
                    TagPillsView(tags: tags, maxVisible: 2, isSmall: true, onTagTap: onTagTap)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
