//
//  InsertVariablePopover.swift
//  Pault
//
//  A small popover that lets the user insert a {{variable}} chip
//  by picking an existing variable name or typing a new one.
//

import SwiftUI

struct InsertVariablePopover: View {
    /// Existing variable names already used in the prompt.
    let existingNames: [String]
    /// Called with the chosen variable name to insert.
    let onInsert: (String) -> Void

    @State private var newName: String = ""
    @Environment(\.dismiss) private var dismiss

    private var trimmedName: String {
        newName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Only allow word characters (letters, digits, underscores) to
    /// match the `\w+` pattern used by TemplateEngine.
    private var isValidName: Bool {
        let name = trimmedName
        return !name.isEmpty && name.range(of: #"^\w+$"#, options: .regularExpression) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insert Variable")
                .font(.headline)

            // New variable name field
            HStack(spacing: 8) {
                TextField("variable_name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
                    .onSubmit {
                        if isValidName {
                            insert(trimmedName)
                        }
                    }

                Button("Insert") {
                    insert(trimmedName)
                }
                .disabled(!isValidName)
                .keyboardShortcut(.defaultAction)
            }

            // Existing variables (quick-pick)
            if !existingNames.isEmpty {
                Divider()

                Text("Existing")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 6) {
                    ForEach(existingNames, id: \.self) { name in
                        Button(action: { insert(name) }) {
                            Text(name)
                                .font(.caption.monospaced())
                                .fontWeight(.medium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private func insert(_ name: String) {
        onInsert(name)
        dismiss()
    }
}
