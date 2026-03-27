//
//  ContentView.swift
//  Pault
//
//  Created by Jonathan Hines Dumitru on 12/16/25.
//
//  Main window with collapsible sidebar and inspector panels.
//  Layout: [Sidebar] | Editor | [Inspector]
//  Default state: Editor only (panels collapsed)
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
    @State private var promptToDelete: Prompt?
    @State private var showCopyToast: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var showingAnalytics: Bool = false
    @State private var showCreationLaunchpad: Bool = false

    // Panel visibility state with persistence
    @AppStorage("showSidebar") private var showSidebar: Bool = false
    @AppStorage("showInspector") private var showInspector: Bool = false

    // Auto-collapse manager
    @StateObject private var autoCollapse = AutoCollapseManager()

    private var service: PromptService { PromptService(modelContext: modelContext) }

    var body: some View {
        mainContent
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
            .sheet(isPresented: $showingAnalytics) {
                AnalyticsView()
            }
            .sheet(isPresented: $showCreationLaunchpad) {
                PromptLaunchpadView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .createNewPrompt)) { _ in
                showCreationLaunchpad = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .promptCreated)) { notification in
                guard let promptID = notification.userInfo?["promptID"] as? UUID else { return }
                selectedPrompt = prompts.first(where: { $0.id == promptID })
            }
            // Auto-collapse handler
            .onChange(of: autoCollapse.shouldCollapse) { _, shouldCollapse in
                if shouldCollapse {
                    withAnimation(.spring(response: AppConstants.Panels.Animation.slideDuration, dampingFraction: AppConstants.Panels.Animation.dampingFraction)) {
                        showSidebar = false
                        showInspector = false
                    }
                    autoCollapse.didCollapse()
                }
            }
            // Escape key collapses all panels
            .onKeyPress(.escape) {
                if showSidebar || showInspector {
                    withAnimation {
                        showSidebar = false
                        showInspector = false
                    }
                    return .handled
                }
                return .ignored
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top toolbar
            mainToolbar

            Divider()

            // Content area with collapsible panels
            HStack(spacing: 0) {
                // Sidebar panel (leading)
                if showSidebar {
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
                    .frame(width: AppConstants.Panels.sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .autoCollapseWarning(autoCollapse)
                    .protectFromAutoCollapse(autoCollapse, panel: .sidebar)

                    Divider()
                }

                // Center content (detail view)
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Inspector panel (trailing)
                if showInspector, let prompt = selectedPrompt {
                    Divider()

                    InspectorView(prompt: prompt)
                        .frame(width: AppConstants.Panels.inspectorWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .autoCollapseWarning(autoCollapse)
                        .protectFromAutoCollapse(autoCollapse, panel: .inspector)
                }
            }
            .animation(.spring(response: AppConstants.Panels.Animation.slideDuration, dampingFraction: AppConstants.Panels.Animation.dampingFraction), value: showSidebar)
            .animation(.spring(response: AppConstants.Panels.Animation.slideDuration, dampingFraction: AppConstants.Panels.Animation.dampingFraction), value: showInspector)
        }
    }

    // MARK: - Toolbar

    private var mainToolbar: some View {
        HStack(spacing: 12) {
            // Sidebar toggle (left)
            Button(action: {
                withAnimation {
                    showSidebar.toggle()
                    if showSidebar { autoCollapse.userDidExpandPanel() }
                }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.body)
                    .foregroundStyle(showSidebar ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("1", modifiers: .command)
            .help("Toggle Sidebar (⌘1)")

            Divider()
                .frame(height: 16)

            // Title / Breadcrumb
            if let prompt = selectedPrompt {
                Text(prompt.title.isEmpty ? "Untitled" : prompt.title)
                    .font(.headline)
                    .lineLimit(1)
            } else {
                Text("No Prompt Selected")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Action buttons
            if selectedPrompt != nil {
                Button(action: copySelectedPrompt) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("c", modifiers: .command)
                .help("Copy Prompt Content (⌘C)")

                Button(action: editSelectedPrompt) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .keyboardShortcut("e", modifiers: .command)
                .help("Edit Prompt (⌘E)")
            }

            Button(action: { showCreationLaunchpad = true }) {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .help("New Prompt (⌘N)")

            if ProFeature.isUnlocked(.analytics) {
                Button {
                    showingAnalytics = true
                } label: {
                    Image(systemName: "chart.bar")
                }
                .buttonStyle(.plain)
                .help("Analytics")
            }

            Divider()
                .frame(height: 16)

            // Inspector toggle (right)
            Button(action: {
                withAnimation {
                    showInspector.toggle()
                    if showInspector { autoCollapse.userDidExpandPanel() }
                }
            }) {
                Image(systemName: "info.circle")
                    .font(.body)
                    .foregroundStyle(showInspector ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("i", modifiers: .command)
            .help("Toggle Inspector (⌘I)")
            .disabled(selectedPrompt == nil)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Detail Content

    @ViewBuilder
    private var detailContent: some View {
        if let prompt = selectedPrompt {
            PromptDetailView(
                prompt: prompt,
                showInspector: $showInspector,
                autoCollapseManager: autoCollapse
            )
            .id(prompt.id)
        } else {
            EmptyDetailView()
        }
    }

    // MARK: - Actions

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
