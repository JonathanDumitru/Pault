import Foundation
import SwiftUI

struct ProxyConfig {
    static var baseURL: String {
        UserDefaults.standard.string(forKey: "ai.proxy.baseURL") ?? "https://pault-proxy.PLACEHOLDER.workers.dev"
    }
    
    static var enableCaching: Bool {
        UserDefaults.standard.object(forKey: "ai.proxy.enableCaching") as? Bool ?? true
    }
    
    static var isConfigured: Bool {
        !baseURL.contains("PLACEHOLDER")
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
