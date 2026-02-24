//
//  RenderMode.swift
//  Pault
//
//  Render mode enumeration (from Schemap)
//

import Foundation

/// Render mode for snippets
enum RenderMode: String, CaseIterable, Identifiable {
    case inline = "Inline"
    case reference = "Reference"
    case implicit = "Implicit"

    var id: String { rawValue }
}
