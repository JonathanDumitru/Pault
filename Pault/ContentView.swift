//
//  ContentView.swift
//  Pault
//
//  Created by Jonathan Hines Dumitru on 12/16/25.
//

import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: [SortDescriptor(\Prompt.updatedAt, order: .reverse)]) private var prompts: [Prompt]

    @State private var selectedPrompt: Prompt?
    @State private var selectedFilter: SidebarFilter = .all
    @State private var searchText: String = ""
    @State private var showInspector: Bool = false
    @State private var promptToDelete: Prompt?
    @State private var showCopyToast: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding: Bool = false

    private var service: PromptService { PromptService(modelContext: modelContext) }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedPrompt: $selectedPrompt,
                selectedFilter: $selectedFilter,
                searchText: $searchText,
                onDelete: { promptToDelete = $0 },
                onToggleFavorite: { service.toggleFavorite($0) },
                onToggleArchive: { service.toggleArchive($0) },
                onCopy: { prompt in
                    service.copyToClipboard(prompt)
                    withAnimation { showCopyToast = true }
                }
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let prompt = selectedPrompt {
                PromptPreviewView(prompt: prompt, showInspector: $showInspector)
                    .id(prompt.id)
            } else {
                EmptyDetailView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: copySelectedPrompt) {
                    Image(systemName: "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(selectedPrompt == nil)
                .help("Copy Prompt Content (⌘C)")

                Button(action: editSelectedPrompt) {
                    Image(systemName: "pencil")
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(selectedPrompt == nil)
                .help("Edit Prompt (⌘E)")

                Button(action: { openWindow(id: "new-prompt") }) {
                    Image(systemName: "plus")
                }
                .help("New Prompt (⌘N)")
            }
        }
        .copyToast(isShowing: $showCopyToast)
        .frame(minWidth: 700, minHeight: 500)
        .onDeleteCommand {
            if let prompt = selectedPrompt {
                promptToDelete = prompt
            }
        }
        .alert("Delete Prompt?", isPresented: Binding(
            get: { promptToDelete != nil },
            set: { if !$0 { promptToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let prompt = promptToDelete {
                    deletePrompt(prompt)
                }
                promptToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                promptToDelete = nil
            }
        } message: {
            if let prompt = promptToDelete {
                Text("Are you sure you want to delete \"\(prompt.title.isEmpty ? "Untitled" : prompt.title)\"? This cannot be undone.")
            }
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onChange(of: showOnboarding) { _, newValue in
            if !newValue {
                hasCompletedOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewPrompt)) { _ in
            openWindow(id: "new-prompt")
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptCreated)) { notification in
            guard let promptID = notification.userInfo?["promptID"] as? UUID else { return }
            selectedPrompt = prompts.first(where: { $0.id == promptID })
        }
    }

    private func deletePrompt(_ prompt: Prompt) {
        if selectedPrompt?.id == prompt.id {
            selectedPrompt = nil
        }
        service.deletePrompt(prompt)
    }

    private func editSelectedPrompt() {
        guard let prompt = selectedPrompt else { return }
        openWindow(value: prompt.id)
    }

    private func copySelectedPrompt() {
        guard let prompt = selectedPrompt else { return }
        service.copyToClipboard(prompt)
        withAnimation { showCopyToast = true }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Prompt.self, Tag.self, TemplateVariable.self, Attachment.self], inMemory: true)
}
