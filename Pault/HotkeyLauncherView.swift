//
//  HotkeyLauncherView.swift
//  Pault
//

import SwiftUI
import SwiftData

struct HotkeyLauncherView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Prompt.updatedAt, order: .reverse)]) private var prompts: [Prompt]

    @AppStorage("defaultAction") private var defaultAction: String = "showOptions"

    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var showingActions: Bool = false
    @State private var selectedPrompt: Prompt? = nil
    @FocusState private var isSearchFocused: Bool

    let onDismiss: () -> Void

    private var service: PromptService { PromptService(modelContext: modelContext) }

    private var filteredPrompts: [Prompt] {
        if searchText.isEmpty {
            // Show favorites first, then others, capped at 9
            let nonArchived = prompts.filter { !$0.isArchived }
            let favorites = nonArchived.filter { $0.isFavorite }
            let others = nonArchived.filter { !$0.isFavorite }
            return Array((favorites + others).prefix(9))
        }

        return service.filterPrompts(
            prompts,
            searchText: searchText
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingActions, let prompt = selectedPrompt {
                actionView(for: prompt)
            } else {
                searchView
            }
        }
        .frame(width: 500)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onKeyPress(.escape) {
            if showingActions {
                showingActions = false
                selectedPrompt = nil
                return .handled
            }
            onDismiss()
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredPrompts.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            if !showingActions, filteredPrompts.indices.contains(selectedIndex) {
                let prompt = filteredPrompts[selectedIndex]
                performDefaultAction(on: prompt)
            }
            return .handled
        }
        .onKeyPress(phases: .down) { keyPress in
            // ⌘1-9 to instantly select a prompt
            guard !showingActions,
                  keyPress.modifiers == .command,
                  let digit = keyPress.characters.first?.wholeNumberValue,
                  digit >= 1 && digit <= 9 else {
                return .ignored
            }
            let index = digit - 1
            if filteredPrompts.indices.contains(index) {
                performDefaultAction(on: filteredPrompts[index])
                return .handled
            }
            return .ignored
        }
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                TextField("Search prompts...", text: $searchText)
                    .font(.title3)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onAppear { isSearchFocused = true }
                    .onSubmit {
                        if filteredPrompts.indices.contains(selectedIndex) {
                            let prompt = filteredPrompts[selectedIndex]
                            performDefaultAction(on: prompt)
                        }
                    }
            }
            .padding(16)

            Divider()

            if filteredPrompts.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Text(searchText.isEmpty ? "No prompts yet" : "No results")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: 250)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredPrompts.enumerated()), id: \.element.id) { index, prompt in
                            LauncherResultRow(
                                prompt: prompt,
                                index: index,
                                isSelected: index == selectedIndex,
                                onSelect: {
                                    performDefaultAction(on: prompt)
                                },
                                onQuickCopy: {
                                    service.copyToClipboard(prompt)
                                    onDismiss()
                                }
                            )
                            .onHover { hovering in
                                if hovering { selectedIndex = index }
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    private func actionView(for prompt: Prompt) -> some View {
        VStack(spacing: 16) {
            Text(prompt.title.isEmpty ? "Untitled" : prompt.title)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 12) {
                ActionButton(title: "Copy", shortcut: "C", icon: "doc.on.doc") {
                    service.copyToClipboard(prompt)
                    onDismiss()
                }
            }
            .padding(.horizontal)
        }
        .padding(20)
        .onKeyPress { keyPress in
            if keyPress.modifiers.contains(.command) {
                switch keyPress.characters {
                case "c":
                    service.copyToClipboard(prompt)
                    onDismiss()
                    return .handled
                default:
                    break
                }
            }
            return .ignored
        }
    }

    private func performDefaultAction(on prompt: Prompt) {
        switch defaultAction {
        case "copy":
            service.copyToClipboard(prompt)
            onDismiss()
        default: // "showOptions"
            selectedPrompt = prompt
            showingActions = true
        }
    }
}

// MARK: - Subviews

private struct LauncherResultRow: View {
    let prompt: Prompt
    let index: Int
    let isSelected: Bool
    let onSelect: () -> Void
    let onQuickCopy: () -> Void

    private var displayTitle: String {
        if !prompt.title.isEmpty { return prompt.title }
        return String(prompt.content.prefix(40))
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                if index < 9 {
                    Text("⌘\(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(width: 30)
                } else {
                    Spacer().frame(width: 30)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(displayTitle)
                            .lineLimit(1)
                        if prompt.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                    if !prompt.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(prompt.tags.prefix(3)) { tag in
                                Text("#\(tag.name)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ActionButton: View {
    let title: String
    let shortcut: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                Text(shortcut)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 70, height: 70)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

#Preview {
    HotkeyLauncherView(onDismiss: {})
        .modelContainer(for: [Prompt.self, Tag.self], inMemory: true)
}
