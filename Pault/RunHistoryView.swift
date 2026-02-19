import SwiftUI
import SwiftData

struct RunHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    let prompt: Prompt

    // Fetch runs for this prompt, newest first
    var runs: [PromptRun] {
        let id = prompt.id
        let descriptor = FetchDescriptor<PromptRun>(
            predicate: #Predicate { $0.prompt?.id == id },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @State private var expandedRunID: UUID? = nil

    var body: some View {
        if runs.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("No runs yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("Use the ▶ Run button to execute this prompt.")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(runs) { run in
                        RunHistoryRowView(
                            run: run,
                            isExpanded: expandedRunID == run.id,
                            onToggle: {
                                expandedRunID = expandedRunID == run.id ? nil : run.id
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct RunHistoryRowView: View {
    @Environment(\.modelContext) private var modelContext
    let run: PromptRun
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row header — always visible
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(run.model)
                                .font(.caption2)
                                .fontWeight(.medium)
                            if let label = run.variantLabel {
                                Text(label)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .background(Color.blue.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(run.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Text("\(run.latencyMs)ms")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Truncated output preview (always shown)
            Text(run.output)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            // Expanded action buttons
            if isExpanded {
                HStack(spacing: 8) {
                    Button(action: copyOutput) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)

                    Button(action: saveAsPrompt) {
                        Label("Save as Prompt", systemImage: "plus.square")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(run.output, forType: .string)
    }

    private func saveAsPrompt() {
        let newPrompt = Prompt(title: "From: \(run.promptTitle)", content: run.output)
        modelContext.insert(newPrompt)
        try? modelContext.save()
    }
}
