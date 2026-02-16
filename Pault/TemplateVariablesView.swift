//
//  TemplateVariablesView.swift
//  Pault
//
//  Displays editable fields for each {{variable}} found in a prompt's content,
//  along with a live preview of the resolved output.
//

import SwiftUI
import SwiftData
import os

private let variablesLogger = Logger(subsystem: "com.pault.app", category: "TemplateVariablesView")

struct TemplateVariablesView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: Prompt
    @State private var focusedVariableID: UUID?

    private var sortedVariables: [TemplateVariable] {
        prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var hasVariables: Bool {
        !prompt.templateVariables.isEmpty
    }

    private var resolvedContent: String {
        TemplateEngine.resolve(content: prompt.content, variables: prompt.templateVariables)
    }

    private var allFilled: Bool {
        prompt.templateVariables.allSatisfy { !$0.defaultValue.isEmpty }
    }

    private var anyFilled: Bool {
        prompt.templateVariables.contains { !$0.defaultValue.isEmpty }
    }

    private var filledCount: Int {
        prompt.templateVariables.filter { !$0.defaultValue.isEmpty }.count
    }

    /// Names that appear more than once, so we know when to add occurrence labels.
    private var duplicatedNames: Set<String> {
        var counts: [String: Int] = [:]
        for v in prompt.templateVariables { counts[v.name, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    /// Display label for a variable: "name" if unique, "name [1]" / "name [2]" if duplicated.
    private func displayLabel(for variable: TemplateVariable) -> String {
        if duplicatedNames.contains(variable.name) {
            return "\(variable.name) [\(variable.occurrenceIndex + 1)]"
        }
        return variable.name
    }

    var body: some View {
        if hasVariables {
            VStack(alignment: .leading, spacing: 12) {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    // Header with filled count
                    HStack {
                        Label(
                            "Variables (\(filledCount)/\(prompt.templateVariables.count))",
                            systemImage: "curlybraces"
                        )
                        .font(.headline)
                        .foregroundStyle(.secondary)

                        Spacer()

                        if anyFilled {
                            Button("Clear") {
                                clearAllValues()
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Clear all variable values")
                        }
                    }

                    // Variable fields
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        ForEach(sortedVariables) { variable in
                            GridRow {
                                Text(displayLabel(for: variable))
                                    .font(.caption.monospaced())
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                                    .frame(minWidth: 80, alignment: .trailing)
                                    .padding(.top, 6)
                                    .accessibilityLabel("Variable: \(displayLabel(for: variable))")

                                ExpandingTextEditor(
                                    text: Binding(
                                        get: { variable.defaultValue },
                                        set: { newValue in
                                            variable.defaultValue = newValue
                                            debouncedSave()
                                        }
                                    ),
                                    placeholder: "Enter \(displayLabel(for: variable))...",
                                    onTab: { advanceFocus(from: variable) },
                                    onBackTab: { retreatFocus(from: variable) },
                                    isFocused: focusedVariableID == variable.id
                                )
                                .frame(minHeight: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Preview
                if anyFilled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(resolvedContent)
                            .font(.body)
                            .foregroundStyle(.primary.opacity(0.8))
                            .textSelection(.enabled)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Tab navigation

    private func advanceFocus(from current: TemplateVariable) {
        let sorted = sortedVariables
        guard let idx = sorted.firstIndex(where: { $0.id == current.id }) else {
            focusedVariableID = sorted.first?.id
            return
        }
        let nextIdx = sorted.index(after: idx)
        focusedVariableID = nextIdx < sorted.endIndex ? sorted[nextIdx].id : sorted.first?.id
    }

    private func retreatFocus(from current: TemplateVariable) {
        let sorted = sortedVariables
        guard let idx = sorted.firstIndex(where: { $0.id == current.id }) else {
            focusedVariableID = sorted.last?.id
            return
        }
        if idx > sorted.startIndex {
            focusedVariableID = sorted[sorted.index(before: idx)].id
        } else {
            focusedVariableID = sorted.last?.id
        }
    }

    // MARK: - Persistence

    @State private var saveTask: Task<Void, Never>?

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                prompt.updatedAt = Date()
                do {
                    try modelContext.save()
                } catch {
                    variablesLogger.error("debouncedSave: Failed to save — \(error.localizedDescription)")
                }
            }
        }
    }

    private func clearAllValues() {
        for variable in prompt.templateVariables {
            variable.defaultValue = ""
        }
        prompt.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            variablesLogger.error("clearAllValues: Failed to save — \(error.localizedDescription)")
        }
    }
}
