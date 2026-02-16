//
//  InlineVariablePreview.swift
//  Pault
//
//  Renders prompt content with editable inline TextFields at {{variable}}
//  positions. Each occurrence gets its own independent TemplateVariable,
//  resolved by global position across all paragraphs.
//

import SwiftUI
import SwiftData
import os

private let inlineLogger = Logger(subsystem: "com.pault.app", category: "InlineVariablePreview")

struct InlineVariablePreview: View {
    @Environment(\.modelContext) private var modelContext
    let prompt: Prompt

    @State private var saveTask: Task<Void, Never>?

    /// Variables sorted by their global position in the content.
    private var sortedVariables: [TemplateVariable] {
        prompt.templateVariables.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Each paragraph's segments, paired with a starting variable index
    /// so that each `.variable` segment maps to the correct TemplateVariable.
    private var paragraphData: [(segments: [TemplateEngine.ContentSegment], variableStartIndex: Int)] {
        let lines = prompt.content.components(separatedBy: "\n")
        var globalVarIndex = 0
        return lines.map { line in
            let segments = TemplateEngine.splitContent(line)
            let startIndex = globalVarIndex
            let varCount = segments.filter {
                if case .variable = $0 { return true } else { return false }
            }.count
            globalVarIndex += varCount
            return (segments: segments, variableStartIndex: startIndex)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(paragraphData.enumerated()), id: \.offset) { _, data in
                    InlineParagraphView(
                        segments: data.segments,
                        sortedVariables: sortedVariables,
                        variableStartIndex: data.variableStartIndex,
                        onValueChanged: debouncedSave
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Persistence

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
                    inlineLogger.error("debouncedSave: Failed to save — \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Paragraph View

private struct InlineParagraphView: View {
    let segments: [TemplateEngine.ContentSegment]
    let sortedVariables: [TemplateVariable]
    let variableStartIndex: Int
    let onValueChanged: () -> Void

    private var hasVariables: Bool {
        segments.contains { if case .variable = $0 { return true } else { return false } }
    }

    private var isBlankLine: Bool {
        segments.isEmpty || (segments.count == 1 && segments[0] == .text(""))
    }

    var body: some View {
        if isBlankLine {
            Text(" ")
                .frame(height: 8)
        } else if !hasVariables {
            // Pure text paragraph — simple Text view with selection
            let fullText = segments.compactMap { segment -> String? in
                if case .text(let t) = segment { return t }
                return nil
            }.joined()
            Text(fullText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Mixed paragraph — FlowLayout with text and inline fields
            // Track which variable we're on within this paragraph
            let indexedSegments = buildIndexedSegments()
            FlowLayout(spacing: 0) {
                ForEach(Array(indexedSegments.enumerated()), id: \.offset) { _, item in
                    switch item {
                    case .text(let text):
                        Text(text)
                            .font(.body)
                    case .field(let variable):
                        InlineVariableField(
                            variable: variable,
                            onValueChanged: onValueChanged
                        )
                    case .unresolved(let name):
                        Text("{{\(name)}}")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Pairs each `.variable` segment with its positional TemplateVariable.
    private func buildIndexedSegments() -> [IndexedSegment] {
        var localVarIndex = 0
        return segments.map { segment in
            switch segment {
            case .text(let text):
                return .text(text)
            case .variable(let name):
                let globalIndex = variableStartIndex + localVarIndex
                localVarIndex += 1
                if globalIndex < sortedVariables.count {
                    return .field(sortedVariables[globalIndex])
                } else {
                    return .unresolved(name)
                }
            }
        }
    }
}

/// Pre-resolved segment with either literal text, a bound variable, or an unresolved placeholder.
private enum IndexedSegment {
    case text(String)
    case field(TemplateVariable)
    case unresolved(String)
}

// MARK: - Inline Variable Field

private struct InlineVariableField: View {
    @Bindable var variable: TemplateVariable
    let onValueChanged: () -> Void

    private var estimatedWidth: CGFloat {
        let charCount = max(variable.defaultValue.count, variable.name.count, 6)
        return CGFloat(charCount) * 8 + 24
    }

    var body: some View {
        TextField(variable.name, text: $variable.defaultValue)
            .font(.body.monospaced())
            .textFieldStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .frame(minWidth: 80, idealWidth: estimatedWidth)
            .background(Color.accentColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .lineLimit(1...3)
            .accessibilityLabel("\(variable.name): \(variable.defaultValue.isEmpty ? "empty" : variable.defaultValue)")
            .onChange(of: variable.defaultValue) {
                onValueChanged()
            }
    }
}
