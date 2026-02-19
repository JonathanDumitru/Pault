import XCTest
@testable import Pault

final class AIServiceTests: XCTestCase {

    // Test 1: No API key stored → AIError.missingAPIKey is thrown
    func test_missingAPIKey_throwsMissingAPIKey() async throws {
        let service = AIService()
        let config = AIConfig(provider: .openai, model: "gpt-4o")
        do {
            _ = try await service.improve(prompt: "test", config: config)
            XCTFail("Expected AIError.missingAPIKey to be thrown")
        } catch AIError.missingAPIKey {
            // Expected — pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // Test 2: QualityScore.overall computes correctly — 8 + 6 + 7 + 9 = 30 / 4 = 7.5
    func test_qualityScore_overallCalculation() {
        let score = QualityScore(
            clarity: 8,
            specificity: 6,
            completeness: 7,
            conciseness: 9
        )
        XCTAssertEqual(score.overall, 7.5, accuracy: 0.001)
    }

    // Test 3: AIConfig.defaults contains entries for all 3 providers
    func test_aiConfig_defaults_containAllProviders() {
        for provider in AIConfig.Provider.allCases {
            XCTAssertNotNil(AIConfig.defaults[provider], "Missing default for provider: \(provider.rawValue)")
        }
    }
}
