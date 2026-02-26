//
//  EditingMode.swift
//  Pault
//
//  Editing mode for prompt editor (text vs blocks)
//

import Foundation

/// The active editing mode for a prompt
enum EditingMode: String, Codable {
    case text
    case blocks
}
