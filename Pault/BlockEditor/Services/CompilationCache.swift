//
//  CompilationCache.swift
//  Pault
//
//  Caching service for compiled templates (from Schemap)
//

import Foundation

/// Cache entry for compiled templates
struct CompilationCacheEntry {
    let compiledTemplate: String
    let filledExample: String
    let rawTemplate: String
    let tokenEstimate: Int
    let cacheKey: String
    let timestamp: Date
}

/// Service for caching compiled templates to improve performance
final class CompilationCache {
    static let shared = CompilationCache()

    private var cache: [String: CompilationCacheEntry] = [:]
    private let maxCacheSize = 50 // Maximum number of cached entries
    private let cacheTimeout: TimeInterval = 300 // 5 minutes

    private init() {}

    /// Generate cache key from blocks and inputs
    func generateCacheKey(blocks: [BlockData], blockInputs: [UUID: [String: String]]) -> String {
        // Create a hash from blocks and inputs
        var keyComponents: [String] = []

        // Add block IDs and snippets
        for block in blocks {
            keyComponents.append("\(block.id.uuidString):\(block.snippet.hashValue)")
        }

        // Add input values
        for (blockID, inputs) in blockInputs.sorted(by: { $0.key.uuidString < $1.key.uuidString }) {
            keyComponents.append("\(blockID.uuidString):")
            for (key, value) in inputs.sorted(by: { $0.key < $1.key }) {
                keyComponents.append("\(key)=\(value.hashValue)")
            }
        }

        return keyComponents.joined(separator: "|")
    }

    /// Get cached compilation result
    func get(key: String) -> CompilationCacheEntry? {
        guard let entry = cache[key] else { return nil }

        // Check if cache entry is still valid
        if Date().timeIntervalSince(entry.timestamp) > cacheTimeout {
            cache.removeValue(forKey: key)
            return nil
        }

        return entry
    }

    /// Store compilation result in cache
    func set(key: String, entry: CompilationCacheEntry) {
        // Remove oldest entries if cache is full
        if cache.count >= maxCacheSize {
            let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            for (oldKey, _) in sortedEntries.prefix(cache.count - maxCacheSize + 1) {
                cache.removeValue(forKey: oldKey)
            }
        }

        cache[key] = entry
    }

    /// Clear all cache entries
    func clear() {
        cache.removeAll()
    }

    /// Clear expired cache entries
    func clearExpired() {
        let now = Date()
        cache = cache.filter { now.timeIntervalSince($0.value.timestamp) <= cacheTimeout }
    }
}
