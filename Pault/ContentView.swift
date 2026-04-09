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
import UniformTypeIdentifiers

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

    // Import/Export state
    @State private var importSession: ImportSession? = nil
    @State private var importResult: ImportResult? = nil
    @State private var isDropTargeted: Bool = false
    @State private var isExporting: Bool = false

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
            // Export library as JSON
            .onReceive(NotificationCenter.default.publisher(for: .exportLibraryJSON)) { _ in
                isExporting = true
                ExportService.exportLibraryJSON(prompts: prompts)
                isExporting = false
            }
            // Export library as Markdown
            .onReceive(NotificationCenter.default.publisher(for: .exportLibraryMarkdown)) { _ in
                isExporting = true
                ExportService.exportMarkdown(prompts: prompts)
                isExporting = false
            }
            // Import prompts via NSOpenPanel
            .onReceive(NotificationCenter.default.publisher(for: .importPrompts)) { _ in
                presentImportPanel()
            }
            // Import preview sheet
            .sheet(item: $importSession) { session in
                ImportPreviewSheet(session: Binding(
                    get: { importSession },
                    set: { importSession = $0 }
                ), onComplete: { result in
                    importResult = result
                    // Auto-dismiss banner after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        importResult = nil
                    }
                })
                .environment(\.modelContext, modelContext)
            }
            // Drag-drop file import
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                var urls: [URL] = []
                let group = DispatchGroup()
                for provider in providers {
                    group.enter()
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        if let url = url {
                            urls.append(url)
                        }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    let jsonURLs = urls.filter { $0.pathExtension.lowercased() == "json" }
                    let mdURLs = urls.filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) }
                    guard !jsonURLs.isEmpty || !mdURLs.isEmpty else { return }
                    if let session = ImportOrchestrator.prepare(jsonURLs: jsonURLs, markdownURLs: mdURLs, context: modelContext) {
                        importSession = session
                    }
                }
                return !providers.isEmpty
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
        ZStack(alignment: .top) {
            mainContentLayout

            // Import result summary banner (top-aligned, auto-dismiss)
            if let result = importResult {
                ImportResultBanner(result: result) {
                    importResult = nil
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }

            // Export spinner overlay (centered)
            if isExporting {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Exporting...")
                                .font(.headline)
                        }
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .zIndex(20)
            }

            // Drop indicator overlay
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                                .font(.largeTitle)
                                .foregroundStyle(Color.accentColor)
                            Text("Drop to Import")
                                .font(.headline)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding(20)
                    .zIndex(15)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: importResult != nil)
        .animation(.easeInOut(duration: 0.15), value: isExporting)
        .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
    }

    private var mainContentLayout: some View {
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

    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import Prompts"
        panel.allowedContentTypes = [.json, .plainText]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK else { return }

        let jsonURLs = panel.urls.filter { $0.pathExtension.lowercased() == "json" }
        let mdURLs = panel.urls.filter { ["md", "markdown"].contains($0.pathExtension.lowercased()) }

        if let session = ImportOrchestrator.prepare(jsonURLs: jsonURLs, markdownURLs: mdURLs, context: modelContext) {
            importSession = session
        }
    }
}

// MARK: - ImportResultBanner

private struct ImportResultBanner: View {
    let result: ImportResult
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(summaryText)
                .font(.subheadline)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onTapGesture { onDismiss() }
        .accessibilityLabel("Import result: \(summaryText)")
    }

    private var summaryText: String {
        var parts: [String] = []
        if result.imported > 0 { parts.append("\(result.imported) imported") }
        if result.overwritten > 0 { parts.append("\(result.overwritten) overwritten") }
        if result.skipped > 0 { parts.append("\(result.skipped) skipped") }
        if result.errors > 0 { parts.append("\(result.errors) errors") }
        return parts.isEmpty ? "Nothing to import" : parts.joined(separator: ", ")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Prompt.self, Tag.self, TemplateVariable.self, Attachment.self], inMemory: true)
}
