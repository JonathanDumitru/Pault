// PaultTests/AIServiceTests.swift
import XCTest
@testable import Pault

final class AIServiceTests: XCTestCase {

    func test_missingAPIKey_throwsMissingAPIKey() async throws {
        // No API key stored, so should throw missingAPIKey
        let service = AIService()
        let config = AIConfig(provider: .openai, model: "gpt-4o")
        do {
            _ = try await service.improve(content: "test", instruction: "improve", config: config)
            XCTFail("Expected AIError.missingAPIKey to be thrown")
        } catch AIError.missingAPIKey {
            // Expected — pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_qualityScore_overallCalculation() {
        let score = QualityScore(
            clarity: 8,
            specificity: 6,
            roleDefinition: 7,
            outputFormat: 9,
            clarityReason: "Clear",
            specificityReason: "Specific",
            roleDefinitionReason: "Has role",
            outputFormatReason: "Well formatted"
        )
        XCTAssertEqual(score.overall, 7.5, accuracy: 0.001)
    }

    func test_aiConfig_defaults_containAllProviders() {
        XCTAssertNotNil(AIConfig.defaults[.claude])
        XCTAssertNotNil(AIConfig.defaults[.openai])
        XCTAssertNotNil(AIConfig.defaults[.ollama])
    }
}
