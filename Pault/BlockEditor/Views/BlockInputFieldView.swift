//
//  BlockInputFieldView.swift
//  Pault
//
//  Input field for block placeholders with validation feedback.
//

import SwiftUI

/// Input field for a single placeholder in a block
struct BlockInputFieldView: View {
    let placeholder: String
    let value: String
    let onChange: (String) -> Void
    var isCompact: Bool = false

    @State private var localValue: String = ""
    @FocusState private var isFocused: Bool

    private var displayName: String {
        placeholder
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private var isEmpty: Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Label
            HStack(spacing: 4) {
                Text(displayName)
                    .font(isCompact ? .caption2 : .caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                if isEmpty {
                    Text("(required)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            // Input field
            if isMultiline {
                TextEditor(text: $localValue)
                    .font(isCompact ? .caption : .callout)
                    .frame(minHeight: isCompact ? 40 : 60, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                isFocused ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: 1
                            )
                    )
                    .focused($isFocused)
                    .onChange(of: localValue) { _, newValue in
                        onChange(newValue)
                    }
            } else {
                TextField("Enter \(displayName.lowercased())...", text: $localValue)
                    .font(isCompact ? .caption : .callout)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                isFocused ? Color.accentColor : Color(nsColor: .separatorColor),
                                lineWidth: 1
                            )
                    )
                    .focused($isFocused)
                    .onChange(of: localValue) { _, newValue in
                        onChange(newValue)
                    }
            }
        }
        .onAppear {
            localValue = value
        }
        .onChange(of: value) { _, newValue in
            if localValue != newValue {
                localValue = newValue
            }
        }
    }

    /// Determine if the field should be multiline based on placeholder name
    private var isMultiline: Bool {
        let multilineHints = ["body", "content", "text", "description", "notes", "instructions", "context", "criteria", "constraints", "rules"]
        let lowerPlaceholder = placeholder.lowercased()
        return multilineHints.contains { lowerPlaceholder.contains($0) }
    }
}

#Preview {
    VStack(spacing: 20) {
        BlockInputFieldView(
            placeholder: "goal",
            value: "Test goal",
            onChange: { _ in }
        )

        BlockInputFieldView(
            placeholder: "description",
            value: "",
            onChange: { _ in }
        )

        BlockInputFieldView(
            placeholder: "priority",
            value: "High",
            onChange: { _ in },
            isCompact: true
        )
    }
    .padding()
    .frame(width: 300)
}
