//
//  PromptLaunchpadView.swift
//  Pault
//

import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#endif

struct PromptLaunchpadView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<PromptTemplate> { $0.usageCount > 0 },
        sort: [SortDescriptor(\PromptTemplate.usageCount, order: .reverse)]
    ) private var recentTemplates: [PromptTemplate]

    @Query(sort: [SortDescriptor(\PromptTemplate.name, order: .forward)])
    private var allTemplates: [PromptTemplate]

    @State private var showTemplateBrowser = false
    @State private var showAIGenerator = false
    @State private var aiDescription = ""
    @State private var isGenerating = false
    @State private var searchText = ""

    private var service: PromptService { PromptService(modelContext: modelContext) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Prompt")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            if showTemplateBrowser {
                templateBrowserView
            } else if showAIGenerator {
                aiGeneratorView
            } else {
                launchpadGrid
            }
        }
        .frame(width: 520, height: 460)
    }

    // MARK: - Launchpad Grid

    private var launchpadGrid: some View {
        VStack(spacing: 20) {
            Spacer()

            // Card grid — 2x2
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                launchpadCard(
                    icon: "doc.text",
                    title: "Blank Prompt",
                    subtitle: "Start from scratch",
                    color: .blue
                ) {
                    createBlankPrompt()
                }

                launchpadCard(
                    icon: "rectangle.stack",
                    title: "From Template",
                    subtitle: "Use a template",
                    color: .purple
                ) {
                    showTemplateBrowser = true
                }

                if ProStatusManager.shared.isProUnlocked {
                    launchpadCard(
                        icon: "sparkles",
                        title: "Generate with AI",
                        subtitle: "Describe & generate",
                        color: .orange,
                        badge: "PRO"
                    ) {
                        showAIGenerator = true
                    }
                } else {
                    launchpadCard(
                        icon: "sparkles",
                        title: "Generate with AI",
                        subtitle: "Describe & generate",
                        color: .gray,
                        badge: "PRO"
                    ) {
                        showAIGenerator = true
                    }
                }

                launchpadCard(
                    icon: "doc.on.clipboard",
                    title: "Paste from Clipboard",
                    subtitle: "Paste existing prompt",
                    color: .green
                ) {
                    createFromClipboard()
                }
            }
            .padding(.horizontal, 32)

            // Recent templates row
            if !recentTemplates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Templates")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 32)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(recentTemplates.prefix(5)) { template in
                                Button(action: { createFromTemplate(template) }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: template.iconName)
                                            .font(.caption)
                                        Text(template.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                }
            }

            Spacer()
        }
    }

    // MARK: - Card Component

    private func launchpadCard(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundStyle(color)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.2))
                            .clipShape(Capsule())
                            .offset(x: 16, y: -8)
                    }
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func createBlankPrompt() {
        let prompt = service.createPrompt()
        postCreated(prompt)
        dismiss()
    }

    private func createFromClipboard() {
        #if os(macOS)
        let content = NSPasteboard.general.string(forType: .string) ?? ""
        #endif
        let prompt = service.createPrompt(content: content)
        TemplateEngine.syncVariables(for: prompt, in: modelContext)
        postCreated(prompt)
        dismiss()
    }

    private func createFromTemplate(_ template: PromptTemplate) {
        let prompt = service.createPromptFromTemplate(template)
        TemplateEngine.syncVariables(for: prompt, in: modelContext)
        postCreated(prompt)
        dismiss()
    }

    private func postCreated(_ prompt: Prompt) {
        NotificationCenter.default.post(
            name: .promptCreated,
            object: nil,
            userInfo: ["promptID": prompt.id]
        )
    }

    // MARK: - Template Browser

    private var templateBrowserView: some View {
        VStack(spacing: 0) {
            // Back button + search
            HStack {
                Button(action: { showTemplateBrowser = false }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                TextField("Search templates...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Template list grouped by category
            ScrollView {
                let filtered = filteredTemplates
                let categories = Array(Set(filtered.map(\.category))).sorted()

                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(categories, id: \.self) { category in
                        Section {
                            ForEach(filtered.filter { $0.category == category }) { template in
                                Button(action: { createFromTemplate(template) }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: template.iconName)
                                            .font(.title3)
                                            .foregroundStyle(.blue)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(template.name)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            Text(template.content.prefix(80) + "...")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        if template.isBuiltIn {
                                            Text("Built-in")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text(category)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding()
            }
        }
    }

    private var filteredTemplates: [PromptTemplate] {
        if searchText.isEmpty { return Array(allTemplates) }
        let query = searchText.lowercased()
        return allTemplates.filter {
            $0.name.lowercased().contains(query) ||
            $0.category.lowercased().contains(query) ||
            $0.content.lowercased().contains(query)
        }
    }

    // MARK: - AI Generator

    private var aiGeneratorView: some View {
        VStack(spacing: 16) {
            // Back button
            HStack {
                Button(action: { showAIGenerator = false }) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            if !ProStatusManager.shared.isProUnlocked {
                // Pro nudge
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text("AI Generation is a Pro feature")
                        .font(.headline)
                    Text("Upgrade to Pro to generate prompts from descriptions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text("Describe your prompt")
                        .font(.headline)
                    Text("Tell us what you want your prompt to do, and AI will generate it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    TextEditor(text: $aiDescription)
                        .font(.body)
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                        .padding(.horizontal, 32)

                    Button(action: generateFromAI) {
                        if isGenerating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Generate", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(aiDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
                }
            }

            Spacer()
        }
    }

    private func generateFromAI() {
        guard !aiDescription.isEmpty else { return }
        isGenerating = true

        let description = aiDescription
        let config = AIConfig.defaults[.claude] ?? AIConfig(provider: .claude, model: "claude-opus-4-6")

        Task {
            do {
                let content = try await AIService.shared.generatePrompt(
                    from: description,
                    config: config
                )
                await MainActor.run {
                    let prompt = service.createPrompt(content: content)
                    TemplateEngine.syncVariables(for: prompt, in: modelContext)
                    postCreated(prompt)
                    isGenerating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    let prompt = service.createPrompt(content: description)
                    postCreated(prompt)
                    dismiss()
                }
            }
        }
    }
}
