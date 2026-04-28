//
//  CompositionCanvasView.swift
//  Pault
//
//  Central canvas displaying the ordered block composition.
//  Users drag blocks from the library, reorder them, and fill in placeholders.
//
//  Features (02-02):
//  - Position-aware drop with 2pt line indicator between blocks
//  - Library-to-canvas drag at specific positions (insertOnCanvas)
//  - ScrollViewReader + auto-scroll to newly added block
//  - 13 keyboard shortcuts (Option+Up/Down, Cmd+D, Enter, Esc, Delete, Cmd+/, etc.)
//  - Visible focus ring on selected block
//  - Block count warning at 30+ blocks
//  - Empty canvas drop zone with dashed border
//  - Right-click context menu delegated to BlockRowView
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Accessibility

// MARK: - LibraryBlockTransfer
// Thin Transferable wrapper for library-originated drags.
// This is separate from the Block.self Transferable used by .onMove so we can
// distinguish library drops from reorder drags in the per-row dropDestination.
struct LibraryBlockTransfer: Transferable, Codable {
    let blockID: UUID
    let title: String
    let categoryRaw: String
    let valueTypeRaw: String
    let snippet: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .init(exportedAs: "com.pault.libraryblock"))
    }
}

/// Central pane showing the block stack with inputs and modifiers
struct CompositionCanvasView: View {
    @ObservedObject var model: PromptStudioModel
    @ObservedObject var slashState: SlashCommandState

    @State private var draggedBlockID: UUID?
    @State private var dropTargetIndex: Int? = nil
    @FocusState private var isFocused: Bool

    // Suggestion banner state
    @State private var dismissedSuggestionHash: Int? = nil
    @State private var showSuggestion = false
    @AppStorage("showBlockSuggestions") private var suggestionsEnabled: Bool = true

    // Toast for Cmd+Shift+C copy action
    @State private var showCopyToast = false

    // Paywall state for block limit gate
    @State private var showPaywall = false
    @State private var paywallFeature: ProFeature = .unlimitedBlocks

    // Accessibility environments
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Current suggestion based on canvas state
    private var currentSuggestion: BlockSuggestion? {
        guard suggestionsEnabled else { return nil }

        let categories = model.canvasBlocks.map {
            ConsolidatedBlockCategory.from(legacy: $0.category)
        }

        if let suggestion = BlockSuggestionEngine.suggest(canvasCategories: categories) {
            if suggestion.message.hashValue == dismissedSuggestionHash {
                return nil
            }
            return suggestion
        }

        return BlockSuggestionEngine.shouldShowTokenWarning(tokenCount: model.tokenEstimate)
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // Header
                canvasHeader

                Divider()

                // Canvas content
                if model.canvasBlocks.isEmpty {
                    emptyCanvasState
                } else {
                    blockList
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .focusable()
            .focused($isFocused)
            // ---- Keyboard shortcuts ----
            // Option+Up: move selected block up
            .onKeyPress(.upArrow, phases: .down) { keyPress in
                if keyPress.modifiers.contains(.option) {
                    return handleMoveBlock(direction: -1)
                }
                return handleArrowKey(direction: -1)
            }
            // Option+Down: move selected block down
            .onKeyPress(.downArrow, phases: .down) { keyPress in
                if keyPress.modifiers.contains(.option) {
                    return handleMoveBlock(direction: 1)
                }
                return handleArrowKey(direction: 1)
            }
            // Delete / ForwardDelete / Cmd+Backspace: remove selected block
            .onKeyPress(.delete) { handleDelete() }
            .onKeyPress(.deleteForward) { handleDelete() }
            .onKeyPress(phases: .down) { keyPress in
                // Cmd+Backspace: delete
                if keyPress.key == KeyEquivalent("\u{8}") && keyPress.modifiers == .command {
                    return handleDelete()
                }
                // Cmd+D: duplicate
                if keyPress.key == KeyEquivalent("d") && keyPress.modifiers == .command {
                    return handleDuplicate()
                }
                // Enter / Return: toggle expand/collapse on selected block
                if keyPress.key == KeyEquivalent("\r") {
                    return handleToggleExpand()
                }
                // Cmd+/: open slash command palette
                if keyPress.key == KeyEquivalent("/") && keyPress.modifiers == .command {
                    slashState.show()
                    return .handled
                }
                // Cmd+Shift+E: toggle all blocks expanded/collapsed
                if keyPress.key == KeyEquivalent("e") && keyPress.modifiers == [.command, .shift] {
                    return handleToggleAllExpanded()
                }
                // Cmd+Shift+C: copy compiled prompt to clipboard
                if keyPress.key == KeyEquivalent("c") && keyPress.modifiers == [.command, .shift] {
                    return handleCopyCompiledPrompt()
                }
                // Cmd+Home (fn+Left on Mac keyboards): scroll to first block
                if keyPress.key == KeyEquivalent("\u{F729}") && keyPress.modifiers == .command {
                    model.selectedCanvasBlockID = model.canvasBlocks.first?.id
                    return .handled
                }
                // Cmd+End (fn+Right on Mac keyboards): scroll to last block
                if keyPress.key == KeyEquivalent("\u{F72B}") && keyPress.modifiers == .command {
                    model.selectedCanvasBlockID = model.canvasBlocks.last?.id
                    return .handled
                }
                // Layered Esc: dismiss palette > picker > help > deselect > collapse
                if keyPress.key == .escape {
                    return handleLayeredEsc()
                }
                return .ignored
            }
            // Canvas-level drop destination for library blocks (fallback when empty)
            .dropDestination(for: Block.self) { items, _ in
                for block in items {
                    guard ProFeature.isUnlocked(.unlimitedBlocks) || model.canvasBlocks.count < ProFeature.freeBlockLimit else {
                        paywallFeature = .unlimitedBlocks
                        showPaywall = true
                        return false
                    }
                    withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
                        model.addToCanvas(block)
                    }
                }
                return !items.isEmpty
            }
            // Slash palette overlay
            .overlay {
                if slashState.isVisible {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { slashState.hide() }

                    SlashCommandPaletteView(state: slashState, model: model) { block in
                        // Check block limit for free users
                        guard ProFeature.isUnlocked(.unlimitedBlocks) || model.canvasBlocks.count < ProFeature.freeBlockLimit else {
                            paywallFeature = .unlimitedBlocks
                            showPaywall = true
                            return
                        }
                        withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
                            model.addToCanvas(block)
                            // After insert, select, scroll, and drive focus into first input
                            if let last = model.canvasBlocks.last {
                                model.selectedCanvasBlockID = last.id
                                model.pendingFirstInputFocusBlockID = last.id
                            }
                        }
                    }
                }
            }
            // Block count warning banner
            if model.canvasBlocks.count >= AppConstants.Canvas.blockCountWarning {
                blockCountWarningBanner
            }

            // Copy toast
            if showCopyToast {
                copyToastView
            }
        }
        .onChange(of: model.canvasBlocks.count) { oldCount, newCount in
            if newCount > oldCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if currentSuggestion != nil {
                        withAnimation(reduceMotion ? nil : .default) { showSuggestion = true }
                    }
                }
                // Post polite VoiceOver announcement for block addition
                let count = newCount
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    AccessibilityNotification.Announcement("Block added. \(count) block\(count == 1 ? "" : "s") on canvas.").post()
                }
            } else if newCount < oldCount {
                // Post polite VoiceOver announcement for block removal
                let count = newCount
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    AccessibilityNotification.Announcement("Block removed. \(count) block\(count == 1 ? "" : "s") on canvas.").post()
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Composition canvas, \(model.canvasBlocks.count) block\(model.canvasBlocks.count == 1 ? "" : "s")")
        .sheet(isPresented: $showPaywall) {
            PaywallView(featureName: paywallFeature.displayName, featureDescription: paywallFeature.description, featureIcon: paywallFeature.sfSymbol)
        }
    }

    // MARK: - Keyboard Handlers

    private func handleArrowKey(direction: Int) -> KeyPress.Result {
        guard !model.canvasBlocks.isEmpty else { return .ignored }

        if let selectedID = model.selectedCanvasBlockID,
           let currentIndex = model.canvasBlocks.firstIndex(where: { $0.id == selectedID }) {
            let newIndex = max(0, min(model.canvasBlocks.count - 1, currentIndex + direction))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                model.selectedCanvasBlockID = model.canvasBlocks[newIndex].id
            }
        } else {
            let block = direction > 0 ? model.canvasBlocks.first : model.canvasBlocks.last
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                model.selectedCanvasBlockID = block?.id
            }
        }
        return .handled
    }

    private func handleMoveBlock(direction: Int) -> KeyPress.Result {
        guard let selectedID = model.selectedCanvasBlockID else { return .ignored }
        withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
            model.moveBlock(id: selectedID, direction: direction)
        }
        return .handled
    }

    private func handleDelete() -> KeyPress.Result {
        guard let selectedID = model.selectedCanvasBlockID,
              let index = model.canvasBlocks.firstIndex(where: { $0.id == selectedID }) else {
            return .ignored
        }

        withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
            model.removeFromCanvas(at: IndexSet(integer: index))
        }

        // Focus management: next block, or previous if last was deleted
        if !model.canvasBlocks.isEmpty {
            let newIndex = min(index, model.canvasBlocks.count - 1)
            model.selectedCanvasBlockID = model.canvasBlocks[newIndex].id
        } else {
            model.selectedCanvasBlockID = nil
        }
        return .handled
    }

    private func handleDuplicate() -> KeyPress.Result {
        guard let selectedID = model.selectedCanvasBlockID else { return .ignored }
        withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
            model.duplicateBlock(id: selectedID)
        }
        // Select the duplicated block (inserted right after original)
        if let originalIndex = model.canvasBlocks.firstIndex(where: { $0.id == selectedID }),
           originalIndex + 1 < model.canvasBlocks.count {
            model.selectedCanvasBlockID = model.canvasBlocks[originalIndex + 1].id
        }
        return .handled
    }

    // Toggle expand/collapse on selected block via notification
    private func handleToggleExpand() -> KeyPress.Result {
        guard let selectedID = model.selectedCanvasBlockID else { return .ignored }
        NotificationCenter.default.post(
            name: .blockRowToggleExpand,
            object: selectedID
        )
        return .handled
    }

    private func handleToggleAllExpanded() -> KeyPress.Result {
        NotificationCenter.default.post(name: .blockRowToggleAllExpanded, object: nil)
        return .handled
    }

    private func handleCopyCompiledPrompt() -> KeyPress.Result {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.compiledTemplate, forType: .string)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showCopyToast = false }
        }
        return .handled
    }

    private func handleLayeredEsc() -> KeyPress.Result {
        if slashState.isVisible {
            slashState.hide()
            return .handled
        }
        if model.selectedCanvasBlockID != nil {
            model.selectedCanvasBlockID = nil
            return .handled
        }
        return .ignored
    }

    // MARK: - Header

    private var canvasHeader: some View {
        HStack {
            Text("Composition")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            if !model.canvasBlocks.isEmpty {
                Text("\(model.canvasBlocks.count) block\(model.canvasBlocks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Empty State

    private var emptyCanvasState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            VStack(spacing: 4) {
                Text("Start Building")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Drag blocks here or use \u{2318}/ to add")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            // Dashed drop zone
            ZStack {
                RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.35))
                    .frame(height: 80)

                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.dashed")
                        .font(.title2)
                        .foregroundStyle(.tertiary)

                    Text("Drop a block here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 32)
            .dropDestination(for: Block.self) { items, _ in
                for block in items {
                    guard ProFeature.isUnlocked(.unlimitedBlocks) || model.canvasBlocks.count < ProFeature.freeBlockLimit else {
                        paywallFeature = .unlimitedBlocks
                        showPaywall = true
                        return false
                    }
                    withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
                        model.addToCanvas(block)
                        model.selectedCanvasBlockID = model.canvasBlocks.last?.id
                    }
                }
                return !items.isEmpty
            }

            // Cmd+/ button
            Button(action: { slashState.show() }) {
                HStack(spacing: 8) {
                    Image(systemName: "command")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("/ Add block...")
                        .font(.callout)
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(AppConstants.CornerRadius.medium)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Block List

    private var blockList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Drop indicator above first block
                    dropIndicator(at: 0)

                    ForEach(Array(model.canvasBlocks.enumerated()), id: \.element.id) { index, block in
                        BlockRowView(
                            block: block,
                            index: index,
                            totalCount: model.canvasBlocks.count,
                            isSelected: model.selectedCanvasBlockID == block.id,
                            isDragging: draggedBlockID == block.id,
                            placeholderStatus: model.placeholderStatus(for: block.id),
                            inputs: model.blockInputs[block.id] ?? [:],
                            modifiers: model.modifiersForBlock(block.id),
                            modifierInputs: { modifierID in
                                model.modifierInputs[modifierID] ?? [:]
                            },
                            onSelect: {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                                    model.selectedCanvasBlockID = block.id
                                }
                            },
                            onInputChange: { placeholder, value in
                                model.setBlockInput(blockID: block.id, placeholder: placeholder, value: value)
                            },
                            onModifierInputChange: { modifierID, placeholder, value in
                                model.setModifierInput(modifierID: modifierID, placeholder: placeholder, value: value)
                            },
                            onRemove: {
                                // Focus management: select next or previous
                                let idx = model.canvasBlocks.firstIndex(where: { $0.id == block.id }) ?? 0
                                withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
                                    model.removeFromCanvas(at: IndexSet(integer: idx))
                                }
                                if !model.canvasBlocks.isEmpty {
                                    let newIdx = min(idx, model.canvasBlocks.count - 1)
                                    model.selectedCanvasBlockID = model.canvasBlocks[newIdx].id
                                }
                            },
                            onDuplicate: {
                                withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
                                    model.duplicateBlock(id: block.id)
                                }
                            },
                            onMoveUp: {
                                withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
                                    model.moveBlock(id: block.id, direction: -1)
                                }
                            },
                            onMoveDown: {
                                withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
                                    model.moveBlock(id: block.id, direction: 1)
                                }
                            },
                            onAddModifier: { modifier in
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                    model.addModifierToBlock(blockID: block.id, modifier: modifier)
                                }
                            },
                            onRemoveModifier: { modifierID in
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                    model.removeModifierFromBlock(blockID: block.id, modifierID: modifierID)
                                }
                            },
                            modifierLibrary: model.modifierLibrary,
                            pendingFirstInputFocusBlockID: model.pendingFirstInputFocusBlockID,
                            onClearPendingFocus: { model.pendingFirstInputFocusBlockID = nil }
                        )
                        .id(block.id)
                        .transition(reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                        .draggable(block) {
                            BlockDragPreview(block: block)
                        }
                        .onDrag {
                            draggedBlockID = block.id
                            return NSItemProvider()
                        }
                        // Per-row drop destination for library blocks
                        .dropDestination(for: Block.self) { items, _ in
                            for item in items {
                                guard ProFeature.isUnlocked(.unlimitedBlocks) || model.canvasBlocks.count < ProFeature.freeBlockLimit else {
                                    paywallFeature = .unlimitedBlocks
                                    showPaywall = true
                                    dropTargetIndex = nil
                                    return false
                                }
                                withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
                                    model.insertOnCanvas(item, at: index)
                                    model.selectedCanvasBlockID = model.canvasBlocks[safe: index]?.id
                                }
                            }
                            dropTargetIndex = nil
                            return !items.isEmpty
                        } isTargeted: { isTargeted in
                            dropTargetIndex = isTargeted ? index : nil
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)

                        // Drop indicator after each block
                        dropIndicator(at: index + 1)
                    }
                    .onMove { from, to in
                        withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.spring) {
                            model.moveOnCanvas(from: from, to: to)
                        }
                        draggedBlockID = nil
                    }

                    // Suggestion banner
                    if showSuggestion, let suggestion = currentSuggestion {
                        SuggestionBannerView(
                            suggestion: suggestion,
                            onSelectCategory: { category in
                                slashState.show()
                                slashState.query = category.rawValue.lowercased()
                            },
                            onDismiss: {
                                dismissedSuggestionHash = suggestion.message.hashValue
                                withAnimation(reduceMotion ? nil : .default) { showSuggestion = false }
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    // Add block hint at bottom
                    addBlockHint
                        .padding(.horizontal, 16)
                }
                .animation(reduceMotion ? nil : AppConstants.StandardAnimation.spring, value: model.canvasBlocks.count)
            }
            .onChange(of: model.canvasBlocks.count) { oldCount, newCount in
                // Auto-scroll to newly added block
                if newCount > oldCount, let lastID = model.canvasBlocks.last?.id {
                    withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.standard) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
            .onChange(of: model.selectedCanvasBlockID) { _, newID in
                // Auto-scroll to selected block
                if let id = newID {
                    withAnimation(reduceMotion ? nil : AppConstants.StandardAnimation.standard) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
            .accessibilityIdentifier("block-canvas")
        }
    }

    // MARK: - Drop Indicator

    @ViewBuilder
    private func dropIndicator(at index: Int) -> some View {
        if dropTargetIndex == index {
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 2)
                .padding(.horizontal, 16)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: dropTargetIndex)
        }
    }

    // MARK: - Block Count Warning Banner

    private var blockCountWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)

            Text("Large canvas (\(model.canvasBlocks.count) blocks) — compilation may be slower")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(1)
    }

    // MARK: - Copy Toast

    private var copyToastView: some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Prompt copied to clipboard")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.bottom, 20)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(2)
    }

    // MARK: - Add Block Hint

    private var addBlockHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.dashed")
                .font(.title3)
                .foregroundStyle(.tertiary)

            Text("Drag a block here or press \u{2318}/")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(.quaternary)
        )
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let blockRowToggleExpand = Notification.Name("blockRowToggleExpand")
    static let blockRowToggleAllExpanded = Notification.Name("blockRowToggleAllExpanded")
}

// MARK: - Safe Array Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0 && index < count else { return nil }
        return self[index]
    }
}

// MARK: - Drag Preview

private struct BlockDragPreview: View {
    let block: Block

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(block.category.color)
                .frame(width: 8, height: 8)

            Text(block.title)
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(AppConstants.CornerRadius.medium)
        .shadow(radius: 4)
    }
}

#Preview {
    let prompt = Prompt(title: "Test", content: "Test content")
    let model = PromptStudioModel(prompt: prompt)
    let slashState = SlashCommandState()
    return CompositionCanvasView(model: model, slashState: slashState)
        .frame(width: 400, height: 600)
}
