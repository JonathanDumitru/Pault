//
//  BlockRowView.swift
//  Pault
//
//  Individual block in the composition canvas with inputs and modifiers.
//
//  Features (02-02):
//  - Lift effect (scale + elevated shadow) when isDragging
//  - Grab cursor on drag handle via onContinuousHover
//  - Dimmed drag handle when single block (totalCount == 1)
//  - Right-click context menu: Duplicate, Delete, Move Up/Down, Expand/Collapse, Copy
//  - Long titles truncated with .help() tooltip
//  - Responds to .blockRowToggleExpand and .blockRowToggleAllExpanded notifications
//

import SwiftUI
import AppKit

/// A single block in the canvas with its placeholder inputs and modifiers
struct BlockRowView: View {
    let block: Block
    let index: Int
    let totalCount: Int
    let isSelected: Bool
    let isDragging: Bool
    let placeholderStatus: BlockPlaceholderStatus
    let inputs: [String: String]
    let modifiers: [BlockModifier]
    let modifierInputs: (UUID) -> [String: String]
    let onSelect: () -> Void
    let onInputChange: (String, String) -> Void
    let onModifierInputChange: (UUID, String, String) -> Void
    let onRemove: () -> Void
    let onDuplicate: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onAddModifier: (BlockModifier) -> Void
    let onRemoveModifier: (UUID) -> Void
    let modifierLibrary: [ModifierCategory: [BlockModifier]]

    @State private var isExpanded = true
    @State private var showModifierPicker = false
    @State private var isHovered = false
    @State private var isDragHandleHovered = false

    private var placeholders: [String] {
        PromptStudioModel.placeholders(in: block.snippet)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Block header
            blockHeader

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Placeholder inputs
                    if !placeholders.isEmpty {
                        inputFields
                    }

                    // Modifiers section
                    modifiersSection
                }
                .padding(12)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium)
                .strokeBorder(
                    isSelected ? block.category.color : Color.clear,
                    lineWidth: 2
                )
        )
        // Lift effect when dragging
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .shadow(
            color: isDragging
                ? Color.black.opacity(AppConstants.Shadow.elevated.colorOpacity)
                : Color.black.opacity(isHovered ? AppConstants.Shadow.medium.colorOpacity : AppConstants.Shadow.subtle.colorOpacity),
            radius: isDragging
                ? AppConstants.Shadow.elevated.radius
                : (isHovered ? AppConstants.Shadow.medium.radius : AppConstants.Shadow.subtle.radius),
            x: 0,
            y: isDragging ? AppConstants.Shadow.elevated.y : (isHovered ? AppConstants.Shadow.medium.y : AppConstants.Shadow.subtle.y)
        )
        .opacity(isDragging ? 0.85 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        // Right-click context menu
        .contextMenu {
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            Divider()
            Button(action: onMoveUp) {
                Label("Move Up", systemImage: "arrow.up")
            }
            .disabled(index == 0)
            Button(action: onMoveDown) {
                Label("Move Down", systemImage: "arrow.down")
            }
            .disabled(index == totalCount - 1)
            Divider()
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }) {
                Label(isExpanded ? "Collapse" : "Expand", systemImage: isExpanded ? "chevron.up.square" : "chevron.down.square")
            }
            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(block.snippet, forType: .string)
            }) {
                Label("Copy Block Content", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("Delete", systemImage: "trash")
            }
        }
        // Listen for keyboard-triggered toggle expand (from CompositionCanvasView)
        .onReceive(NotificationCenter.default.publisher(for: .blockRowToggleExpand)) { notification in
            if let id = notification.object as? UUID, id == block.id {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .blockRowToggleAllExpanded)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        }
    }

    // MARK: - Block Header

    private var blockHeader: some View {
        HStack(spacing: 8) {
            // Drag handle — dimmed when only one block
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(totalCount == 1 ? 0.2 : 0.6))
                .onContinuousHover { phase in
                    switch phase {
                    case .active:
                        isDragHandleHovered = true
                        NSCursor.openHand.push()
                    case .ended:
                        isDragHandleHovered = false
                        NSCursor.pop()
                    }
                }

            // Status indicator
            Circle()
                .fill(placeholderStatus.color)
                .frame(width: 10, height: 10)
                .overlay(
                    Image(systemName: placeholderStatus.icon)
                        .font(.system(size: 6))
                        .foregroundStyle(.white)
                )

            // Block title (truncated with tooltip on hover)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .help(block.title)

                Text(block.category.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Index badge
            Text("#\(index + 1)")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(nsColor: .separatorColor).opacity(0.3))
                .clipShape(Capsule())

            // Expand/collapse
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            // Remove button (visible on hover)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(12)
        .background(block.category.color.opacity(0.08))
    }

    // MARK: - Input Fields

    private var inputFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(placeholders, id: \.self) { placeholder in
                BlockInputFieldView(
                    placeholder: placeholder,
                    value: inputs[placeholder] ?? "",
                    onChange: { newValue in
                        onInputChange(placeholder, newValue)
                    }
                )
            }
        }
    }

    // MARK: - Modifiers Section

    private var modifiersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Existing modifiers
            if !modifiers.isEmpty {
                ForEach(modifiers) { modifier in
                    ModifierRowView(
                        modifier: modifier,
                        inputs: modifierInputs(modifier.id),
                        onInputChange: { placeholder, value in
                            onModifierInputChange(modifier.id, placeholder, value)
                        },
                        onRemove: { onRemoveModifier(modifier.id) }
                    )
                }
            }

            // Add modifier button
            Button(action: { showModifierPicker = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                    Text("Add Modifier")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showModifierPicker) {
                ModifierPickerView(
                    library: modifierLibrary,
                    onSelect: { modifier in
                        onAddModifier(modifier)
                        showModifierPicker = false
                    }
                )
            }
        }
    }
}

// MARK: - Modifier Row View

private struct ModifierRowView: View {
    let modifier: BlockModifier
    let inputs: [String: String]
    let onInputChange: (String, String) -> Void
    let onRemove: () -> Void

    @State private var isExpanded = true
    @State private var isHovered = false

    private var placeholders: [String] {
        PromptStudioModel.placeholders(in: modifier.snippet)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "plus.square")
                    .font(.caption2)
                    .foregroundStyle(modifier.category.color)

                Text(modifier.name)
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                if !placeholders.isEmpty {
                    Button(action: { withAnimation { isExpanded.toggle() } }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0)
            }

            if isExpanded && !placeholders.isEmpty {
                ForEach(placeholders, id: \.self) { placeholder in
                    BlockInputFieldView(
                        placeholder: placeholder,
                        value: inputs[placeholder] ?? "",
                        onChange: { onInputChange(placeholder, $0) },
                        isCompact: true
                    )
                }
            }
        }
        .padding(8)
        .background(modifier.category.color.opacity(0.05))
        .cornerRadius(6)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Modifier Picker

private struct ModifierPickerView: View {
    let library: [ModifierCategory: [BlockModifier]]
    let onSelect: (BlockModifier) -> Void

    @State private var searchQuery = ""

    private var filteredModifiers: [(ModifierCategory, [BlockModifier])] {
        ModifierCategory.allCases.compactMap { category in
            guard let modifiers = library[category], !modifiers.isEmpty else { return nil }

            if searchQuery.isEmpty {
                return (category, modifiers)
            }

            let filtered = modifiers.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
            return filtered.isEmpty ? nil : (category, filtered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search
            TextField("Search modifiers...", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .padding(8)

            Divider()

            // List
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredModifiers, id: \.0) { category, modifiers in
                        Section {
                            ForEach(modifiers) { modifier in
                                Button(action: { onSelect(modifier) }) {
                                    HStack {
                                        Text(modifier.name)
                                            .font(.callout)
                                        Spacer()
                                        if !modifier.description.isEmpty {
                                            Text(modifier.description)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(category.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(category.color)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .frame(width: 280, height: 320)
    }
}

#Preview {
    let block = Block(
        title: "Objective",
        category: .intent,
        valueType: .object,
        snippet: "OBJECTIVE: {{goal}}\nPriority: {{priority}}"
    )
    return BlockRowView(
        block: block,
        index: 0,
        totalCount: 3,
        isSelected: true,
        isDragging: false,
        placeholderStatus: .complete,
        inputs: ["goal": "Test goal", "priority": "High"],
        modifiers: [],
        modifierInputs: { _ in [:] },
        onSelect: {},
        onInputChange: { _, _ in },
        onModifierInputChange: { _, _, _ in },
        onRemove: {},
        onDuplicate: {},
        onMoveUp: {},
        onMoveDown: {},
        onAddModifier: { _ in },
        onRemoveModifier: { _ in },
        modifierLibrary: [:]
    )
    .padding()
    .frame(width: 400)
}
