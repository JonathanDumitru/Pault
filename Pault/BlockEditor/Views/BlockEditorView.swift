//
//  BlockEditorView.swift
//  Pault
//
//  Main container for the visual block editor with collapsible panels.
//  Layout: [Library] | Canvas | [Preview]
//  Default state: Canvas only (panels collapsed)
//

import SwiftUI

/// The main block editor view with collapsible panels
struct BlockEditorView: View {
    @Bindable var prompt: Prompt
    @StateObject private var model: PromptStudioModel
    @StateObject private var autoCollapse = AutoCollapseManager()
    @StateObject private var slashState = SlashCommandState()

    // Panel visibility state with persistence
    @AppStorage("showBlockLibrary") private var showLibrary: Bool = false
    @AppStorage("showBlockPreview") private var showPreview: Bool = false

    @State private var showOnboardingTip = false
    @AppStorage("hasSeenBlockEditorOnboarding") private var hasSeenOnboarding = false

    // Dirty navigation warning
    @State private var showDirtyNavigationAlert = false
    @State private var pendingPromptID: UUID? = nil

    // Accessibility
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(prompt: Prompt) {
        self.prompt = prompt
        self._model = StateObject(wrappedValue: PromptStudioModel(prompt: prompt))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Block editor toolbar
            blockEditorToolbar

            Divider()

            // Content area with collapsible panels
            HStack(spacing: 0) {
                // Left pane: Block Library
                if showLibrary {
                    BlockLibraryView(model: model, slashState: slashState)
                        .frame(width: AppConstants.Panels.blockLibraryWidth)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .autoCollapseWarning(autoCollapse)
                        .protectFromAutoCollapse(autoCollapse, panel: .blockLibrary)

                    Divider()
                }

                // Center pane: Composition Canvas
                CompositionCanvasView(model: model, slashState: slashState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Right pane: Preview
                if showPreview {
                    Divider()

                    CompiledPreviewView(model: model, prompt: prompt)
                        .frame(width: AppConstants.Panels.blockPreviewWidth)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .autoCollapseWarning(autoCollapse)
                        .protectFromAutoCollapse(autoCollapse, panel: .blockPreview)
                }
            }
            .animation(
                reduceMotion ? nil : .spring(
                    response: AppConstants.Panels.Animation.slideDuration,
                    dampingFraction: AppConstants.Panels.Animation.dampingFraction
                ),
                value: showLibrary
            )
            .animation(
                reduceMotion ? nil : .spring(
                    response: AppConstants.Panels.Animation.slideDuration,
                    dampingFraction: AppConstants.Panels.Animation.dampingFraction
                ),
                value: showPreview
            )

            // Preview strip (always visible at bottom)
            PreviewStripView(model: model, isExpanded: $showPreview)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            // First-time user onboarding tip
            if showOnboardingTip {
                OnboardingTipView(onDismiss: dismissOnboarding)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .onAppear {
            // Inject the window's UndoManager so Cmd+Z/Shift+Cmd+Z work via the responder chain.
            // We use NSApp.keyWindow to get the system UndoManager rather than @Environment
            // to avoid a SwiftUI + Swift Concurrency crash on macOS 26 (swift_task_isMainExecutorImpl).
            model.undoManager = NSApp.keyWindow?.undoManager

            // Show onboarding tip for first-time users with empty canvas
            if !hasSeenOnboarding && model.canvasBlocks.isEmpty {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(0.5)) {
                    showOnboardingTip = true
                }
            }
        }
        .onChange(of: prompt.id) { _, newID in
            if model.isDirty {
                // Show dirty navigation warning — store pending ID, then let user decide
                pendingPromptID = newID
                showDirtyNavigationAlert = true
            } else {
                // Clean — navigate immediately
                model.clearUndoHistory()
                model.loadFromPrompt()
                model.compileNow()
            }
        }
        .alert("Unsaved Changes", isPresented: $showDirtyNavigationAlert) {
            Button("Save") {
                model.saveToPrompt()
                model.clearUndoHistory()
                model.loadFromPrompt()
                model.compileNow()
                pendingPromptID = nil
            }
            Button("Discard", role: .destructive) {
                model.clearUndoHistory()
                model.loadFromPrompt()
                model.compileNow()
                pendingPromptID = nil
            }
            Button("Cancel", role: .cancel) {
                pendingPromptID = nil
            }
        } message: {
            Text("You have unsaved changes. Would you like to save before continuing?")
        }
        .onChange(of: model.canvasBlocks.count) { old, new in
            // Dismiss tip when user adds first block
            if old == 0 && new > 0 && showOnboardingTip {
                dismissOnboarding()
            }
            // Trigger auto-collapse when blocks change (user is editing)
            if old != new {
                autoCollapse.userDidType()
            }
        }
        // Auto-collapse handler (disabled when VoiceOver is active)
        .onChange(of: autoCollapse.shouldCollapse) { _, shouldCollapse in
            if shouldCollapse && !voiceOverEnabled {
                withAnimation(
                    reduceMotion ? nil : .spring(
                        response: AppConstants.Panels.Animation.slideDuration,
                        dampingFraction: AppConstants.Panels.Animation.dampingFraction
                    )
                ) {
                    showLibrary = false
                    showPreview = false
                }
                autoCollapse.didCollapse()
            } else if shouldCollapse && voiceOverEnabled {
                // Don't collapse — just reset the trigger so it can fire again later
                autoCollapse.didCollapse()
            }
        }
        // Escape key collapses all panels
        .onKeyPress(.escape) {
            if showLibrary || showPreview {
                withAnimation(reduceMotion ? nil : .default) {
                    showLibrary = false
                    showPreview = false
                }
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Toolbar

    private var blockEditorToolbar: some View {
        HStack(spacing: 12) {
            // Library toggle (left)
            Button(action: {
                withAnimation(reduceMotion ? nil : .default) {
                    showLibrary.toggle()
                    if showLibrary { autoCollapse.userDidExpandPanel() }
                }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.body)
                    .foregroundStyle(showLibrary ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("[", modifiers: .command)
            .help("Toggle Block Library (⌘[)")

            Divider()
                .frame(height: 16)

            Text("Block Editor")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            // Save button
            Button(action: { model.saveToPrompt() }) {
                Label("Save", systemImage: "square.and.arrow.down")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .disabled(!model.isDirty)
            .keyboardShortcut("s", modifiers: .command)
            .help("Save composition (⌘S)")

            Divider()
                .frame(height: 16)

            // Preview toggle (right)
            Button(action: {
                withAnimation(reduceMotion ? nil : .default) {
                    showPreview.toggle()
                    if showPreview { autoCollapse.userDidExpandPanel() }
                }
            }) {
                Image(systemName: "sidebar.right")
                    .font(.body)
                    .foregroundStyle(showPreview ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("]", modifiers: .command)
            .help("Toggle Preview Panel (⌘])")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func dismissOnboarding() {
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2)) {
            showOnboardingTip = false
        }
        hasSeenOnboarding = true
    }
}

// MARK: - Onboarding Tip View

private struct OnboardingTipView: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome to the Block Editor")
                    .font(.callout)
                    .fontWeight(.semibold)

                Text("Press ⌘[ to open the block library. Drag blocks to build your prompt visually. Use ↑↓ to navigate and ⌫ to remove blocks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    let prompt = Prompt(title: "Test Prompt", content: "Test content")
    return BlockEditorView(prompt: prompt)
        .frame(width: 1000, height: 600)
}
