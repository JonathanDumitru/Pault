//
//  BlockSyncState.swift
//  Pault
//
//  Sync state between block composition and compiled text
//

import Foundation

/// Whether the block composition is in sync with the compiled prompt text
enum BlockSyncState: String, Codable {
    case synced
    case diverged
}
