//
//  MiniChatTests.swift
//  MiniChatTests
//
//  Created by Krystian Synakowski on 05/06/2026.
//

import Testing
@testable import MiniChat

struct MiniChatTests {

    @Test func example() async throws {
        // Basic sanity test
        #expect(true == true)
    }

    @Test func test_parseSSEDataFull_parses_tool_calls() async throws {
        let client = await MainActor.run { MiniMaxAPIClient() }
        let sample = "{"
            + "\"choices\":[{\"delta\":{\"reasoning_content\":\"Thinking...\",\"tool_calls\":[{\"index\":0,\"id\":\"call1\",\"function\":{\"name\":\"web_search\",\"arguments\":\"{\\\"query\\\":\\\"ficus ginseng care\\\"}\"}}]}}]}"
        let result = await MainActor.run { client.debug_parseSSEDataFull(sample) }
        #expect(result != nil)
        #expect(result?.toolCallsCount == 1)
        #expect(result?.reasoning.contains("Thinking") == true)
    }

}
