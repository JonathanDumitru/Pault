# Block Editor Canvas-Centric UX Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the block editor from panel-centric to canvas-centric with slash commands, inline editing, consolidated categories, smart preview strip, templates, and AI suggestions.

**Architecture:** Extend existing PromptStudioModel with new state for slash palette, consolidated categories, and suggestions. Add new view components (SlashCommandPalette, PreviewStrip) and modify existing views (BlockRowView, BlockLibraryView, CompositionCanvasView) for inline editing and visual indicators.

**Tech Stack:** SwiftUI, Combine, Swift Testing framework

---

## Phase 1: Category Consolidation

### Task 1.1: Create ConsolidatedBlockCategory Enum

**Files:**
- Create: `Pault/BlockEditor/Models/ConsolidatedBlockCategory.swift`
- Test: `PaultTests/ConsolidatedBlockCategoryTests.swift`

**Step 1: Write the failing test**

```swift
// PaultTests/ConsolidatedBlockCategoryTests.swift
import Testing
@testable import Pault

struct ConsolidatedBlockCategoryTests {

    @Test func allCases_returns7Categories() {
        #expect(ConsolidatedBlockCategory.allCases.count == 7)
    }

    @Test func role_mapsFromCorrectLegacyCategories() {
        let mapped = ConsolidatedBlockCategory.role.legacyCategories
        #expect(mapped.contains(.rolePerspective))
        #expect(mapped.contains(.perspectiveFrames))
    }

    @Test func consolidate_mapsLegacyCategoryToConsolidated() {
        let result = ConsolidatedBlockCategory.from(legacy: .rolePerspective)
        #expect(result == .role)
    }

    @Test func icon_returnsCorrectSFSymbol() {
        #expect(ConsolidatedBlockCategory.role.icon == "person.fill")
        #expect(ConsolidatedBlockCategory.task.icon == "checkmark.circle.fill")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/ConsolidatedBlockCategoryTests 2>&1 | xcpretty`
Expected: FAIL with "cannot find 'ConsolidatedBlockCategory' in scope"

**Step 3: Write minimal implementation**

```swift
// Pault/BlockEditor/Models/ConsolidatedBlockCategory.swift
import SwiftUI

/// Consolidated block categories (7 top-level groups from 20+ legacy categories)
enum ConsolidatedBlockCategory: String, CaseIterable, Identifiable {
    case role = "Role"
    case context = "Context"
    case task = "Task"
    case format = "Format"
    case constraints = "Constraints"
    case examples = "Examples"
    case meta = "Meta"

    var id: String { rawValue }

    /// SF Symbol icon for this category
    var icon: String {
        switch self {
        case .role: return "person.fill"
        case .context: return "book.fill"
        case .task: return "checkmark.circle.fill"
        case .format: return "list.bullet.rectangle.fill"
        case .constraints: return "xmark.octagon.fill"
        case .examples: return "doc.text.fill"
        case .meta: return "gearshape.fill"
        }
    }

    /// Color for this category (derived from primary legacy category)
    var color: Color {
        switch self {
        case .role: return Color(hue: 0.08, saturation: 0.60, brightness: 0.75)
        case .context: return Color(hue: 0.58, saturation: 0.65, brightness: 0.90)
        case .task: return Color(hue: 0.78, saturation: 0.68, brightness: 0.82)
        case .format: return Color(hue: 0.12, saturation: 0.72, brightness: 0.92)
        case .constraints: return Color(hue: 0.98, saturation: 0.70, brightness: 0.85)
        case .examples: return Color(hue: 0.30, saturation: 0.40, brightness: 0.80)
        case .meta: return Color(hue: 0.72, saturation: 0.75, brightness: 0.80)
        }
    }

    /// Legacy BlockCategory values that map to this consolidated category
    var legacyCategories: Set<BlockCategory> {
        switch self {
        case .role:
            return [.rolePerspective, .perspectiveFrames]
        case .context:
            return [.inputs, .domainSpecific]
        case .task:
            return [.intent, .instructions, .taskTemplates, .execution]
        case .format:
            return [.structure, .toneStyle, .outputStructures, .communicationPatterns]
        case .constraints:
            return [.constraints, .verification, .qualityControls]
        case .examples:
            return [.logic, .transforms, .interactionModes]
        case .meta:
            return [.reasoning, .metaPrompting, .reuse, .modelConfig, .agenticWorkflows, .softwareEngineering, .dataAnalysis, .creativeContent]
        }
    }

    /// Map a legacy category to its consolidated parent
    static func from(legacy: BlockCategory) -> ConsolidatedBlockCategory {
        for consolidated in ConsolidatedBlockCategory.allCases {
            if consolidated.legacyCategories.contains(legacy) {
                return consolidated
            }
        }
        return .meta // Default fallback
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/ConsolidatedBlockCategoryTests 2>&1 | xcpretty`
Expected: PASS

**Step 5: Commit**

```bash
git add Pault/BlockEditor/Models/ConsolidatedBlockCategory.swift PaultTests/ConsolidatedBlockCategoryTests.swift
git commit -m "feat(block-editor): add ConsolidatedBlockCategory for 7-category grouping"
```

---

### Task 1.2: Add Consolidated Library to PromptStudioModel

**Files:**
- Modify: `Pault/BlockEditor/PromptStudioModel.swift`
- Test: `PaultTests/PromptStudioModelTests.swift`

**Step 1: Write the failing test**

Add to `PaultTests/PromptStudioModelTests.swift`:

```swift
@Test func consolidatedLibrary_groups20CategoriesInto7() throws {
    let context = try makeContext()
    let prompt = makePrompt(in: context)
    let model = PromptStudioModel(prompt: prompt)

    #expect(model.consolidatedLibrary.count == 7)
    #expect(model.consolidatedLibrary[.role] != nil)
    #expect(model.consolidatedLibrary[.task] != nil)
}

@Test func consolidatedLibrary_includesAllBlocksFromLegacy() throws {
    let context = try makeContext()
    let prompt = makePrompt(in: context)
    let model = PromptStudioModel(prompt: prompt)

    let legacyTotal = model.library.values.reduce(0) { $0 + $1.count }
    let consolidatedTotal = model.consolidatedLibrary.values.reduce(0) { $0 + $1.count }

    #expect(consolidatedTotal == legacyTotal)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/PromptStudioModelTests/consolidatedLibrary_groups20CategoriesInto7 2>&1 | xcpretty`
Expected: FAIL with "value of type 'PromptStudioModel' has no member 'consolidatedLibrary'"

**Step 3: Write minimal implementation**

Add to `PromptStudioModel.swift` after `library` property:

```swift
/// Consolidated library grouping legacy categories into 7 top-level groups
var consolidatedLibrary: [ConsolidatedBlockCategory: [Block]] {
    var result: [ConsolidatedBlockCategory: [Block]] = [:]

    for consolidated in ConsolidatedBlockCategory.allCases {
        var blocks: [Block] = []
        for legacy in consolidated.legacyCategories {
            if let legacyBlocks = library[legacy] {
                blocks.append(contentsOf: legacyBlocks)
            }
        }
        if !blocks.isEmpty {
            result[consolidated] = blocks
        }
    }

    return result
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/PromptStudioModelTests/consolidatedLibrary_groups20CategoriesInto7 2>&1 | xcpretty`
Expected: PASS

**Step 5: Commit**

```bash
git add Pault/BlockEditor/PromptStudioModel.swift PaultTests/PromptStudioModelTests.swift
git commit -m "feat(block-editor): add consolidatedLibrary computed property"
```

---

## Phase 2: Block Status Indicators

### Task 2.1: Add PlaceholderStatus to Block Display

**Files:**
- Create: `Pault/BlockEditor/Models/BlockPlaceholderStatus.swift`
- Test: `PaultTests/BlockPlaceholderStatusTests.swift`

**Step 1: Write the failing test**

```swift
// PaultTests/BlockPlaceholderStatusTests.swift
import Testing
@testable import Pault

struct BlockPlaceholderStatusTests {

    @Test func unfilled_whenNoInputsProvided() {
        let snippet = "ROLE: {{role}} with {{years}} experience"
        let inputs: [String: String] = [:]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .unfilled)
    }

    @Test func partial_whenSomeInputsFilled() {
        let snippet = "ROLE: {{role}} with {{years}} experience"
        let inputs = ["role": "developer"]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .partial)
    }

    @Test func complete_whenAllInputsFilled() {
        let snippet = "ROLE: {{role}} with {{years}} experience"
        let inputs = ["role": "developer", "years": "10"]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .complete)
    }

    @Test func complete_whenNoPlaceholders() {
        let snippet = "You are a helpful assistant."
        let inputs: [String: String] = [:]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .complete)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/BlockPlaceholderStatusTests 2>&1 | xcpretty`
Expected: FAIL with "cannot find 'BlockPlaceholderStatus' in scope"

**Step 3: Write minimal implementation**

```swift
// Pault/BlockEditor/Models/BlockPlaceholderStatus.swift
import SwiftUI

/// Status of placeholder completion for a block
enum BlockPlaceholderStatus: Equatable {
    case unfilled   // No placeholders filled (or has unfilled required ones)
    case partial    // Some but not all placeholders filled
    case complete   // All placeholders filled (or no placeholders exist)

    /// Calculate status from snippet and current inputs
    static func calculate(snippet: String, inputs: [String: String]) -> BlockPlaceholderStatus {
        let placeholders = PromptStudioModel.placeholders(in: snippet)

        guard !placeholders.isEmpty else {
            return .complete
        }

        let filledCount = placeholders.filter { placeholder in
            guard let value = inputs[placeholder] else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count

        if filledCount == 0 {
            return .unfilled
        } else if filledCount == placeholders.count {
            return .complete
        } else {
            return .partial
        }
    }

    /// Indicator color for this status
    var color: Color {
        switch self {
        case .unfilled: return .red
        case .partial: return .yellow
        case .complete: return .green
        }
    }

    /// SF Symbol for status indicator
    var icon: String {
        switch self {
        case .unfilled: return "circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .complete: return "checkmark.circle.fill"
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/BlockPlaceholderStatusTests 2>&1 | xcpretty`
Expected: PASS

**Step 5: Commit**

```bash
git add Pault/BlockEditor/Models/BlockPlaceholderStatus.swift PaultTests/BlockPlaceholderStatusTests.swift
git commit -m "feat(block-editor): add BlockPlaceholderStatus for visual indicators"
```

---

### Task 2.2: Add Status Method to PromptStudioModel

**Files:**
- Modify: `Pault/BlockEditor/PromptStudioModel.swift`
- Test: `PaultTests/PromptStudioModelTests.swift`

**Step 1: Write the failing test**

Add to `PaultTests/PromptStudioModelTests.swift`:

```swift
@Test func placeholderStatus_returnsUnfilledForEmptyInputs() throws {
    let context = try makeContext()
    let prompt = makePrompt(in: context)
    let model = PromptStudioModel(prompt: prompt)

    // Add a block with placeholders
    let roleBlocks = model.library[.rolePerspective] ?? []
    guard let block = roleBlocks.first(where: { $0.snippet.contains("{{") }) else {
        Issue.record("No block with placeholders found")
        return
    }
    model.addToCanvas(block)

    let status = model.placeholderStatus(for: block.id)
    #expect(status == .unfilled)
}

@Test func placeholderStatus_returnsCompleteWhenFilled() throws {
    let context = try makeContext()
    let prompt = makePrompt(in: context)
    let model = PromptStudioModel(prompt: prompt)

    // Add a block and fill its placeholders
    let roleBlocks = model.library[.rolePerspective] ?? []
    guard let block = roleBlocks.first(where: { $0.snippet.contains("{{") }) else {
        Issue.record("No block with placeholders found")
        return
    }
    model.addToCanvas(block)

    let placeholders = PromptStudioModel.placeholders(in: block.snippet)
    for placeholder in placeholders {
        model.setBlockInput(blockID: block.id, placeholder: placeholder, value: "test value")
    }

    let status = model.placeholderStatus(for: block.id)
    #expect(status == .complete)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/PromptStudioModelTests/placeholderStatus_returnsUnfilledForEmptyInputs 2>&1 | xcpretty`
Expected: FAIL with "value of type 'PromptStudioModel' has no member 'placeholderStatus'"

**Step 3: Write minimal implementation**

Add to `PromptStudioModel.swift`:

```swift
/// Get placeholder completion status for a canvas block
func placeholderStatus(for blockID: UUID) -> BlockPlaceholderStatus {
    guard let block = canvasBlocks.first(where: { $0.id == blockID }) else {
        return .complete
    }
    let inputs = blockInputs[blockID] ?? [:]
    return BlockPlaceholderStatus.calculate(snippet: block.snippet, inputs: inputs)
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/PromptStudioModelTests/placeholderStatus_returnsUnfilledForEmptyInputs 2>&1 | xcpretty`
Expected: PASS

**Step 5: Commit**

```bash
git add Pault/BlockEditor/PromptStudioModel.swift PaultTests/PromptStudioModelTests.swift
git commit -m "feat(block-editor): add placeholderStatus method to model"
```

---

### Task 2.3: Update BlockRowView with Status Indicator

**Files:**
- Modify: `Pault/BlockEditor/Views/BlockRowView.swift`

**Step 1: No test needed (UI change)**

This is a visual update - we'll verify manually.

**Step 2: Write implementation**

Update `BlockRowView.swift` blockHeader:

Replace the category indicator circle with status-aware indicator:

```swift
// In BlockRowView, add property
let placeholderStatus: BlockPlaceholderStatus

// Update blockHeader, replace:
//   Circle()
//       .fill(block.category.color)
//       .frame(width: 10, height: 10)

// With:
Circle()
    .fill(placeholderStatus.color)
    .frame(width: 10, height: 10)
    .overlay(
        Image(systemName: placeholderStatus.icon)
            .font(.system(size: 6))
            .foregroundStyle(.white)
    )
```

Also update the call site in `CompositionCanvasView.swift`:

```swift
BlockRowView(
    block: block,
    index: index,
    isSelected: model.selectedCanvasBlockID == block.id,
    placeholderStatus: model.placeholderStatus(for: block.id),  // Add this
    inputs: model.blockInputs[block.id] ?? [:],
    // ... rest unchanged
)
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/BlockRowView.swift Pault/BlockEditor/Views/CompositionCanvasView.swift
git commit -m "feat(block-editor): add placeholder status indicator to BlockRowView"
```

---

## Phase 3: Slash Command Palette

### Task 3.1: Create SlashCommandPalette Model

**Files:**
- Create: `Pault/BlockEditor/Models/SlashCommandState.swift`
- Test: `PaultTests/SlashCommandStateTests.swift`

**Step 1: Write the failing test**

```swift
// PaultTests/SlashCommandStateTests.swift
import Testing
@testable import Pault

struct SlashCommandStateTests {

    @Test func filterBlocks_returnsAllWhenQueryEmpty() {
        let blocks = [
            Block(title: "Expert", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "")

        #expect(results.count == 2)
    }

    @Test func filterBlocks_fuzzyMatchesByTitle() {
        let blocks = [
            Block(title: "Expert Advisor", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task Definition", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "exp")

        #expect(results.count == 1)
        #expect(results.first?.title == "Expert Advisor")
    }

    @Test func filterBlocks_matchesByCategory() {
        let blocks = [
            Block(title: "Expert", category: .rolePerspective, valueType: .string, snippet: ""),
            Block(title: "Task", category: .instructions, valueType: .string, snippet: "")
        ]

        let results = SlashCommandState.filterBlocks(blocks, query: "role")

        #expect(results.count == 1)
        #expect(results.first?.title == "Expert")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/SlashCommandStateTests 2>&1 | xcpretty`
Expected: FAIL

**Step 3: Write minimal implementation**

```swift
// Pault/BlockEditor/Models/SlashCommandState.swift
import SwiftUI

/// State management for the slash command palette
@MainActor
final class SlashCommandState: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var query: String = ""
    @Published var selectedIndex: Int = 0

    /// Recent blocks (persisted)
    @AppStorage("recentBlockTitles") private var recentBlockTitlesData: Data = Data()

    var recentBlockTitles: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: recentBlockTitlesData)) ?? []
        }
        set {
            recentBlockTitlesData = (try? JSONEncoder().encode(Array(newValue.prefix(5)))) ?? Data()
        }
    }

    func show() {
        query = ""
        selectedIndex = 0
        isVisible = true
    }

    func hide() {
        isVisible = false
        query = ""
    }

    func recordUsage(block: Block) {
        var recent = recentBlockTitles
        recent.removeAll { $0 == block.title }
        recent.insert(block.title, at: 0)
        recentBlockTitles = Array(recent.prefix(5))
    }

    func moveSelection(by delta: Int, maxIndex: Int) {
        let newIndex = selectedIndex + delta
        selectedIndex = max(0, min(maxIndex - 1, newIndex))
    }

    /// Filter blocks by fuzzy matching query against title and category
    static func filterBlocks(_ blocks: [Block], query: String) -> [Block] {
        guard !query.isEmpty else { return blocks }

        let lowercasedQuery = query.lowercased()
        return blocks.filter { block in
            block.title.lowercased().contains(lowercasedQuery) ||
            block.category.rawValue.lowercased().contains(lowercasedQuery)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/SlashCommandStateTests 2>&1 | xcpretty`
Expected: PASS

**Step 5: Commit**

```bash
git add Pault/BlockEditor/Models/SlashCommandState.swift PaultTests/SlashCommandStateTests.swift
git commit -m "feat(block-editor): add SlashCommandState for palette management"
```

---

### Task 3.2: Create SlashCommandPaletteView

**Files:**
- Create: `Pault/BlockEditor/Views/SlashCommandPaletteView.swift`

**Step 1: No test (UI component)**

**Step 2: Write implementation**

```swift
// Pault/BlockEditor/Views/SlashCommandPaletteView.swift
import SwiftUI

/// Floating palette for quick block insertion via slash commands
struct SlashCommandPaletteView: View {
    @ObservedObject var state: SlashCommandState
    @ObservedObject var model: PromptStudioModel
    let onSelect: (Block) -> Void

    @FocusState private var isSearchFocused: Bool

    private var filteredBlocks: [Block] {
        let allBlocks = model.library.values.flatMap { $0 }
        return SlashCommandState.filterBlocks(allBlocks, query: state.query)
    }

    private var recentBlocks: [Block] {
        let allBlocks = model.library.values.flatMap { $0 }
        return state.recentBlockTitles.compactMap { title in
            allBlocks.first { $0.title == title }
        }
    }

    private var groupedResults: [(ConsolidatedBlockCategory, [Block])] {
        let filtered = filteredBlocks
        return ConsolidatedBlockCategory.allCases.compactMap { category in
            let blocks = filtered.filter { ConsolidatedBlockCategory.from(legacy: $0.category) == category }
            return blocks.isEmpty ? nil : (category, blocks)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search blocks...", text: $state.query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { selectCurrent() }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Results
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        // Recent section
                        if state.query.isEmpty && !recentBlocks.isEmpty {
                            sectionHeader("Recent", icon: "clock.fill")
                            ForEach(recentBlocks) { block in
                                blockRow(block, isSelected: isSelected(block))
                            }
                            Divider().padding(.vertical, 4)
                        }

                        // Grouped results
                        ForEach(groupedResults, id: \.0) { category, blocks in
                            sectionHeader(category.rawValue, icon: category.icon, color: category.color)
                            ForEach(blocks) { block in
                                blockRow(block, isSelected: isSelected(block))
                                    .id(block.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: state.selectedIndex) { _, newIndex in
                    if let block = blockAtIndex(newIndex) {
                        proxy.scrollTo(block.id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 320, height: 400)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        .onAppear { isSearchFocused = true }
        .onKeyPress(.upArrow) {
            state.moveSelection(by: -1, maxIndex: totalBlockCount)
            return .handled
        }
        .onKeyPress(.downArrow) {
            state.moveSelection(by: 1, maxIndex: totalBlockCount)
            return .handled
        }
        .onKeyPress(.escape) {
            state.hide()
            return .handled
        }
    }

    // MARK: - Helpers

    private var totalBlockCount: Int {
        (state.query.isEmpty ? recentBlocks.count : 0) + filteredBlocks.count
    }

    private func blockAtIndex(_ index: Int) -> Block? {
        var currentIndex = 0

        if state.query.isEmpty {
            for block in recentBlocks {
                if currentIndex == index { return block }
                currentIndex += 1
            }
        }

        for block in filteredBlocks {
            if currentIndex == index { return block }
            currentIndex += 1
        }

        return nil
    }

    private func isSelected(_ block: Block) -> Bool {
        blockAtIndex(state.selectedIndex)?.id == block.id
    }

    private func selectCurrent() {
        if let block = blockAtIndex(state.selectedIndex) {
            state.recordUsage(block: block)
            onSelect(block)
            state.hide()
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, icon: String, color: Color = .secondary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func blockRow(_ block: Block, isSelected: Bool) -> some View {
        Button(action: {
            state.recordUsage(block: block)
            onSelect(block)
            state.hide()
        }) {
            HStack(spacing: 8) {
                Circle()
                    .fill(block.category.color)
                    .frame(width: 8, height: 8)

                Text(block.title)
                    .font(.callout)

                Spacer()

                Text(ConsolidatedBlockCategory.from(legacy: block.category).rawValue)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let prompt = Prompt(title: "Test", content: "")
    let model = PromptStudioModel(prompt: prompt)
    let state = SlashCommandState()
    state.isVisible = true

    return SlashCommandPaletteView(state: state, model: model) { block in
        print("Selected: \(block.title)")
    }
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/SlashCommandPaletteView.swift
git commit -m "feat(block-editor): add SlashCommandPaletteView component"
```

---

### Task 3.3: Integrate Slash Palette into CompositionCanvasView

**Files:**
- Modify: `Pault/BlockEditor/Views/CompositionCanvasView.swift`

**Step 1: No test (integration)**

**Step 2: Write implementation**

Add to CompositionCanvasView:

```swift
// Add state object
@StateObject private var slashState = SlashCommandState()

// Add overlay after dropDestination:
.overlay {
    if slashState.isVisible {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture { slashState.hide() }

        SlashCommandPaletteView(state: slashState, model: model) { block in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                model.addToCanvas(block)
            }
        }
    }
}

// Add keyboard shortcut handler after existing onKeyPress handlers:
.onKeyPress(characters: CharacterSet(charactersIn: "/")) {
    slashState.show()
    return .handled
}
.onKeyPress(.init("k"), modifiers: .command) {
    slashState.show()
    return .handled
}
```

Also update the empty canvas state to show slash hint:

```swift
private var emptyCanvasState: some View {
    VStack(spacing: 16) {
        Spacer()

        Image(systemName: "square.stack.3d.up")
            .font(.system(size: 48))
            .foregroundStyle(.tertiary)

        VStack(spacing: 4) {
            Text("Start Building")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Type / to search blocks or press ⌘K")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }

        // Slash trigger area
        Button(action: { slashState.show() }) {
            HStack(spacing: 8) {
                Text("/")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Text("Add block...")
                    .font(.callout)
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)

        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/CompositionCanvasView.swift
git commit -m "feat(block-editor): integrate slash command palette into canvas"
```

---

## Phase 4: Smart Preview Strip

### Task 4.1: Create PreviewStripView

**Files:**
- Create: `Pault/BlockEditor/Views/PreviewStripView.swift`

**Step 1: No test (UI component)**

**Step 2: Write implementation**

```swift
// Pault/BlockEditor/Views/PreviewStripView.swift
import SwiftUI

/// Compact always-visible preview strip below the canvas
struct PreviewStripView: View {
    @ObservedObject var model: PromptStudioModel
    @Binding var isExpanded: Bool

    private var tokenColor: Color {
        if model.tokenEstimate < 1000 {
            return .green
        } else if model.tokenEstimate < 3000 {
            return .yellow
        } else {
            return .red
        }
    }

    private var placeholderStats: (filled: Int, total: Int) {
        var filled = 0
        var total = 0

        for block in model.canvasBlocks {
            let placeholders = PromptStudioModel.placeholders(in: block.snippet)
            total += placeholders.count

            let inputs = model.blockInputs[block.id] ?? [:]
            filled += placeholders.filter { p in
                let value = inputs[p] ?? ""
                return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.count
        }

        return (filled, total)
    }

    private var previewText: String {
        let text = model.filledExample.isEmpty ? model.rawTemplate : model.filledExample
        return text.isEmpty ? "No blocks added yet" : text
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .top, spacing: 12) {
                // Preview text (truncated)
                Text(previewText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(model.canvasBlocks.isEmpty ? .tertiary : .secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 32)

                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tokenColor)
                            .frame(width: 6, height: 6)

                        Text("~\(model.tokenEstimate) tokens")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if placeholderStats.total > 0 {
                        Text("\(placeholderStats.filled)/\(placeholderStats.total) filled")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Expand button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("p", modifiers: .command)
                .help("Toggle full preview (⌘P)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

#Preview {
    let prompt = Prompt(title: "Test", content: "")
    let model = PromptStudioModel(prompt: prompt)

    return PreviewStripView(model: model, isExpanded: .constant(false))
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/PreviewStripView.swift
git commit -m "feat(block-editor): add PreviewStripView component"
```

---

### Task 4.2: Integrate Preview Strip into BlockEditorView

**Files:**
- Modify: `Pault/BlockEditor/Views/BlockEditorView.swift`

**Step 1: No test (integration)**

**Step 2: Write implementation**

Update BlockEditorView body to include preview strip:

```swift
var body: some View {
    VStack(spacing: 0) {
        // Block editor toolbar
        blockEditorToolbar

        Divider()

        // Content area with collapsible panels
        HStack(spacing: 0) {
            // ... existing panel code unchanged
        }
        .animation(...)

        // Preview strip (always visible)
        PreviewStripView(model: model, isExpanded: $showPreview)
    }
    // ... rest unchanged
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/BlockEditorView.swift
git commit -m "feat(block-editor): integrate preview strip into editor layout"
```

---

## Phase 5: Block Templates

### Task 5.1: Create BlockTemplate Model

**Files:**
- Create: `Pault/BlockEditor/Models/BlockTemplate.swift`
- Test: `PaultTests/BlockTemplateTests.swift`

**Step 1: Write the failing test**

```swift
// PaultTests/BlockTemplateTests.swift
import Testing
@testable import Pault

struct BlockTemplateTests {

    @Test func builtInTemplates_includesCodeReview() {
        let templates = BlockTemplate.builtIn

        let codeReview = templates.first { $0.id == "code-review" }
        #expect(codeReview != nil)
        #expect(codeReview?.blocks.count == 5)
    }

    @Test func estimatedTokens_calculatesFromBlocks() {
        let template = BlockTemplate(
            id: "test",
            name: "Test",
            description: "Test template",
            blocks: [
                .init(title: "A", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "Hello world")
            ]
        )

        // ~2 tokens for "Hello world"
        #expect(template.estimatedTokens > 0)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/BlockTemplateTests 2>&1 | xcpretty`
Expected: FAIL

**Step 3: Write minimal implementation**

```swift
// Pault/BlockEditor/Models/BlockTemplate.swift
import Foundation

/// A template containing pre-configured blocks for common prompt patterns
struct BlockTemplate: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let blocks: [BlockSnapshot]

    struct BlockSnapshot: Codable {
        let title: String
        let categoryRaw: String
        let valueTypeRaw: String
        let snippet: String

        func toBlock() -> Block? {
            guard let category = BlockCategory(rawValue: categoryRaw),
                  let valueType = BlockValueType(rawValue: valueTypeRaw) else {
                return nil
            }
            return Block(title: title, category: category, valueType: valueType, snippet: snippet)
        }
    }

    var estimatedTokens: Int {
        let totalChars = blocks.reduce(0) { $0 + $1.snippet.count }
        return max(1, totalChars / 4) // Rough estimate: 4 chars per token
    }

    /// Built-in templates
    static let builtIn: [BlockTemplate] = [
        BlockTemplate(
            id: "code-review",
            name: "Code Review",
            description: "Review code for bugs, style, and improvements",
            blocks: [
                .init(title: "Code Review Expert", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are an expert code reviewer with deep knowledge of {{language}} best practices and design patterns."),
                .init(title: "Code Context", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Review the following code:\n```{{language}}\n{{code}}\n```"),
                .init(title: "Review Focus", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "Focus your review on: {{focus_areas}}"),
                .init(title: "Structured Feedback", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "Provide feedback in these sections:\n1. Summary\n2. Issues Found (with severity: Critical/Major/Minor)\n3. Suggestions for Improvement\n4. Positive Aspects"),
                .init(title: "Constructive Tone", categoryRaw: "Tone & Style", valueTypeRaw: "string", snippet: "Use a constructive and educational tone. Explain the 'why' behind each suggestion.")
            ]
        ),
        BlockTemplate(
            id: "writing-assistant",
            name: "Writing Assistant",
            description: "Help with drafting and editing text",
            blocks: [
                .init(title: "Writing Expert", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are an expert writer and editor specializing in {{writing_type}}."),
                .init(title: "Writing Task", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "{{task_description}}"),
                .init(title: "Audience", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Target audience: {{audience}}"),
                .init(title: "Tone", categoryRaw: "Tone & Style", valueTypeRaw: "string", snippet: "Write in a {{tone}} tone.")
            ]
        ),
        BlockTemplate(
            id: "data-analysis",
            name: "Data Analysis",
            description: "Analyze datasets and extract insights",
            blocks: [
                .init(title: "Data Analyst", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are a data analyst with expertise in {{domain}}."),
                .init(title: "Dataset", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Analyze the following data:\n{{data}}"),
                .init(title: "Analysis Goals", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "Focus on: {{analysis_goals}}"),
                .init(title: "Insight Format", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "Present findings as:\n1. Key Insights\n2. Supporting Data\n3. Recommendations"),
                .init(title: "Statistical Rigor", categoryRaw: "Constraints & Guardrails", valueTypeRaw: "string", snippet: "Ensure statistical validity. Note any limitations or caveats.")
            ]
        ),
        BlockTemplate(
            id: "brainstorming",
            name: "Brainstorming",
            description: "Generate ideas with structured output",
            blocks: [
                .init(title: "Creative Partner", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are a creative thinking partner who generates diverse and innovative ideas."),
                .init(title: "Topic", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Topic: {{topic}}"),
                .init(title: "Brainstorm Task", categoryRaw: "Instructions", valueTypeRaw: "string", snippet: "Generate {{count}} ideas for {{goal}}."),
                .init(title: "Idea Format", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "For each idea, provide:\n- Title\n- One-sentence description\n- Key benefit")
            ]
        ),
        BlockTemplate(
            id: "explanation",
            name: "Explanation",
            description: "Explain concepts at adjustable levels",
            blocks: [
                .init(title: "Teacher", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are an expert teacher who explains complex topics clearly."),
                .init(title: "Concept", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Explain: {{concept}}"),
                .init(title: "Audience Level", categoryRaw: "Constraints & Guardrails", valueTypeRaw: "string", snippet: "Explain for a {{level}} audience (e.g., beginner, intermediate, expert)."),
                .init(title: "Explanation Format", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "Structure as:\n1. Simple overview\n2. Key concepts\n3. Example\n4. Common misconceptions")
            ]
        ),
        BlockTemplate(
            id: "step-by-step",
            name: "Step-by-Step Guide",
            description: "Create tutorials or instructions",
            blocks: [
                .init(title: "Instructor", categoryRaw: "Role & Perspective", valueTypeRaw: "string", snippet: "You are an experienced instructor who creates clear, actionable guides."),
                .init(title: "Task", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Create a guide for: {{task}}"),
                .init(title: "Prerequisites", categoryRaw: "Inputs & Context", valueTypeRaw: "string", snippet: "Assume the reader has: {{prerequisites}}"),
                .init(title: "Guide Format", categoryRaw: "Structure & Layout", valueTypeRaw: "string", snippet: "Format as numbered steps. Each step should:\n- Start with an action verb\n- Be completable in 1-5 minutes\n- Include expected outcome"),
                .init(title: "Warnings", categoryRaw: "Constraints & Guardrails", valueTypeRaw: "string", snippet: "Highlight any warnings or common mistakes with ⚠️ markers.")
            ]
        )
    ]
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/BlockTemplateTests 2>&1 | xcpretty`
Expected: PASS

**Step 5: Commit**

```bash
git add Pault/BlockEditor/Models/BlockTemplate.swift PaultTests/BlockTemplateTests.swift
git commit -m "feat(block-editor): add BlockTemplate model with built-in templates"
```

---

### Task 5.2: Add Template Support to Slash Command Palette

**Files:**
- Modify: `Pault/BlockEditor/Views/SlashCommandPaletteView.swift`
- Modify: `Pault/BlockEditor/Models/SlashCommandState.swift`

**Step 1: No test (UI enhancement)**

**Step 2: Write implementation**

Add template section to SlashCommandPaletteView after recent blocks section:

```swift
// In SlashCommandPaletteView, add templates section:

// After recent section, before grouped results:
if state.query.isEmpty || state.query.lowercased().starts(with: "temp") {
    let filteredTemplates = BlockTemplate.builtIn.filter { template in
        state.query.isEmpty ||
        template.name.lowercased().contains(state.query.lowercased())
    }

    if !filteredTemplates.isEmpty {
        sectionHeader("Templates", icon: "rectangle.stack.fill", color: .purple)
        ForEach(filteredTemplates) { template in
            templateRow(template, isSelected: false)
        }
        Divider().padding(.vertical, 4)
    }
}

// Add templateRow helper:
@ViewBuilder
private func templateRow(_ template: BlockTemplate, isSelected: Bool) -> some View {
    Button(action: {
        // Insert all template blocks
        for blockSnapshot in template.blocks {
            if let block = blockSnapshot.toBlock() {
                model.addToCanvas(block)
            }
        }
        state.hide()
    }) {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.stack.fill")
                .font(.caption)
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.callout)

                Text("\(template.blocks.count) blocks • ~\(template.estimatedTokens) tokens")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/SlashCommandPaletteView.swift
git commit -m "feat(block-editor): add template support to slash command palette"
```

---

## Phase 6: AI Suggestions

### Task 6.1: Create BlockSuggestionEngine

**Files:**
- Create: `Pault/BlockEditor/Services/BlockSuggestionEngine.swift`
- Test: `PaultTests/BlockSuggestionEngineTests.swift`

**Step 1: Write the failing test**

```swift
// PaultTests/BlockSuggestionEngineTests.swift
import Testing
@testable import Pault

struct BlockSuggestionEngineTests {

    @Test func suggest_whenEmpty_suggestsRoleOrTemplate() {
        let canvasCategories: [ConsolidatedBlockCategory] = []

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion != nil)
        #expect(suggestion?.message.contains("Role") == true || suggestion?.message.contains("Template") == true)
    }

    @Test func suggest_whenRoleOnly_suggestsContextOrTask() {
        let canvasCategories: [ConsolidatedBlockCategory] = [.role]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion != nil)
        #expect(suggestion?.suggestedCategories.contains(.context) == true ||
                suggestion?.suggestedCategories.contains(.task) == true)
    }

    @Test func suggest_whenRoleAndTask_suggestsFormat() {
        let canvasCategories: [ConsolidatedBlockCategory] = [.role, .task]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion?.suggestedCategories.contains(.format) == true ||
                suggestion?.suggestedCategories.contains(.constraints) == true)
    }

    @Test func suggest_whenComplete_returnsNil() {
        let canvasCategories: [ConsolidatedBlockCategory] = [.role, .context, .task, .format, .constraints]

        let suggestion = BlockSuggestionEngine.suggest(canvasCategories: canvasCategories)

        #expect(suggestion == nil)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/BlockSuggestionEngineTests 2>&1 | xcpretty`
Expected: FAIL

**Step 3: Write minimal implementation**

```swift
// Pault/BlockEditor/Services/BlockSuggestionEngine.swift
import Foundation

/// Suggestion from the engine
struct BlockSuggestion {
    let message: String
    let suggestedCategories: [ConsolidatedBlockCategory]
}

/// Engine for suggesting next blocks based on canvas state
enum BlockSuggestionEngine {

    /// Suggest next blocks based on current canvas categories
    static func suggest(canvasCategories: [ConsolidatedBlockCategory]) -> BlockSuggestion? {
        let categorySet = Set(canvasCategories)

        // Empty canvas
        if categorySet.isEmpty {
            return BlockSuggestion(
                message: "Start with a Role block to define who the AI should be, or use a Template",
                suggestedCategories: [.role]
            )
        }

        // Has role but no task or context
        if categorySet.contains(.role) && !categorySet.contains(.task) && !categorySet.contains(.context) {
            return BlockSuggestion(
                message: "Add a Task to define what the AI should do, or Context for background info",
                suggestedCategories: [.task, .context]
            )
        }

        // Has role and task but no format
        if categorySet.contains(.role) && categorySet.contains(.task) && !categorySet.contains(.format) {
            return BlockSuggestion(
                message: "Consider adding a Format block for structured output",
                suggestedCategories: [.format, .constraints]
            )
        }

        // Has task but no role
        if categorySet.contains(.task) && !categorySet.contains(.role) {
            return BlockSuggestion(
                message: "Consider adding a Role to establish expertise",
                suggestedCategories: [.role]
            )
        }

        // Has most essentials but no constraints
        if categorySet.count >= 3 && !categorySet.contains(.constraints) {
            return BlockSuggestion(
                message: "Add Constraints to focus the response",
                suggestedCategories: [.constraints]
            )
        }

        // Canvas looks complete
        if categorySet.count >= 4 {
            return nil
        }

        // Default: suggest examples
        if !categorySet.contains(.examples) {
            return BlockSuggestion(
                message: "Add Examples for few-shot learning",
                suggestedCategories: [.examples]
            )
        }

        return nil
    }

    /// Check if suggestion should be shown based on token count
    static func shouldShowTokenWarning(tokenCount: Int) -> BlockSuggestion? {
        if tokenCount > 3000 {
            return BlockSuggestion(
                message: "Prompt is getting long (~\(tokenCount) tokens). Consider adding Constraints to focus.",
                suggestedCategories: [.constraints]
            )
        }
        return nil
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' -only-testing:PaultTests/BlockSuggestionEngineTests 2>&1 | xcpretty`
Expected: PASS

**Step 5: Commit**

```bash
git add Pault/BlockEditor/Services/BlockSuggestionEngine.swift PaultTests/BlockSuggestionEngineTests.swift
git commit -m "feat(block-editor): add BlockSuggestionEngine for AI suggestions"
```

---

### Task 6.2: Create SuggestionBannerView

**Files:**
- Create: `Pault/BlockEditor/Views/SuggestionBannerView.swift`

**Step 1: No test (UI component)**

**Step 2: Write implementation**

```swift
// Pault/BlockEditor/Views/SuggestionBannerView.swift
import SwiftUI

/// Inline suggestion banner shown in canvas
struct SuggestionBannerView: View {
    let suggestion: BlockSuggestion
    let onSelectCategory: (ConsolidatedBlockCategory) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.body)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(suggestion.suggestedCategories, id: \.self) { category in
                        Button(action: { onSelectCategory(category) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.caption2)
                                Text(category.rawValue)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(category.color.opacity(0.15))
                            .foregroundStyle(category.color)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    SuggestionBannerView(
        suggestion: BlockSuggestion(
            message: "Add a Task block to define what the AI should do",
            suggestedCategories: [.task, .context]
        ),
        onSelectCategory: { _ in },
        onDismiss: {}
    )
    .padding()
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/SuggestionBannerView.swift
git commit -m "feat(block-editor): add SuggestionBannerView component"
```

---

### Task 6.3: Integrate Suggestions into CompositionCanvasView

**Files:**
- Modify: `Pault/BlockEditor/Views/CompositionCanvasView.swift`

**Step 1: No test (integration)**

**Step 2: Write implementation**

Add to CompositionCanvasView:

```swift
// Add state
@State private var dismissedSuggestionHash: Int? = nil
@State private var showSuggestion = false
@AppStorage("showBlockSuggestions") private var suggestionsEnabled: Bool = true

// Add computed property
private var currentSuggestion: BlockSuggestion? {
    guard suggestionsEnabled else { return nil }

    let categories = model.canvasBlocks.map {
        ConsolidatedBlockCategory.from(legacy: $0.category)
    }

    if let suggestion = BlockSuggestionEngine.suggest(canvasCategories: categories) {
        // Don't show if user dismissed this exact suggestion
        if suggestion.message.hashValue == dismissedSuggestionHash {
            return nil
        }
        return suggestion
    }

    // Check for token warning
    return BlockSuggestionEngine.shouldShowTokenWarning(tokenCount: model.tokenEstimate)
}

// In blockList, add suggestion banner after the last block:
if showSuggestion, let suggestion = currentSuggestion {
    SuggestionBannerView(
        suggestion: suggestion,
        onSelectCategory: { category in
            // Show slash palette filtered to this category
            slashState.query = category.rawValue.lowercased()
            slashState.show()
        },
        onDismiss: {
            dismissedSuggestionHash = suggestion.message.hashValue
            withAnimation { showSuggestion = false }
        }
    )
    .transition(.opacity.combined(with: .move(edge: .top)))
    .padding(.top, 8)
}

// Add onChange to show suggestions after block added:
.onChange(of: model.canvasBlocks.count) { old, new in
    if new > old {
        // Delay showing suggestion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if currentSuggestion != nil {
                withAnimation { showSuggestion = true }
            }
        }
    }
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/CompositionCanvasView.swift
git commit -m "feat(block-editor): integrate AI suggestions into canvas"
```

---

## Phase 7: Library Update

### Task 7.1: Update BlockLibraryView with Consolidated Categories

**Files:**
- Modify: `Pault/BlockEditor/Views/BlockLibraryView.swift`

**Step 1: No test (UI update)**

**Step 2: Write implementation**

Replace the library filtering and display logic:

```swift
// Replace filteredLibrary with consolidated version:
private var filteredLibrary: [(ConsolidatedBlockCategory, [Block])] {
    ConsolidatedBlockCategory.allCases.compactMap { category in
        guard let blocks = model.consolidatedLibrary[category], !blocks.isEmpty else { return nil }

        if searchQuery.isEmpty {
            return (category, blocks)
        }

        let filtered = blocks.filter { block in
            block.title.localizedCaseInsensitiveContains(searchQuery) ||
            category.rawValue.localizedCaseInsensitiveContains(searchQuery)
        }

        return filtered.isEmpty ? nil : (category, filtered)
    }
}

// Update expandedCategories type:
@State private var expandedCategories: Set<ConsolidatedBlockCategory> = Set(ConsolidatedBlockCategory.allCases)

// Update categoryHeader to use ConsolidatedBlockCategory:
@ViewBuilder
private func categoryHeader(category: ConsolidatedBlockCategory, blockCount: Int) -> some View {
    Button(action: {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedCategories.contains(category) {
                expandedCategories.remove(category)
            } else {
                expandedCategories.insert(category)
            }
        }
    }) {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.caption)
                .foregroundStyle(category.color)

            Text(category.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(category.color)

            Text("(\(blockCount))")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Image(systemName: expandedCategories.contains(category) ? "chevron.down" : "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    .buttonStyle(.plain)
}

// Update body ForEach:
ForEach(filteredLibrary, id: \.0) { category, blocks in
    Section {
        if expandedCategories.contains(category) {
            ForEach(blocks) { block in
                BlockLibraryRowView(
                    block: block,
                    category: category,
                    compatibilityLevel: model.isLibraryBlockCompatible(block),
                    onAdd: { model.addToCanvas(block) }
                )
            }
        }
    } header: {
        categoryHeader(category: category, blockCount: blocks.count)
    }
}

// Update BlockLibraryRowView to use ConsolidatedBlockCategory:
private struct BlockLibraryRowView: View {
    let block: Block
    let category: ConsolidatedBlockCategory
    // ... rest unchanged except use category.color instead of block.category.color
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/BlockLibraryView.swift
git commit -m "feat(block-editor): update library view with consolidated categories"
```

---

### Task 7.2: Add Recent and Suggested Sections to Library

**Files:**
- Modify: `Pault/BlockEditor/Views/BlockLibraryView.swift`

**Step 1: No test (UI enhancement)**

**Step 2: Write implementation**

Add recent and suggested sections at top of library:

```swift
// Add properties
@AppStorage("recentBlockTitles") private var recentBlockTitlesData: Data = Data()

private var recentBlockTitles: [String] {
    (try? JSONDecoder().decode([String].self, from: recentBlockTitlesData)) ?? []
}

private var recentBlocks: [Block] {
    let allBlocks = model.consolidatedLibrary.values.flatMap { $0 }
    return recentBlockTitles.compactMap { title in
        allBlocks.first { $0.title == title }
    }
}

private var suggestedBlocks: [(Block, String)] {
    let categories = model.canvasBlocks.map { ConsolidatedBlockCategory.from(legacy: $0.category) }
    guard let suggestion = BlockSuggestionEngine.suggest(canvasCategories: categories) else {
        return []
    }

    var results: [(Block, String)] = []
    for category in suggestion.suggestedCategories.prefix(2) {
        if let blocks = model.consolidatedLibrary[category], let block = blocks.first {
            results.append((block, category.rawValue))
        }
    }
    return results
}

// In body, add sections before main categories:
ScrollView {
    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
        // Recent section
        if !recentBlocks.isEmpty && searchQuery.isEmpty {
            Section {
                ForEach(recentBlocks.prefix(3)) { block in
                    BlockLibraryRowView(
                        block: block,
                        category: ConsolidatedBlockCategory.from(legacy: block.category),
                        compatibilityLevel: model.isLibraryBlockCompatible(block),
                        onAdd: { model.addToCanvas(block) }
                    )
                }
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Recent")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }

        // Suggested section
        if !suggestedBlocks.isEmpty && searchQuery.isEmpty {
            Section {
                ForEach(suggestedBlocks, id: \.0.id) { block, reason in
                    HStack {
                        BlockLibraryRowView(
                            block: block,
                            category: ConsolidatedBlockCategory.from(legacy: block.category),
                            compatibilityLevel: model.isLibraryBlockCompatible(block),
                            onAdd: { model.addToCanvas(block) }
                        )
                    }
                }
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("Suggested")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.yellow)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }

        // Main categories
        ForEach(filteredLibrary, id: \.0) { ... }
    }
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/BlockLibraryView.swift
git commit -m "feat(block-editor): add recent and suggested sections to library"
```

---

## Phase 8: Final Integration & Polish

### Task 8.1: Update Placeholder Hints in BlockInputFieldView

**Files:**
- Modify: `Pault/BlockEditor/Views/BlockInputFieldView.swift`

**Step 1: No test (UI enhancement)**

**Step 2: Read current file and add hints**

Add placeholder hints below input fields:

```swift
// Add hint text below the text field
VStack(alignment: .leading, spacing: 4) {
    // Existing TextField...

    if let hint = placeholderHint(for: placeholder) {
        HStack(spacing: 4) {
            Image(systemName: "lightbulb")
                .font(.caption2)
            Text(hint)
                .font(.caption2)
        }
        .foregroundStyle(.tertiary)
    }
}

// Add helper function
private func placeholderHint(for placeholder: String) -> String? {
    let hints: [String: String] = [
        "role": "e.g., \"senior developer\", \"legal expert\"",
        "domain": "e.g., \"machine learning\", \"finance\"",
        "language": "e.g., \"Python\", \"TypeScript\"",
        "task": "What should the AI do?",
        "context": "Background information",
        "format": "e.g., \"bullet points\", \"JSON\"",
        "tone": "e.g., \"professional\", \"casual\"",
        "audience": "Who will read this?",
        "years": "Number of years",
        "count": "Number of items",
        "level": "e.g., \"beginner\", \"expert\""
    ]
    return hints[placeholder.lowercased()]
}
```

**Step 3: Build to verify**

Run: `xcodebuild build -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Pault/BlockEditor/Views/BlockInputFieldView.swift
git commit -m "feat(block-editor): add placeholder hints to input fields"
```

---

### Task 8.2: Run Full Test Suite

**Files:** None (verification)

**Step 1: Run all tests**

Run: `xcodebuild test -scheme Pault -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: All tests pass

**Step 2: Build release**

Run: `xcodebuild build -scheme Pault -configuration Release -destination 'platform=macOS' 2>&1 | xcpretty`
Expected: BUILD SUCCEEDED

**Step 3: Commit if any fixes needed**

```bash
git status
# If clean, no commit needed
```

---

### Task 8.3: Manual Verification

**Verification checklist:**

1. **Slash command palette**
   - [ ] Type `/` in canvas → palette appears
   - [ ] `⌘K` → palette appears
   - [ ] Fuzzy search works (type "exp" finds "Expert")
   - [ ] Arrow keys navigate, Enter selects
   - [ ] Escape dismisses
   - [ ] Recent blocks appear at top
   - [ ] Templates section shows

2. **Inline block editing**
   - [ ] Block shows red dot when unfilled
   - [ ] Block shows green dot when all placeholders filled
   - [ ] Click block to expand/collapse
   - [ ] Tab moves between fields

3. **Consolidated library**
   - [ ] Shows 7 categories instead of 20+
   - [ ] Recent section at top
   - [ ] Suggested section shows relevant blocks
   - [ ] Categories collapse/expand

4. **Preview strip**
   - [ ] Always visible at bottom
   - [ ] Shows truncated preview text
   - [ ] Token count with color coding
   - [ ] Placeholder fill status
   - [ ] `⌘P` toggles full preview

5. **Templates**
   - [ ] `/template` shows template list
   - [ ] Clicking template inserts all blocks

6. **AI suggestions**
   - [ ] Empty canvas suggests Role
   - [ ] After Role, suggests Task/Context
   - [ ] Dismiss button works
   - [ ] Clicking suggestion category opens palette

---

## Summary

| Phase | Tasks | New Files | Modified Files |
|-------|-------|-----------|----------------|
| 1 | Category consolidation | 2 | 1 |
| 2 | Status indicators | 1 | 2 |
| 3 | Slash command palette | 2 | 1 |
| 4 | Preview strip | 1 | 1 |
| 5 | Templates | 1 | 1 |
| 6 | AI suggestions | 2 | 1 |
| 7 | Library update | 0 | 1 |
| 8 | Polish & verification | 0 | 1 |

**Total: 9 new files, 9 modified files, ~1500 lines of code**

**Estimated implementation time:** 8 phases × ~30 min = ~4 hours
