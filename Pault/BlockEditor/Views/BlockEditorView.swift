//
//  BlockEditorView.swift
//  Pault
//
//  Main 3-pane container for the visual block editor.
//  Layout: Library (left) | Canvas (center) | Preview+Inspector (right)
//

import SwiftUI

/// The main block editor view with 3-pane layout
struct BlockEditorView: View {
    @Bindable var prompt: Prompt
    @StateObject private var model: PromptStudioModel

    @State private var showLibrary = true
    @State private var showPreview = true
    @State private var showOnboardingTip = false
    @AppStorage("hasSeenBlockEditorOnboarding") private var hasSeenOnboarding = false

    init(prompt: Prompt) {
        self.prompt = prompt
        self._model = StateObject(wrappedValue: PromptStudioModel(prompt: prompt))
    }

    var body: some View {
        HSplitView {
            // Left pane: Block Library
            if showLibrary {
                BlockLibraryView(model: model)
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)
            }

            // Center pane: Composition Canvas
            CompositionCanvasView(model: model)
                .frame(minWidth: 300)

            // Right pane: Preview + Inspector
            if showPreview {
                CompiledPreviewView(model: model, prompt: prompt)
                    .frame(minWidth: 220, idealWidth: 280, maxWidth: 350)
            }
        }
        .overlay(alignment: .top) {
            // First-time user onboarding tip
            if showOnboardingTip {
                OnboardingTipView(onDismiss: dismissOnboarding)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Library toggle
                Button(action: { withAnimation { showLibrary.toggle() } }) {
                    Image(systemName: "sidebar.left")
                        .foregroundStyle(showLibrary ? .primary : .secondary)
                }
                .help("Toggle Block Library (⌘[)")
                .keyboardShortcut("[", modifiers: .command)

                // Preview toggle
                Button(action: { withAnimation { showPreview.toggle() } }) {
                    Image(systemName: "sidebar.right")
                        .foregroundStyle(showPreview ? .primary : .secondary)
                }
                .help("Toggle Preview Panel (⌘])")
                .keyboardShortcut("]", modifiers: .command)

                Divider()

                // Save button
                Button(action: { model.saveToPrompt() }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .disabled(!model.isDirty)
                .help("Save composition to prompt (⌘S)")
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .onAppear {
            // Show onboarding tip for first-time users with empty canvas
            if !hasSeenOnboarding && model.canvasBlocks.isEmpty {
                withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                    showOnboardingTip = true
                }
            }
        }
        .onChange(of: prompt.id) { _, _ in
            // Reload model when prompt changes
            model.loadFromPrompt()
            model.compileNow()
        }
        .onChange(of: model.canvasBlocks.count) { old, new in
            // Dismiss tip when user adds first block
            if old == 0 && new > 0 && showOnboardingTip {
                dismissOnboarding()
            }
        }
    }

    private func dismissOnboarding() {
        withAnimation(.easeIn(duration: 0.2)) {
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

                Text("Drag blocks from the library on the left to build your prompt visually. Use ↑↓ to navigate and ⌫ to remove blocks.")
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
