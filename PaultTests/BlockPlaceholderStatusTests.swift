//
//  BlockPlaceholderStatusTests.swift
//  PaultTests
//
//  Tests for BlockPlaceholderStatus enum.
//

import Testing
@testable import Pault

struct BlockPlaceholderStatusTests {

    @Test func unfilled_whenNoInputsProvided() {
        let snippet = "ROLE: {{role}} with {{years}} experience"
        let inputs: [String: String] = [:]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .unfilled)
    }

    @Test func partial_whenSomeInputsFilled() {
        let snippet = "ROLE: {{role}} with {{years}} experience"
        let inputs = ["role": "developer"]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .partial)
    }

    @Test func complete_whenAllInputsFilled() {
        let snippet = "ROLE: {{role}} with {{years}} experience"
        let inputs = ["role": "developer", "years": "10"]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .complete)
    }

    @Test func complete_whenNoPlaceholders() {
        let snippet = "You are a helpful assistant."
        let inputs: [String: String] = [:]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .complete)
    }

    @Test func unfilled_whenInputsAreWhitespaceOnly() {
        let snippet = "ROLE: {{role}}"
        let inputs = ["role": "   "]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .unfilled)
    }

    @Test func partial_whenSomeInputsAreWhitespace() {
        let snippet = "ROLE: {{role}} with {{years}} experience"
        let inputs = ["role": "developer", "years": "  "]

        let status = BlockPlaceholderStatus.calculate(snippet: snippet, inputs: inputs)

        #expect(status == .partial)
    }
}
