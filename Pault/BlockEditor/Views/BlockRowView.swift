//
//  BlockRowView.swift
//  Pault
//
//  Individual block in the composition canvas with inputs and modifiers.
//

import SwiftUI

/// A single block in the canvas with its placeholder inputs and modifiers
struct BlockRowView: View {
    let block: Block
    let index: Int
    let isSelected: Bool
    let inputs: [String: String]
    let modifiers: [BlockModifier]
    let modifierInputs: (UUID) -> [String: String]
    let onSelect: () -> Void
    let onInputChange: (String, String) -> Void
    let onModifierInputChange: (UUID, String, String) -> Void
    let onRemove: () -> Void
    let onAddModifier: (BlockModifier) -> Void
    let onRemoveModifier: (UUID) -> Void
    let modifierLibrary: [ModifierCategory: [BlockModifier]]

    @State private var isExpanded = true
    @State private var showModifierPicker = false
    @State private var isHovered = false

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
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? block.category.color : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(color: .black.opacity(isHovered ? 0.1 : 0.05), radius: isHovered ? 4 : 2)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }

    // MARK: - Block Header

    private var blockHeader: some View {
        HStack(spacing: 8) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Category indicator
            Circle()
                .fill(block.category.color)
                .frame(width: 10, height: 10)

            // Block title
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

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

            // Remove button
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
        isSelected: true,
        inputs: ["goal": "Test goal", "priority": "High"],
        modifiers: [],
        modifierInputs: { _ in [:] },
        onSelect: {},
        onInputChange: { _, _ in },
        onModifierInputChange: { _, _, _ in },
        onRemove: {},
        onAddModifier: { _ in },
        onRemoveModifier: { _ in },
        modifierLibrary: [:]
    )
    .padding()
    .frame(width: 400)
}
