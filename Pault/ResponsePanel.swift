import SwiftUI
import SwiftData

struct ResponsePanel: View {
    @Environment(\.modelContext) private var modelContext

    let prompt: Prompt
    let config: AIConfig
    var variantLabel: String? = nil

    @State private var streamingText: String = ""
    @State private var isRunning: Bool = false
    @State private var errorMessage: String? = nil
    @State private var runTask: Task<Void, Never>? = nil
    @State private var startTime: Date = Date()
    @State private var runMetadata: (inputTokens: Int, outputTokens: Int, costUSD: Double)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header bar
            HStack {
                Label(config.provider.displayName + " · " + config.model,
                      systemImage: "cpu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if isRunning {
                    Button("Cancel") { runTask?.cancel() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                } else if !streamingText.isEmpty {
                    if let meta = runMetadata {
                        Text("\(meta.outputTokens) tokens • ~$\(meta.costUSD, specifier: "%.4f")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Button(action: copyResponse) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)

                    Button(action: saveAsPrompt) {
                        Label("Save as Prompt", systemImage: "plus.square")
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Divider()

            // Response or error
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding(.horizontal, 12)
            } else {
                ScrollView {
                    Text(streamingText.isEmpty ? (isRunning ? "…" : "") : streamingText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                .frame(maxHeight: 200)
            }
        }
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onAppear { startRun() }
        .onDisappear { runTask?.cancel() }
    }

    private func startRun() {
        guard !isRunning else { return }
        isRunning = true
        streamingText = ""
        runMetadata = nil
        errorMessage = nil
        startTime = Date()

        // Resolve variables
        let variables: [String: String] = prompt.templateVariables.reduce(into: [:]) {
            $0[$1.name] = $1.defaultValue
        }

        runTask = Task {
            do {
                let stream = try await AIService.shared.streamRun(
                    prompt: prompt.content,
                    variables: variables,
                    config: config
                )
                for try await event in stream {
                    switch event {
                    case .token(let token):
                        await MainActor.run { streamingText += token }
                    case .metadata(let input, let output, let cost):
                        await MainActor.run { runMetadata = (input, output, cost) }
                    }
                }
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                await MainActor.run {
                    isRunning = false
                    persistRun(output: streamingText, latencyMs: elapsed)
                }
            } catch is CancellationError {
                await MainActor.run { isRunning = false }
            } catch {
                await MainActor.run {
                    isRunning = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @MainActor
    private func persistRun(output: String, latencyMs: Int) {
        let run = PromptRun(
            promptTitle: prompt.title,
            resolvedInput: prompt.content,
            output: output,
            model: config.model,
            provider: config.provider.rawValue,
            latencyMs: latencyMs,
            inputTokens: runMetadata?.inputTokens,
            outputTokens: runMetadata?.outputTokens,
            variantLabel: variantLabel
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
