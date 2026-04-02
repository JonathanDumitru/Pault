import Foundation
import SwiftUI

struct ProxyConfig {
    @AppStorage("proxy.baseURL") private static var storedBaseURL: String = "https://pault-proxy.PLACEHOLDER.workers.dev"
    
    static var baseURL: String {
        get { storedBaseURL }
        set { storedBaseURL = newValue }
    }
    
    static var isConfigured: Bool {
        !storedBaseURL.contains("PLACEHOLDER")
    }
}

enum StreamEvent: Equatable {
    case token(String)
    case metadata(inputTokens: Int, outputTokens: Int, estimatedCostUSD: Double)
}

struct CallMetadata: Codable {
    var inputTokens: Int
    var outputTokens: Int
    var estimatedCostUSD: Double
}
