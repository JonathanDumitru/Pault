import SwiftUI
import SwiftData

struct ABTestResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var prompt: Prompt

    let runA: PromptRun
    let runB: PromptRun

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("A/B Test Results")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            // Side-by-side results
            HStack(alignment: .top, spacing: 0) {
                variantColumn(label: "A", run: runA)
                Divider()
                variantColumn(label: "B", run: runB)
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Promote footer
            HStack(spacing: 16) {
                Button(action: { promote(variant: "A") }) {
                    Label("Promote A", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button(action: { promote(variant: "B") }) {
                    Label("Promote B", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .padding()
        }
        .frame(width: 700, height: 480)
    }

    private func variantColumn(label: String, run: PromptRun) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Variant \(label)")
                    .font(.headline)
                    .foregroundStyle(label == "A" ? .blue : .purple)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(run.model)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(run.latencyMs)ms")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider()

            ScrollView {
                Text(run.output)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func promote(variant: String) {
        if variant == "A" {
            // A is already prompt.content — just clear variantB
            prompt.variantB = nil
        } else {
            // B wins: swap content
            prompt.content = runB.resolvedInput
            prompt.variantB = nil
        }
        dismiss()
    }
}
