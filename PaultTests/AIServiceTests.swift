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

    // 1. test_proxyUnreachable_showsInlineError -- Verifies graceful error when proxy is unreachable (R2.5)
    func test_proxyUnreachable_showsInlineError() async throws {
        XCTFail("Wave 0 stub -- implement in Plan 04-01")
    }

    // 2. test_rateLimitResponse_parsesRetryAfter -- Verifies 429 response parsing extracts Retry-After value (R2.5)
    func test_rateLimitResponse_parsesRetryAfter() async throws {
        XCTFail("Wave 0 stub -- implement in Plan 04-01")
    }

    // 3. test_ollamaBypassesProxy_directLocalhost -- Verifies Ollama provider routes directly to localhost, not proxy (R2.5)
    func test_ollamaBypassesProxy_directLocalhost() async throws {
        XCTFail("Wave 0 stub -- implement in Plan 04-01")
    }

    // 4. test_streamImprove_returnsStreamEvents -- Verifies streamImprove returns StreamEvent tokens (R2.1)
    func test_streamImprove_returnsStreamEvents() async throws {
        XCTFail("Wave 0 stub -- implement in Plan 04-02")
    }

    // 5. test_claudeRoutesViaProxy_withHeaders -- Verifies Claude requests include X-Provider, X-Provider-Key, X-Storekit-JWS headers (R2.5)
    func test_claudeRoutesViaProxy_withHeaders() async throws {
        XCTFail("Wave 0 stub -- implement in Plan 04-01")
    }

    // 6. test_qualityScoreReturnsTips -- Verifies QualityScore includes tips array (R2.4)
    func test_qualityScoreReturnsTips() async throws {
        XCTFail("Wave 0 stub -- implement in Plan 04-02")
    }
}
