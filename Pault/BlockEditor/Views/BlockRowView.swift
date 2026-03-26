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
//  Features (02-03):
//  - VoiceOver accessibilityLabel with category and position
//  - VoiceOver custom actions: Move Up, Move Down, Delete, Duplicate, Expand/Collapse
//  - Visible focus ring (2pt system accent color) on selected block
//  - Reduce Motion: spring animations replaced with instant transitions
//  - Differentiate Without Color: SF Symbol icons shown alongside status colors
//  - High contrast mode: increased color opacity and thicker borders
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
    let pendingFirstInputFocusBlockID: UUID?
    let onClearPendingFocus: () -> Void

    @State private var isExpanded = true
    @State private var showModifierPicker = false
    @State private var isHovered = false
    @State private var isDragHandleHovered = false
    @State private var shouldFocusFirstInput: Bool = false

    // Accessibility environments
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private var placeholders: [String] {
        PromptStudioModel.placeholders(in: block.snippet)
    }

    /// Animation to use based on Reduce Motion preference
    private var expandCollapseAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    /// Scale effect for drag — disabled under Reduce Motion
    private var dragScale: CGFloat {
        reduceMotion ? 1.0 : (isDragging ? 1.03 : 1.0)
    }

    /// Opacity for dragging — same regardless of motion
    private var dragOpacity: Double {
        isDragging ? 0.85 : 1.0
    }

    /// Border line width based on contrast
    private var selectedBorderWidth: CGFloat {
        colorSchemeContrast == .increased ? 3 : 2
    }

    /// Shadow color opacity adjusted for high contrast
    private var shadowOpacity: Double {
        colorSchemeContrast == .increased ? 0.25 : 1.0
    }

    private var currentShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        if isDragging {
            return (
                Color.black.opacity(AppConstants.Shadow.elevated.colorOpacity * shadowOpacity),
                AppConstants.Shadow.elevated.radius,
                AppConstants.Shadow.elevated.y
            )
        } else if isHovered {
            return (
                Color.black.opacity(AppConstants.Shadow.medium.colorOpacity * shadowOpacity),
                AppConstants.Shadow.medium.radius,
                AppConstants.Shadow.medium.y
            )
        } else {
            return (
                Color.black.opacity(AppConstants.Shadow.subtle.colorOpacity * shadowOpacity),
                AppConstants.Shadow.subtle.radius,
                AppConstants.Shadow.subtle.y
            )
        }
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
        // Selected border: 2pt system accent color (not a glow)
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.CornerRadius.medium)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: isSelected ? selectedBorderWidth : 0
                )
        )
        // Lift effect when dragging (disabled under Reduce Motion)
        .scaleEffect(dragScale)
        .shadow(
            color: currentShadow.color,
            radius: currentShadow.radius,
            x: 0,
            y: currentShadow.y
        )
        .opacity(dragOpacity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isDragging)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        // Accessibility: label with category and position
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(block.category.rawValue) block: \(block.title), position \(index + 1) of \(totalCount)")
        // Accessibility: custom actions for VoiceOver navigation
        .accessibilityAction(named: "Move Up") {
            guard index > 0 else { return }
            onMoveUp()
        }
        .accessibilityAction(named: "Move Down") {
            guard index < totalCount - 1 else { return }
            onMoveDown()
        }
        .accessibilityAction(named: "Delete") {
            onRemove()
        }
        .accessibilityAction(named: "Duplicate") {
            onDuplicate()
        }
        .accessibilityAction(named: isExpanded ? "Collapse" : "Expand") {
            withAnimation(expandCollapseAnimation) { isExpanded.toggle() }
        }
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
                withAnimation(expandCollapseAnimation) { isExpanded.toggle() }
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
                withAnimation(expandCollapseAnimation) { isExpanded.toggle() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .blockRowToggleAllExpanded)) { _ in
            withAnimation(expandCollapseAnimation) { isExpanded.toggle() }
        }
        // Drive focus into first input field after slash palette or library insert
        .onChange(of: pendingFirstInputFocusBlockID) { _, newID in
            guard newID == block.id, isExpanded, !placeholders.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                shouldFocusFirstInput = true
                onClearPendingFocus()
            }
        }
    }

    // MARK: - Block Header

    private var blockHeader: some View {
        HStack(spacing: 8) {
            // Drag handle — dimmed when only one block
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(Color.secondary.opacity(totalCount == 1 ? 0.2 : 0.6))
                .accessibilityHidden(true)
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

            // Status indicator with icon support for Differentiate Without Color
            statusIndicator

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
                .accessibilityHidden(true)

            // Expand/collapse
            Button(action: { withAnimation(expandCollapseAnimation) { isExpanded.toggle() } }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true) // Exposed via accessibilityAction on the row instead

            // Remove button (visible on hover)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
            .accessibilityHidden(true) // Exposed via accessibilityAction on the row instead
        }
        .padding(12)
        .background(
            block.category.color.opacity(
                colorSchemeContrast == .increased ? 0.15 : 0.08
            )
        )
    }

    // MARK: - Status Indicator

    /// Status indicator that shows icon alongside color.
    /// When differentiateWithoutColor is on, icon is always prominently shown.
    /// Otherwise, icon is shown subtly alongside color.
    @ViewBuilder
    private var statusIndicator: some View {
        let showIcon = differentiateWithoutColor || true // Always show icon (subtle when not needed)
        let iconOpacity: Double = differentiateWithoutColor ? 1.0 : 0.7

        ZStack {
            Circle()
                .fill(placeholderStatus.statusColor(highContrast: colorSchemeContrast == .increased))
                .frame(width: 16, height: 16)

            if showIcon {
                Image(systemName: placeholderStatus.accessibilityIcon)
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
                    .opacity(iconOpacity)
            }
        }
        .accessibilityLabel(placeholderStatus.accessibilityDescription)
    }

    // MARK: - Input Fields

    private var inputFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(placeholders.enumerated()), id: \.element) { idx, placeholder in
                BlockInputFieldView(
                    placeholder: placeholder,
                    value: inputs[placeholder] ?? "",
                    onChange: { newValue in
                        onInputChange(placeholder, newValue)
                    },
                    shouldFocus: idx == 0 ? $shouldFocusFirstInput : .constant(false)
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

// MARK: - BlockPlaceholderStatus Accessibility Extensions

extension BlockPlaceholderStatus {
    /// Icon used when Differentiate Without Color is enabled (distinct shapes per state)
    var accessibilityIcon: String {
        switch self {
        case .unfilled:  return "xmark.circle.fill"
        case .partial:   return "exclamationmark.triangle.fill"
        case .complete:  return "checkmark.circle.fill"
        }
    }

    /// Accessible description of this status
    var accessibilityDescription: String {
        switch self {
        case .unfilled:  return "Unfilled placeholders"
        case .partial:   return "Partially filled placeholders"
        case .complete:  return "All placeholders filled"
        }
    }

    /// Color adjusted for high contrast mode
    func statusColor(highContrast: Bool) -> Color {
        let opacity: Double = highContrast ? 1.0 : 0.9
        switch self {
        case .unfilled:  return Color.red.opacity(opacity)
        case .partial:   return Color.yellow.opacity(opacity)
        case .complete:  return Color.green.opacity(opacity)
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                    Button(action: {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    }) {
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
                                .accessibilityLabel("Add \(modifier.name) modifier")
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
        modifierLibrary: [:],
        pendingFirstInputFocusBlockID: nil,
        onClearPendingFocus: {}
    )
    .padding()
    .frame(width: 400)
}
