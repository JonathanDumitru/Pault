//
//  CompositionCanvasView.swift
//  Pault
//
//  Central canvas displaying the ordered block composition.
//  Users drag blocks from the library, reorder them, and fill in placeholders.
//

import SwiftUI

/// Central pane showing the block stack with inputs and modifiers
struct CompositionCanvasView: View {
    @ObservedObject var model: PromptStudioModel
    @ObservedObject var slashState: SlashCommandState

    @State private var draggedBlockID: UUID?
    @FocusState private var isFocused: Bool

    // Suggestion banner state
    @State private var dismissedSuggestionHash: Int? = nil
    @State private var showSuggestion = false
    @AppStorage("showBlockSuggestions") private var suggestionsEnabled: Bool = true

    /// Current suggestion based on canvas state
    private var currentSuggestion: BlockSuggestion? {
        guard suggestionsEnabled else { return nil }

        let categories = model.canvasBlocks.map {
            ConsolidatedBlockCategory.from(legacy: $0.category)
        }

        if let suggestion = BlockSuggestionEngine.suggest(canvasCategories: categories) {
            // Don't show if user dismissed this exact suggestion
            if suggestion.message.hashValue == dismissedSuggestionHash {
                return nil
            }
            return suggestion
        }

        // Check for token warning
        return BlockSuggestionEngine.shouldShowTokenWarning(tokenCount: model.tokenEstimate)
    }

    var body: some View {
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
        .onKeyPress(.upArrow) { handleArrowKey(direction: -1) }
        .onKeyPress(.downArrow) { handleArrowKey(direction: 1) }
        .onKeyPress(.delete) { handleDelete() }
        .onKeyPress(.deleteForward) { handleDelete() }
        .dropDestination(for: Block.self) { items, location in
            for block in items {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    model.addToCanvas(block)
                }
            }
            return !items.isEmpty
        }
        .overlay {
            if slashState.isVisible {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { slashState.hide() }

                SlashCommandPaletteView(state: slashState, model: model) { block in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        model.addToCanvas(block)
                    }
                }
            }
        }
        .onKeyPress(phases: .down) { keyPress in
            // "/" key opens slash command palette
            if keyPress.characters == "/" && keyPress.modifiers.isEmpty {
                slashState.show()
                return .handled
            }
            // ⌘K also opens slash command palette
            if keyPress.characters.lowercased() == "k" && keyPress.modifiers == .command {
                slashState.show()
                return .handled
            }
            return .ignored
        }
        .onChange(of: model.canvasBlocks.count) { oldCount, newCount in
            if newCount > oldCount {
                // Delay showing suggestion after adding a block
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if currentSuggestion != nil {
                        withAnimation { showSuggestion = true }
                    }
                }
            }
        }
    }

    // MARK: - Keyboard Navigation

    private func handleArrowKey(direction: Int) -> KeyPress.Result {
        guard !model.canvasBlocks.isEmpty else { return .ignored }

        if let selectedID = model.selectedCanvasBlockID,
           let currentIndex = model.canvasBlocks.firstIndex(where: { $0.id == selectedID }) {
            let newIndex = max(0, min(model.canvasBlocks.count - 1, currentIndex + direction))
            withAnimation(.easeInOut(duration: 0.15)) {
                model.selectedCanvasBlockID = model.canvasBlocks[newIndex].id
            }
        } else {
            // No selection, select first or last based on direction
            let block = direction > 0 ? model.canvasBlocks.first : model.canvasBlocks.last
            withAnimation(.easeInOut(duration: 0.15)) {
                model.selectedCanvasBlockID = block?.id
            }
        }
        return .handled
    }

    private func handleDelete() -> KeyPress.Result {
        guard let selectedID = model.selectedCanvasBlockID,
              let index = model.canvasBlocks.firstIndex(where: { $0.id == selectedID }) else {
            return .ignored
        }

        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            model.removeFromCanvas(at: IndexSet(integer: index))
        }

        // Select next block after deletion
        if !model.canvasBlocks.isEmpty {
            let newIndex = min(index, model.canvasBlocks.count - 1)
            model.selectedCanvasBlockID = model.canvasBlocks[newIndex].id
        }
        return .handled
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

                Text("Type / to search blocks or press \u{2318}K")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            // Slash trigger area
            Button(action: { slashState.show() }) {
                HStack(spacing: 8) {
                    Text("/")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    Text("Add block...")
                        .font(.callout)
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Block List

    private var blockList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(model.canvasBlocks.enumerated()), id: \.element.id) { index, block in
                    BlockRowView(
                        block: block,
                        index: index,
                        isSelected: model.selectedCanvasBlockID == block.id,
                        placeholderStatus: model.placeholderStatus(for: block.id),
                        inputs: model.blockInputs[block.id] ?? [:],
                        modifiers: model.modifiersForBlock(block.id),
                        modifierInputs: { modifierID in
                            model.modifierInputs[modifierID] ?? [:]
                        },
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.15)) {
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
                            if let idx = model.canvasBlocks.firstIndex(where: { $0.id == block.id }) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    model.removeFromCanvas(at: IndexSet(integer: idx))
                                }
                            }
                        },
                        onAddModifier: { modifier in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                model.addModifierToBlock(blockID: block.id, modifier: modifier)
                            }
                        },
                        onRemoveModifier: { modifierID in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                model.removeModifierFromBlock(blockID: block.id, modifierID: modifierID)
                            }
                        },
                        modifierLibrary: model.modifierLibrary
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                    .draggable(block) {
                        BlockDragPreview(block: block)
                    }
                }
                .onMove { from, to in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        model.moveOnCanvas(from: from, to: to)
                    }
                }

                // Suggestion banner
                if showSuggestion, let suggestion = currentSuggestion {
                    SuggestionBannerView(
                        suggestion: suggestion,
                        onSelectCategory: { category in
                            // Show slash palette filtered to this category
                            slashState.show()
                            slashState.query = category.rawValue.lowercased()
                        },
                        onDismiss: {
                            dismissedSuggestionHash = suggestion.message.hashValue
                            withAnimation { showSuggestion = false }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 8)
                }

                // Add block hint at bottom
                addBlockHint
            }
            .padding(16)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.canvasBlocks.count)
        }
    }

    // MARK: - Add Block Hint

    private var addBlockHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.dashed")
                .font(.title3)
                .foregroundStyle(.tertiary)

            Text("Drag a block here or double-click in the library")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(.quaternary)
        )
        .padding(.top, 8)
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
        .cornerRadius(8)
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
