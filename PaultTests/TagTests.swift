//
//  TagTests.swift
//  PaultTests
//

import Foundation
import Testing
import SwiftData
@testable import Pault

struct TagTests {

    @Test func tagInitializesWithDefaults() async throws {
        let tag = Tag(name: "work")

        #expect(tag.name == "work")
        #expect(tag.color == "blue")
        #expect(tag.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test func tagInitializesWithCustomColor() async throws {
        let tag = Tag(name: "urgent", color: "red")

        #expect(tag.name == "urgent")
        #expect(tag.color == "red")
    }
}
