import SwiftUI

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
                    Text("Suggest Variables — coming soon")
                        .font(.caption).foregroundStyle(.secondary).padding()
                case .tags:
                    Text("Auto-tag — coming soon")
                        .font(.caption).foregroundStyle(.secondary).padding()
                case .score:
                    Text("Quality Score — coming soon")
                        .font(.caption).foregroundStyle(.secondary).padding()
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
        let currentContent = prompt.content
        Task {
            do {
                let result = try await AIService.shared.improve(prompt: currentContent, config: config)
                await MainActor.run { improvedText = result; isImproving = false }
            } catch {
                await MainActor.run { isImproving = false }
            }
        }
    }
}
