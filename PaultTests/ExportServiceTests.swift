//
//  ExportServiceTests.swift
//  PaultTests
//

import XCTest
@testable import Pault

final class ExportServiceTests: XCTestCase {

    // MARK: - v2 DTO encode/decode

    func testV2RecordEncodeDecode() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let record = PromptExportRecord(
            id: "550E8400-E29B-41D4-A716-446655440000",
            title: "Test Prompt",
            content: "Prompt body here.",
            isFavorite: true,
            isArchived: false,
            createdAt: 1_700_000_000,
            updatedAt: 1_700_100_000,
            tags: ["swift", "tools"],
            templateVariables: [
                VariableExportRecord(name: "lang", defaultValue: "Swift", sortOrder: 0)
            ],
            blockCompositionData: "eyJibG9ja3MiOltdfQ==".data(using: .utf8),
            qualityScore: 85,
            lastUsedAt: 1_700_200_000,
            editingModeRaw: "blocks",
            variantB: "Alternative content",
            attachmentFileNames: ["image.png", "doc.pdf"]
        )

        let data = try encoder.encode(record)
        let decoded = try JSONDecoder().decode(PromptExportRecord.self, from: data)

        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.title, record.title)
        XCTAssertEqual(decoded.content, record.content)
        XCTAssertEqual(decoded.isFavorite, record.isFavorite)
        XCTAssertEqual(decoded.isArchived, record.isArchived)
        XCTAssertEqual(decoded.createdAt, record.createdAt)
        XCTAssertEqual(decoded.updatedAt, record.updatedAt)
        XCTAssertEqual(decoded.tags, record.tags)
        XCTAssertEqual(decoded.templateVariables.count, 1)
        XCTAssertEqual(decoded.templateVariables[0].name, "lang")
        XCTAssertEqual(decoded.qualityScore, 85)
        XCTAssertEqual(decoded.lastUsedAt, 1_700_200_000)
        XCTAssertEqual(decoded.editingModeRaw, "blocks")
        XCTAssertEqual(decoded.variantB, "Alternative content")
        XCTAssertEqual(decoded.attachmentFileNames, ["image.png", "doc.pdf"])
        XCTAssertNotNil(decoded.blockCompositionData)
    }

    // MARK: - v1 backward compatibility

    func testV1BundleDecodesAsV2() throws {
        // A v1-shaped JSON bundle (no v2 optional fields)
        let v1JSON = """
        {
          "version": 1,
          "exportedAt": 1700000000,
          "prompts": [
            {
              "id": "550E8400-E29B-41D4-A716-446655440000",
              "title": "Old Prompt",
              "content": "Some content",
              "isFavorite": false,
              "isArchived": false,
              "createdAt": 1700000000,
              "updatedAt": 1700100000,
              "tags": ["legacy"],
              "templateVariables": []
            }
          ]
        }
        """

        let data = v1JSON.data(using: .utf8)!
        let bundle = try JSONDecoder().decode(PromptExportBundle.self, from: data)

        XCTAssertEqual(bundle.version, 1)
        XCTAssertEqual(bundle.prompts.count, 1)

        let record = bundle.prompts[0]
        XCTAssertEqual(record.title, "Old Prompt")

        // All v2 optionals must be nil (not crash)
        XCTAssertNil(record.blockCompositionData)
        XCTAssertNil(record.qualityScore)
        XCTAssertNil(record.lastUsedAt)
        XCTAssertNil(record.editingModeRaw)
        XCTAssertNil(record.variantB)
        XCTAssertNil(record.attachmentFileNames)

        // collectionName on the bundle should also be nil
        XCTAssertNil(bundle.collectionName)
    }

    // MARK: - v2 bundle collectionName

    func testBundleV2IncludesCollectionName() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let bundle = PromptExportBundle(
            version: 2,
            exportedAt: 1_700_000_000,
            prompts: [],
            collectionName: "My Collection"
        )

        let data = try encoder.encode(bundle)
        let decoded = try JSONDecoder().decode(PromptExportBundle.self, from: data)

        XCTAssertEqual(decoded.version, 2)
        XCTAssertEqual(decoded.collectionName, "My Collection")
    }

    func testBundleV2CollectionNameNilWhenAbsent() throws {
        let bundle = PromptExportBundle(
            version: 2,
            exportedAt: 1_700_000_000,
            prompts: [],
            collectionName: nil
        )

        let data = try JSONEncoder().encode(bundle)
        let decoded = try JSONDecoder().decode(PromptExportBundle.self, from: data)
        XCTAssertNil(decoded.collectionName)
    }

    // MARK: - Slugify (via MarkdownFrontmatterParser)

    func testSlugify() {
        XCTAssertEqual(MarkdownFrontmatterParser.slugify("Hello World!", existing: []), "hello-world")
        XCTAssertEqual(MarkdownFrontmatterParser.slugify("Swift 5.9 Macros", existing: []), "swift-5-9-macros")
        XCTAssertEqual(MarkdownFrontmatterParser.slugify("---leading hyphens---", existing: []), "leading-hyphens")
    }

    func testSlugifyCollision() {
        var used: Set<String> = []
        let slug1 = MarkdownFrontmatterParser.slugify("Test Prompt", existing: used)
        XCTAssertEqual(slug1, "test-prompt")
        used.insert(slug1)

        let slug2 = MarkdownFrontmatterParser.slugify("Test Prompt", existing: used)
        XCTAssertEqual(slug2, "test-prompt-2")
        used.insert(slug2)

        let slug3 = MarkdownFrontmatterParser.slugify("Test Prompt", existing: used)
        XCTAssertEqual(slug3, "test-prompt-3")
    }
}
