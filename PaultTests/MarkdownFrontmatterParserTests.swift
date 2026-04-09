//
//  MarkdownFrontmatterParserTests.swift
//  PaultTests
//

import XCTest
@testable import Pault

final class MarkdownFrontmatterParserTests: XCTestCase {

    // MARK: - Helpers

    private func makeRecord(
        id: String = "550E8400-E29B-41D4-A716-446655440000",
        title: String = "Test Prompt",
        content: String = "This is the prompt body.",
        tags: [String] = ["swift", "ios"],
        isFavorite: Bool = true,
        isArchived: Bool = false,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date = Date(timeIntervalSince1970: 1_700_100_000),
        qualityScore: Int? = 75,
        variables: [(name: String, defaultValue: String)] = [("lang", "Swift"), ("platform", "macOS")]
    ) -> PromptExportRecord {
        PromptExportRecord(
            id: id,
            title: title,
            content: content,
            isFavorite: isFavorite,
            isArchived: isArchived,
            createdAt: createdAt.timeIntervalSince1970,
            updatedAt: updatedAt.timeIntervalSince1970,
            tags: tags,
            templateVariables: variables.enumerated().map { i, v in
                VariableExportRecord(name: v.name, defaultValue: v.defaultValue, sortOrder: i)
            },
            blockCompositionData: nil,
            qualityScore: qualityScore,
            lastUsedAt: nil,
            editingModeRaw: nil,
            variantB: nil,
            attachmentFileNames: nil
        )
    }

    // MARK: - Serialize / Parse Round-trip

    func testSerializeRoundTrip() throws {
        let original = makeRecord()
        let markdown = MarkdownFrontmatterParser.serialize(record: original)
        let parsed = MarkdownFrontmatterParser.parse(markdown: markdown, filename: "test.md")

        XCTAssertEqual(parsed.title, original.title)
        XCTAssertEqual(parsed.content.trimmingCharacters(in: .whitespacesAndNewlines),
                       original.content.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertEqual(parsed.tags.sorted(), original.tags.sorted())
        XCTAssertEqual(parsed.isFavorite, original.isFavorite)
        XCTAssertEqual(parsed.isArchived, original.isArchived)
        XCTAssertEqual(parsed.qualityScore, original.qualityScore)
        XCTAssertEqual(parsed.id, original.id)

        // Dates — compare within 1 second to tolerate ISO8601 string truncation
        let parsedCreated = try XCTUnwrap(parsed.createdAt)
        let parsedUpdated = try XCTUnwrap(parsed.updatedAt)
        XCTAssertEqual(parsedCreated.timeIntervalSince1970,
                       Date(timeIntervalSince1970: original.createdAt).timeIntervalSince1970,
                       accuracy: 1.0)
        XCTAssertEqual(parsedUpdated.timeIntervalSince1970,
                       Date(timeIntervalSince1970: original.updatedAt).timeIntervalSince1970,
                       accuracy: 1.0)

        // Variables
        XCTAssertEqual(parsed.variables.count, 2)
        XCTAssertEqual(parsed.variables[0].name, "lang")
        XCTAssertEqual(parsed.variables[0].defaultValue, "Swift")
        XCTAssertEqual(parsed.variables[1].name, "platform")
        XCTAssertEqual(parsed.variables[1].defaultValue, "macOS")
    }

    // MARK: - Plain Markdown Parsing

    func testParsePlainMarkdown() {
        let markdown = """
        # My Prompt Title

        This is the body content.
        """
        let parsed = MarkdownFrontmatterParser.parse(markdown: markdown, filename: "my-prompt.md")
        XCTAssertEqual(parsed.title, "My Prompt Title")
        XCTAssertTrue(parsed.content.contains("This is the body content."))
        XCTAssertTrue(parsed.tags.isEmpty)
        XCTAssertFalse(parsed.isFavorite)
        XCTAssertFalse(parsed.isArchived)
        XCTAssertNil(parsed.qualityScore)
    }

    func testParsePlainMarkdownFallbackToFilename() {
        let markdown = "Just some text with no heading."
        let parsed = MarkdownFrontmatterParser.parse(markdown: markdown, filename: "my-prompt-file.md")
        XCTAssertEqual(parsed.title, "my-prompt-file")
    }

    // MARK: - Edge Cases

    func testParseQuotedTitleWithColon() throws {
        let record = makeRecord(title: "URL: https://example.com")
        let markdown = MarkdownFrontmatterParser.serialize(record: record)
        let parsed = MarkdownFrontmatterParser.parse(markdown: markdown, filename: "test.md")
        XCTAssertEqual(parsed.title, "URL: https://example.com")
    }

    func testParseEmptyTags() throws {
        let record = makeRecord(tags: [])
        let markdown = MarkdownFrontmatterParser.serialize(record: record)
        let parsed = MarkdownFrontmatterParser.parse(markdown: markdown, filename: "test.md")
        XCTAssertTrue(parsed.tags.isEmpty)
    }

    func testParseMissingOptionalFields() throws {
        let record = makeRecord(qualityScore: nil, variables: [])
        let markdown = MarkdownFrontmatterParser.serialize(record: record)
        let parsed = MarkdownFrontmatterParser.parse(markdown: markdown, filename: "test.md")
        XCTAssertNil(parsed.qualityScore)
        XCTAssertTrue(parsed.variables.isEmpty)
    }

    // MARK: - Slugify

    func testSlugify() {
        XCTAssertEqual(MarkdownFrontmatterParser.slugify("Hello World!", existing: []), "hello-world")
        XCTAssertEqual(MarkdownFrontmatterParser.slugify("  leading and trailing  ", existing: []), "leading-and-trailing")
        XCTAssertEqual(MarkdownFrontmatterParser.slugify("Multiple   Spaces", existing: []), "multiple-spaces")
        XCTAssertEqual(MarkdownFrontmatterParser.slugify("Special!@#$%Chars", existing: []), "special-chars")
        XCTAssertEqual(MarkdownFrontmatterParser.slugify("Already-hyphenated", existing: []), "already-hyphenated")
    }

    func testSlugifyCollision() {
        var used: Set<String> = []
        let slug1 = MarkdownFrontmatterParser.slugify("My Prompt", existing: used)
        XCTAssertEqual(slug1, "my-prompt")
        used.insert(slug1)

        let slug2 = MarkdownFrontmatterParser.slugify("My Prompt", existing: used)
        XCTAssertEqual(slug2, "my-prompt-2")
        used.insert(slug2)

        let slug3 = MarkdownFrontmatterParser.slugify("My Prompt", existing: used)
        XCTAssertEqual(slug3, "my-prompt-3")
    }

    // MARK: - Serialize output format

    func testSerializeContainsFrontmatterDelimiters() {
        let record = makeRecord()
        let markdown = MarkdownFrontmatterParser.serialize(record: record)
        XCTAssertTrue(markdown.hasPrefix("---\n"), "Markdown should start with YAML frontmatter delimiter")
        XCTAssertTrue(markdown.contains("\n---\n"), "Markdown should have closing YAML frontmatter delimiter")
    }

    func testSerializeContainsTitleAsH1() {
        let record = makeRecord(title: "My Test Prompt")
        let markdown = MarkdownFrontmatterParser.serialize(record: record)
        XCTAssertTrue(markdown.contains("# My Test Prompt"), "Markdown body should have H1 title")
    }
}
