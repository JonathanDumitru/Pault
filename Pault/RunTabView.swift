import SwiftUI
import SwiftData

struct RunTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: Prompt
    let config: AIConfig

    @State private var variableValues: [String: String] = [:]
    @State private var isRunning = false
    @State private var streamingText = ""
    @State private var runMetadata: (inputTokens: Int, outputTokens: Int, costUSD: Double)? = nil
    @State private var runTask: Task<Void, Never>? = nil
    @State private var startTime: Date = Date()
    @State private var errorMessage: String? = nil
    
    @Query private var runs: [PromptRun]

    init(prompt: Prompt, config: AIConfig) {
        self.prompt = prompt
        self.config = config
        let promptID = prompt.id
        _runs = Query(filter: #Predicate<PromptRun> { $0.prompt?.id == promptID }, sort: \.createdAt, order: .reverse)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 1. Variable form
                    if !prompt.templateVariables.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Variables")
                                .font(.headline)
                            
                            ForEach(prompt.templateVariables) { variable in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(variable.name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("Value", text: Binding(
                                        get: { variableValues[variable.name] ?? variable.defaultValue },
                                        set: { variableValues[variable.name] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 2. Execute button row
                    HStack(spacing: 12) {
                        Button(action: startRun) {
                            Label(isRunning ? "Running..." : "Run", systemImage: "play.fill")
                                .frame(width: 100)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunning)

                        if isRunning {
                            Button("Cancel") {
                                runTask?.cancel()
                                isRunning = false
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(config.provider.displayName) / \(config.model)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    // 3. Error display
                    if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // 4. Streaming response area
                    if isRunning || !streamingText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Response")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(streamingText + (isRunning ? "▊" : ""))
                                    .font(.system(.body, design: .monospace))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .textSelection(.enabled)
                                
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                            )
                            
                            // 5. Response footer
                            if let meta = runMetadata, !isRunning {
                                HStack {
                                    Text("\(meta.outputTokens) tokens")
                                    Text("•")
                                    Text("~$\(meta.costUSD, specifier: "%.4f")")
                                    Text("•")
                                    Text("\(Int(Date().timeIntervalSince(startTime)))s")
                                }
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                            }
                            
                            // 6. Response actions
                            if !isRunning && !streamingText.isEmpty {
                                HStack(spacing: 12) {
                                    Button(action: copyResponse) {
                                        Label("Copy", systemImage: "doc.on.doc")
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(action: saveAsPrompt) {
                                        Label("Save as Prompt", systemImage: "plus.square")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    Divider()

                    // 7. Run history
                    VStack(alignment: .leading, spacing: 12) {
                        Text("History")
                            .font(.headline)
                        
                        RunHistoryView(prompt: prompt, onRunAgain: { previousRun in
                            self.streamingText = ""
                            self.runMetadata = nil
                            self.errorMessage = nil
                            // Pre-fill variables from previous run if possible (or just use the resolved input)
                            // For simplicity, we'll just use the prompt as is for now, but task says:
                            // "setting variableValues from the run's resolvedInput (parse back the variables or just use resolvedInput directly)"
                            // Since we don't have a reliable way to parse back variables from resolved text, 
                            // we'll just use the resolved text as the input for startRun.
                            startRun(overrideInput: previousRun.resolvedInput)
                        })
                    }
                }
                .padding()
                .onChange(of: streamingText) { _, _ in
                    if isRunning {
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func startRun() {
        startRun(overrideInput: nil)
    }

    private func startRun(overrideInput: String? = nil) {
        guard !isRunning else { return }
        
        // Pro-gate
        guard ProFeature.isUnlocked(.apiRunner) else {
            // This should be handled by the parent view switching tabs, 
            // but as a safety measure we could trigger paywall here.
            return 
        }

        isRunning = true
        streamingText = ""
        runMetadata = nil
        errorMessage = nil
        startTime = Date()

        let resolvedText: String
        if let override = overrideInput {
            resolvedText = override
        } else {
            // Substitute variables
            var currentContent = prompt.content
            for variable in prompt.templateVariables {
                let value = variableValues[variable.name] ?? variable.defaultValue
                currentContent = currentContent.replacingOccurrences(of: "{{\(variable.name)}}", with: value)
            }
            resolvedText = currentContent
        }

        runTask = Task {
            do {
                let stream = try await AIService.shared.streamRun(
                    prompt: resolvedText,
                    variables: [:], // already resolved
                    config: config
                )
                
                for try await event in stream {
                    switch event {
                    case .token(let t):
                        await MainActor.run { streamingText += t }
                    case .metadata(let input, let output, let cost):
                        await MainActor.run { runMetadata = (input, output, cost) }
                    }
                }
                
                let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
                await MainActor.run {
                    isRunning = false
                    persistRun(resolvedInput: resolvedText, output: streamingText, latencyMs: latencyMs)
                }
            } catch is CancellationError {
                await MainActor.run { isRunning = false }
            } catch let error as AIError {
                await MainActor.run {
                    isRunning = false
                    switch error {
                    case .subscriptionRequired:
                        errorMessage = "Subscription required for API Runner."
                    case .rateLimited(let retryAfter):
                        errorMessage = "Rate limited. Retry after \(retryAfter)s."
                    default:
                        errorMessage = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isRunning = false
                    errorMessage = "AI unavailable — check connection"
                }
            }
        }
    }

    @MainActor
    private func persistRun(resolvedInput: String, output: String, latencyMs: Int) {
        let run = PromptRun(
            promptTitle: prompt.title,
            resolvedInput: resolvedInput,
            output: output,
            model: config.model,
            provider: config.provider.rawValue,
            latencyMs: latencyMs,
            inputTokens: runMetadata?.inputTokens,
            outputTokens: runMetadata?.outputTokens
        )
        run.prompt = prompt
        modelContext.insert(run)
        try? modelContext.save()
    }

    private func copyResponse() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(streamingText, forType: .string)
    }

    @MainActor
    private func saveAsPrompt() {
        let newPrompt = Prompt(title: "From: \(prompt.title)", content: streamingText)
        modelContext.insert(newPrompt)
        try? modelContext.save()
    }
}
