//
//  MenuBarContentView.swift
//  Pault
//

import SwiftUI
import SwiftData

enum MenuBarFilter: Hashable {
    case favorites
    case all
    case archived
    case tag(Tag)
}

struct MenuBarContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Prompt.updatedAt, order: .reverse)]) private var prompts: [Prompt]

    @State private var searchText: String = ""
    @State private var selectedFilter: MenuBarFilter = .all
    @State private var expandedPromptID: UUID? = nil
    @State private var isCreatingNew: Bool = false
    @State private var promptToDelete: Prompt?
    @State private var showCopyToast: Bool = false

    private var service: PromptService { PromptService(modelContext: modelContext) }

    private var filteredPrompts: [Prompt] {
        service.filterPrompts(
            prompts,
            showArchived: selectedFilter == .archived,
            showOnlyFavorites: selectedFilter == .favorites,
            tagFilter: selectedFilter.tagValue,
            searchText: searchText
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search prompts...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // Filter tabs
            HStack(spacing: 0) {
                FilterTab(title: "★ Favorites", isSelected: selectedFilter == .favorites) {
                    selectedFilter = .favorites
                }
                FilterTab(title: "All", isSelected: selectedFilter == .all) {
                    selectedFilter = .all
                }
                FilterTab(title: "Archived", isSelected: selectedFilter == .archived) {
                    selectedFilter = .archived
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            // Prompt list
            if filteredPrompts.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: emptyStateIcon)
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(emptyStateMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPrompts) { prompt in
                            MenuBarPromptRow(
                                prompt: prompt,
                                isExpanded: expandedPromptID == prompt.id,
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedPromptID = expandedPromptID == prompt.id ? nil : prompt.id
                                    }
                                },
                                onCopy: {
                                    service.copyToClipboard(prompt)
                                    withAnimation { showCopyToast = true }
                                },
                                onToggleFavorite: { service.toggleFavorite(prompt) },
                                onArchive: { service.toggleArchive(prompt) },
                                onDelete: { promptToDelete = prompt }
                            )
                            Divider()
                        }
                    }
                }
            }

            Divider()

            // Bottom bar
            HStack {
                Button(action: { isCreatingNew = true }) {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: openMainWindow) {
                    Image(systemName: "macwindow")
                }
                .buttonStyle(.plain)
                .help("Open Main Window")

                Button(action: openSettings) {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(10)
        }
        .copyToast(isShowing: $showCopyToast)
        .frame(width: AppConstants.Windows.menuBarDefault.width,
               height: AppConstants.Windows.menuBarDefault.height)
        .sheet(isPresented: $isCreatingNew) {
            NewPromptSheet(isPresented: $isCreatingNew)
        }
        .alert("Delete Prompt?", isPresented: Binding(
            get: { promptToDelete != nil },
            set: { if !$0 { promptToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let prompt = promptToDelete {
                    service.deletePrompt(prompt)
                }
                promptToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                promptToDelete = nil
            }
        } message: {
            if let prompt = promptToDelete {
                Text("Are you sure you want to delete \"\(prompt.title.isEmpty ? "Untitled" : prompt.title)\"?")
            }
        }
    }

    private var emptyStateIcon: String {
        if !searchText.isEmpty { return "magnifyingglass" }
        switch selectedFilter {
        case .favorites: return "star"
        case .archived: return "archivebox"
        default: return "doc.text"
        }
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty { return "No results found" }
        switch selectedFilter {
        case .favorites: return "No favorites yet.\nStar a prompt to see it here."
        case .archived: return "No archived prompts"
        default: return "No prompts yet"
        }
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "main" ||
            ($0.isVisible && $0.canBecomeMain && !$0.className.contains("Panel"))
        }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            if let delegate = NSApp.delegate as? AppDelegate {
                delegate.closePopover()
            }
        }
    }
}

// MARK: - Helper to extract Tag from MenuBarFilter

private extension MenuBarFilter {
    var tagValue: Tag? {
        if case .tag(let tag) = self { return tag }
        return nil
    }
}

// MARK: - Subviews

private struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private struct MenuBarPromptRow: View {
    let prompt: Prompt
    let isExpanded: Bool
    let onTap: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    private var displayTitle: String {
        if !prompt.title.isEmpty { return prompt.title }
        let preview = prompt.content.prefix(30)
        return preview.isEmpty ? "Untitled" : String(preview)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(displayTitle)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            if prompt.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        if !prompt.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(prompt.tags.prefix(2)) { tag in
                                    Text("#\(tag.name)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if prompt.tags.count > 2 {
                                    Text("+\(prompt.tags.count - 2)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
                        .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand") prompt actions")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt.content)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(6)
                        .padding(.horizontal, 12)

                    HStack(spacing: 8) {
                        Button(action: onCopy) {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Copies prompt text to clipboard")

                        Spacer()

                        Menu {
                            Button(action: onToggleFavorite) {
                                Label(prompt.isFavorite ? "Unfavorite" : "Favorite", systemImage: "star")
                            }
                            .accessibilityHint(prompt.isFavorite ? "Removes from favorites" : "Adds to favorites")
                            Button(action: onArchive) {
                                Label(prompt.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
                            }
                            .accessibilityHint(prompt.isArchived ? "Unarchives this prompt" : "Archives this prompt")
                            Divider()
                            Button(role: .destructive, action: onDelete) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.caption)
                        }
                        .menuStyle(.borderlessButton)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            }
        }
        .background(isExpanded ? Color(nsColor: .controlBackgroundColor).opacity(0.3) : Color.clear)
    }
}

private struct NewPromptSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool

    @State private var title: String = ""
    @State private var content: String = ""

    private var service: PromptService { PromptService(modelContext: modelContext) }

    var body: some View {
        VStack(spacing: 12) {
            Text("New Prompt")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $content)
                .frame(height: 120)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    service.createPrompt(title: title, content: content)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 280)
    }
}

#Preview {
    MenuBarContentView()
        .modelContainer(for: [Prompt.self, Tag.self], inMemory: true)
}
