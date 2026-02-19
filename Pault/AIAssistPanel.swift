import SwiftUI
import SwiftData

struct AIAssistPanel: View {
    @Bindable var prompt: Prompt
    let config: AIConfig

    enum AssistTab: String, CaseIterable {
        case improve = "Improve"
        case variables = "Variables"
        case tags = "Tags"
        case score = "Score"
        case refine = "Refine"
    }

    @State private var selectedTab: AssistTab = .improve
    @State private var improvedText: String = ""
    @State private var isImproving: Bool = false
    @State private var instruction: String = ""
    @State private var improveError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(AssistTab.allCases, id: \.self) { tab in
                        Button(tab.rawValue) { selectedTab = tab }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedTab == tab ? Color.accentColor.opacity(0.1) : .clear)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                }
            }
            .frame(height: 32)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .improve:
                    improveTabContent
                case .variables:
                    VariablesTabContent(prompt: prompt, config: config)
                case .tags:
                    TagsTabContent(prompt: prompt, config: config)
                case .score:
                    ScoreTabContent(prompt: prompt, config: config)
                case .refine:
                    RefinementLoopView(prompt: prompt, config: config)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 220)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var improveTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Instruction (e.g. Add chain-of-thought)", text: $instruction)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            HStack {
                Button(action: runImprove) {
                    if isImproving { ProgressView().controlSize(.small) }
                    else { Label("Improve", systemImage: "wand.and.sparkles") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImproving)

                if !improvedText.isEmpty {
                    Button("Accept") {
                        prompt.content = improvedText
                        improvedText = ""
                        instruction = ""
                    }
                    .buttonStyle(.bordered)

                    Button("Reject") {
                        improvedText = ""
                        instruction = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            if let err = improveError {
                AIErrorBar(message: err) { improveError = nil }
            }
            if !improvedText.isEmpty {
                Text(improvedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .padding(8)
                    .background(Color.green.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(10)
    }

    private func runImprove() {
        isImproving = true
        improveError = nil
        let currentContent = prompt.content
        Task {
            do {
                let result = try await AIService.shared.improve(prompt: currentContent, config: config)
                await MainActor.run { improvedText = result; isImproving = false }
            } catch {
                await MainActor.run { isImproving = false; improveError = error.localizedDescription }
            }
        }
    }
}

// MARK: - Variables Tab

private struct VariablesTabContent: View {
    @Bindable var prompt: Prompt
    let config: AIConfig

    @State private var suggestions: [VariableSuggestion] = []
    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: load) {
                    if isLoading { ProgressView().controlSize(.small) }
                    else { Label("Suggest Variables", systemImage: "curlybraces") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)

                if !suggestions.isEmpty {
                    Button("Insert All") { insertAll() }
                        .buttonStyle(.bordered)
                }
            }

            if let err = error {
                AIErrorBar(message: err) { error = nil }
            }

            if !suggestions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(suggestions, id: \.placeholder) { suggestion in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.placeholder)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(suggestion.description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Insert") { insert(suggestion) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
        }
        .padding(10)
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                let result = try await AIService.shared.suggestVariables(prompt: prompt.content, config: config)
                await MainActor.run { suggestions = result; isLoading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            }
        }
    }

    private func insert(_ suggestion: VariableSuggestion) {
        // Strip wrapping {{ }} if already present, then re-wrap consistently
        let raw = suggestion.placeholder
            .replacingOccurrences(of: "{{", with: "")
            .replacingOccurrences(of: "}}", with: "")
            .trimmingCharacters(in: .whitespaces)
        let token = "{{\(raw)}}"
        if !prompt.content.contains(token) {
            prompt.content += " \(token)"
        }
    }

    private func insertAll() {
        for suggestion in suggestions { insert(suggestion) }
    }
}

// MARK: - Tags Tab

private struct TagsTabContent: View {
    @Bindable var prompt: Prompt
    let config: AIConfig

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Tag.name)]) private var allTags: [Tag]

    @State private var suggestions: [String] = []
    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: load) {
                if isLoading { ProgressView().controlSize(.small) }
                else { Label("Suggest Tags", systemImage: "tag") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            if let err = error {
                AIErrorBar(message: err) { error = nil }
            }

            if !suggestions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { name in
                        let attached = prompt.tags.contains(where: { $0.name.lowercased() == name.lowercased() })
                        Button(name) { attachTag(named: name) }
                            .buttonStyle(.bordered)
                            .foregroundStyle(attached ? .secondary : .primary)
                            .disabled(attached)
                    }
                }
            }
        }
        .padding(10)
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                let result = try await AIService.shared.autoTag(prompt: prompt.content, config: config)
                await MainActor.run { suggestions = result; isLoading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            }
        }
    }

    private func attachTag(named name: String) {
        let tag: Tag
        if let existing = allTags.first(where: { $0.name.lowercased() == name.lowercased() }) {
            tag = existing
        } else {
            tag = Tag(name: name)
            modelContext.insert(tag)
        }
        if !prompt.tags.contains(where: { $0.id == tag.id }) {
            prompt.tags.append(tag)
        }
    }
}

// MARK: - Score Tab

private struct ScoreTabContent: View {
    @Bindable var prompt: Prompt
    let config: AIConfig

    @State private var score: QualityScore? = nil
    @State private var isLoading = false
    @State private var error: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: load) {
                if isLoading { ProgressView().controlSize(.small) }
                else { Label("Analyse", systemImage: "chart.bar") }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)

            if let err = error {
                AIErrorBar(message: err) { error = nil }
            }

            if let score {
                VStack(alignment: .leading, spacing: 4) {
                    ScoreRow(label: "Clarity",       value: score.clarity)
                    ScoreRow(label: "Specificity",   value: score.specificity)
                    ScoreRow(label: "Completeness",  value: score.completeness)
                    ScoreRow(label: "Conciseness",   value: score.conciseness)

                    HStack {
                        Text("Overall")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(String(format: "%.1f / 10", score.overall))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(10)
    }

    private func load() {
        isLoading = true
        error = nil
        Task {
            do {
                let result = try await AIService.shared.qualityScore(prompt: prompt.content, config: config)
                await MainActor.run { score = result; isLoading = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            }
        }
    }
}

private struct ScoreRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            ProgressView(value: value, total: 10)
                .progressViewStyle(.linear)
            Text(String(format: "%.0f", value))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
        }
    }
}

// MARK: - AIErrorBar

struct AIErrorBar: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 10)
    }
}
