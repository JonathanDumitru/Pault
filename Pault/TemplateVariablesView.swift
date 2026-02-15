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

    var body: some View {
        if hasVariables {
            VStack(alignment: .leading, spacing: 12) {
                Divider()

                // Header
                HStack {
                    Label("Variables", systemImage: "curlybraces")
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
                    }
                }

                // Variable fields
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    ForEach(sortedVariables) { variable in
                        GridRow {
                            Text(variable.name)
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 80, alignment: .trailing)
                                .padding(.top, 6)

                            ExpandingTextEditor(
                                text: Binding(
                                    get: { variable.defaultValue },
                                    set: { newValue in
                                        variable.defaultValue = newValue
                                        debouncedSave()
                                    }
                                ),
                                placeholder: "Enter \(variable.name)...",
                                onTab: { advanceFocus(from: variable) },
                                onBackTab: { retreatFocus(from: variable) },
                                isFocused: focusedVariableID == variable.id
                            )
                            .frame(minHeight: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }

                // Preview
                if anyFilled {
                    Divider()

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
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
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
