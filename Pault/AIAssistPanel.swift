import SwiftUI
import SwiftData
import Combine

struct AIAssistPanel: View {
    @Bindable var prompt: Prompt
    let config: AIConfig
    @Environment(\.modelContext) private var modelContext

    enum AssistTab: String, CaseIterable {
        case improve = "Improve"
        case variables = "Variables"
        case tags = "Tags"
        case score = "Score"
        case refine = "Refine"
    }

    @State private var selectedTab: AssistTab = .improve
    @State private var streamingImproveText: String = ""
    @State private var isImproving: Bool = false
    @State private var improveTask: Task<Void, Never>? = nil
    @State private var originalText: String = ""
    @State private var instruction: String = ""
    @State private var improveError: String? = nil
    @State private var showCursor = true
    
    private let cursorTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var hasAnyAPIKey: Bool {
        for provider in AIConfig.Provider.allCases {
            if let key = try? KeychainService().load(key: "ai.apikey.\(provider.rawValue)"), !key.isEmpty {
                return true
            }
        }
        return false
    }

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
                if !hasAnyAPIKey {
                    noKeyStateView
                } else {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 220)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var noKeyStateView: some View {
        VStack(spacing: 12) {
            Text("Set up your API key in Preferences to use AI features")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open Preferences") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var improveTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !isImproving && streamingImproveText.isEmpty {
                // Idle state
                VStack(alignment: .leading, spacing: 8) {
                    Text("Analyze your prompt and suggest improvements")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("Instruction (e.g. Add chain-of-thought)", text: $instruction)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    
                    Button(action: runImprove) {
                        Label("Improve", systemImage: "wand.and.sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if isImproving {
                // Streaming state
                VStack(alignment: .leading, spacing: 8) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            (Text(streamingImproveText)
                                .font(.system(.caption, design: .monospaced)) +
                             Text(showCursor ? "|" : "")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.accentColor))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("bottom")
                        }
                        .onChange(of: streamingImproveText) { _, _ in
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .frame(maxHeight: 120)
                    .padding(8)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Button("Cancel") {
                        improveTask?.cancel()
                        isImproving = false
                        streamingImproveText = ""
                    }
                    .buttonStyle(.bordered)
                }
                .onReceive(cursorTimer) { _ in showCursor.toggle() }
            } else {
                // Complete state (DiffView)
                VStack(alignment: .leading, spacing: 8) {
                    DiffView(original: originalText, revised: streamingImproveText)
                    
                    HStack {
                        Button("Accept") {
                            acceptImprovement()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Reject") {
                            streamingImproveText = ""
                            originalText = ""
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            
            if let err = improveError {
                AIErrorBar(message: err) { improveError = nil }
            }
        }
        .padding(10)
    }

    private func runImprove() {
        isImproving = true
        improveError = nil
        streamingImproveText = ""
        originalText = prompt.content
        
        let promptToImprove = prompt.content
        let finalInstruction = instruction
        
        improveTask = Task {
            do {
                let userPrompt = finalInstruction.isEmpty ? promptToImprove : "Instruction: \(finalInstruction)\n\nPrompt:\n\(promptToImprove)"
                let stream = try await AIService.shared.streamImprove(prompt: userPrompt, config: config)
                
                for try await event in stream {
                    if case .token(let token) = event {
                        await MainActor.run {
                            streamingImproveText += token
                        }
                    }
                }
                await MainActor.run { isImproving = false }
            } catch {
                await MainActor.run {
                    isImproving = false
                    handleAIError(error, outError: &improveError)
                }
            }
        }
    }

    private func acceptImprovement() {
        PromptService(modelContext: modelContext).saveSnapshot(for: prompt)
        prompt.content = streamingImproveText
        streamingImproveText = ""
        originalText = ""
        instruction = ""
    }
}

// MARK: - Variables Tab

private struct VariablesTabContent: View {
    @Bindable var prompt: Prompt
    let config: AIConfig
    @Environment(\.modelContext) private var modelContext

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
                                HStack(spacing: 4) {
                                    Button("Accept") { insert(suggestion) }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    
                                    Button("Reject") {
                                        suggestions.removeAll { $0.placeholder == suggestion.placeholder }
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .controlSize(.small)
                                }
                            }
                            .padding(6)
                            .background(Color.secondary.opacity(0.03))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
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
                await MainActor.run { 
                    isLoading = false
                    handleAIError(error, outError: &self.error)
                }
            }
        }
    }

    private func insert(_ suggestion: VariableSuggestion) {
        PromptService(modelContext: modelContext).saveSnapshot(for: prompt)
        // Strip wrapping {{ }} if already present, then re-wrap consistently
        let raw = suggestion.placeholder
            .replacingOccurrences(of: "{{", with: "")
            .replacingOccurrences(of: "}}", with: "")
            .trimmingCharacters(in: .whitespaces)
        let token = "{{\(raw)}}"
        if !prompt.content.contains(token) {
            prompt.content += " \(token)"
        }
        suggestions.removeAll { $0.placeholder == suggestion.placeholder }
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
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { name in
                            let attached = prompt.tags.contains(where: { $0.name.lowercased() == name.lowercased() })
                            HStack(spacing: 4) {
                                Button(name) { attachTag(named: name) }
                                    .buttonStyle(.bordered)
                                    .foregroundStyle(attached ? .secondary : .primary)
                                    .disabled(attached)
                                
                                Button {
                                    suggestions.removeAll { $0 == name }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                            }
                            .padding(4)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(.vertical, 4)
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
                await MainActor.run { 
                    isLoading = false
                    handleAIError(error, outError: &self.error)
                }
            }
        }
    }

    private func attachTag(named name: String) {
        PromptService(modelContext: modelContext).saveSnapshot(for: prompt)
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Quality Score")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(String(format: "%.1f", score.overall))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.accent)
                            Text("/ 10")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                            ScoreRow(label: "Clarity",       value: score.clarity)
                            ScoreRow(label: "Specificity",   value: score.specificity)
                            ScoreRow(label: "Completeness",  value: score.completeness)
                            ScoreRow(label: "Conciseness",   value: score.conciseness)
                        }
                        
                        if !score.tips.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Improvement Tips")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.top, 4)
                                
                                ForEach(score.tips, id: \.self) { tip in
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("\u{2022}")
                                        Text(tip)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
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
                let result = try await AIService.shared.qualityScore(prompt: prompt.content, config: config)
                await MainActor.run { score = result; isLoading = false }
            } catch {
                await MainActor.run { 
                    isLoading = false
                    handleAIError(error, outError: &self.error)
                }
            }
        }
    }
}

private struct ScoreRow: View {
    let label: String
    let value: Double

    var body: some View {
        GridRow {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            ProgressView(value: value, total: 10)
                .progressViewStyle(.linear)
                .tint(value > 7 ? .green : (value > 4 ? .orange : .red))
            
            Text(String(format: "%.0f", value))
                .font(.caption2)
                .monospacedDigit()
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
            
            if message.contains("Preferences") {
                Button("Open") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.accent)
            }
            
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

// MARK: - Error Helper

func handleAIError(_ error: Error, outError: inout String?) {
    if let aiError = error as? AIError {
        switch aiError {
        case .missingAPIKey:
            outError = "Set up your API key in Preferences"
        case .rateLimited(let retryAfter):
            outError = "Rate limit reached — try again in \(retryAfter)s"
        case .subscriptionRequired:
            outError = "Pro subscription required"
        case .httpError(let code, _):
            outError = "AI unavailable (HTTP \(code)) — check connection"
        default:
            outError = error.localizedDescription
        }
    } else {
        outError = error.localizedDescription
    }
}
