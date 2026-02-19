import SwiftUI
import SwiftData

// MARK: - DiffView

/// Word-level diff view showing removed (red strikethrough) and added (green) text.
struct DiffView: View {
    let original: String
    let revised: String

    struct DiffChunk: Identifiable {
        let id = UUID()
        let text: String
        let kind: Kind
        enum Kind { case unchanged, removed, added }
    }

    private var chunks: [DiffChunk] {
        let originalWords = original.components(separatedBy: .whitespaces)
        let revisedWords = revised.components(separatedBy: .whitespaces)
        let diff = revisedWords.difference(from: originalWords).inferringMoves()

        var result: [DiffChunk] = []
        var oIdx = 0

        for change in diff {
            switch change {
            case .remove(let offset, let element, _):
                while oIdx < offset {
                    result.append(.init(text: originalWords[oIdx] + " ", kind: .unchanged))
                    oIdx += 1
                }
                result.append(.init(text: element + " ", kind: .removed))
                oIdx += 1
            case .insert(_, let element, _):
                result.append(.init(text: element + " ", kind: .added))
            }
        }
        while oIdx < originalWords.count {
            result.append(.init(text: originalWords[oIdx] + " ", kind: .unchanged))
            oIdx += 1
        }
        return result
    }

    var body: some View {
        ScrollView {
            chunks.reduce(Text("")) { partial, chunk in
                switch chunk.kind {
                case .unchanged:
                    return partial + Text(chunk.text)
                case .removed:
                    return partial + Text(chunk.text)
                        .strikethrough(color: .red)
                        .foregroundStyle(.red.opacity(0.7))
                case .added:
                    return partial + Text(chunk.text)
                        .foregroundStyle(.green)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .frame(maxHeight: 180)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - RefinementLoopView

struct RefinementLoopView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var prompt: Prompt
    let config: AIConfig

    @State private var goal: String = ""
    @State private var iterationCount: Int = 0
    @State private var currentRevision: String = ""
    @State private var isRefining: Bool = false
    @State private var errorMessage: String? = nil
    @State private var pendingRating: Int? = nil
    @State private var history: [(input: String, output: String, rating: Int?)] = []

    private let maxIterations = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if currentRevision.isEmpty {
                // Initial state — goal input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Refinement goal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Make more concise and add a role", text: $goal)
                        .textFieldStyle(.roundedBorder)
                    Button(action: refine) {
                        if isRefining {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Refine", systemImage: "wand.and.sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(goal.isEmpty || isRefining)
                }
            } else {
                // Show diff + actions
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Iteration \(iterationCount) of \(maxIterations)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let err = errorMessage {
                            Text(err).font(.caption2).foregroundStyle(.red)
                        }
                    }

                    DiffView(original: prompt.content, revised: currentRevision)

                    // Star rating
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: (pendingRating ?? 0) >= star ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                                .onTapGesture { pendingRating = star }
                        }
                        Spacer()
                    }

                    // Action buttons
                    HStack(spacing: 8) {
                        Button("Accept") { accept() }
                            .buttonStyle(.borderedProminent)

                        Button(action: tryAgain) {
                            if isRefining { ProgressView().controlSize(.small) }
                            else { Text("Try Again") }
                        }
                        .buttonStyle(.bordered)
                        .disabled(iterationCount >= maxIterations || isRefining)

                        Button("Discard") { reset() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }

                    if iterationCount >= maxIterations {
                        Text("Max iterations reached — accept or discard.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(10)
    }

    // MARK: - Private

    private func refine() {
        isRefining = true
        errorMessage = nil
        let basePrompt = prompt.content
        let currentGoal = goal
        let historyContext = buildHistoryContext()

        Task {
            do {
                // Build goal-aware system prompt by prefixing the user prompt
                let augmentedPrompt = "Goal: \(currentGoal)\n\(historyContext)\n\n\(basePrompt)"
                let improved = try await AIService.shared.improve(prompt: augmentedPrompt, config: config)
                await MainActor.run {
                    currentRevision = improved
                    iterationCount += 1
                    isRefining = false
                }
            } catch {
                await MainActor.run {
                    isRefining = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func tryAgain() {
        history.append((input: prompt.content, output: currentRevision, rating: pendingRating))
        pendingRating = nil
        refine()
    }

    private func accept() {
        let finalRevision = currentRevision
        let titleSnapshot = prompt.title

        // Persist all intermediate iterations
        for (i, item) in history.enumerated() {
            let run = PromptRun(
                promptTitle: titleSnapshot,
                resolvedInput: item.input,
                output: item.output,
                model: config.model,
                provider: config.provider.rawValue,
                latencyMs: 0,
                variantLabel: "refine-\(i + 1)",
                userRating: item.rating
            )
            run.prompt = prompt
            modelContext.insert(run)
        }

        // Persist final accepted revision
        let finalRun = PromptRun(
            promptTitle: titleSnapshot,
            resolvedInput: prompt.content,
            output: finalRevision,
            model: config.model,
            provider: config.provider.rawValue,
            latencyMs: 0,
            variantLabel: "refine-\(iterationCount)",
            userRating: pendingRating
        )
        finalRun.prompt = prompt
        modelContext.insert(finalRun)
        try? modelContext.save()

        // Update prompt content
        prompt.content = finalRevision
        reset()
    }

    private func reset() {
        currentRevision = ""
        iterationCount = 0
        pendingRating = nil
        history = []
        errorMessage = nil
    }

    private func buildHistoryContext() -> String {
        guard !history.isEmpty else { return "" }
        let lines = history.enumerated().map { i, item in
            let ratingStr = item.rating.map { "User rated \($0)/5." } ?? ""
            return "Attempt \(i + 1): \(item.output)\n\(ratingStr)"
        }
        return "Previous attempts (improve further):\n" + lines.joined(separator: "\n---\n")
    }
}
