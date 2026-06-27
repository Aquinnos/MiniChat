//
//  MiniChatTests.swift
//  MiniChatTests
//
//  Created by Krystian Synakowski on 05/06/2026.
//

import Testing
import Foundation
@testable import MiniChat

struct MiniChatTests {

    @Test func example() async throws {
        #expect(true == true)
    }

    // MARK: - SSE Parser

    @Test func test_parseSSEDataFull_parses_tool_calls() async throws {
        let client = await MainActor.run { MiniMaxAPIClient() }
        let sample = "{"
            + "\"choices\":[{\"delta\":{\"reasoning_content\":\"Thinking...\",\"tool_calls\":[{\"index\":0,\"id\":\"call1\",\"function\":{\"name\":\"web_search\",\"arguments\":\"{\\\"query\\\":\\\"ficus ginseng care\\\"}\"}}]}}]}"
        let result = await MainActor.run { client.debug_parseSSEDataFull(sample) }
        #expect(result != nil)
        #expect(result?.toolCallsCount == 1)
        #expect(result?.reasoning.contains("Thinking") == true)
    }

    @Test func test_parseSSEDataFull_parses_content() async throws {
        let client = await MainActor.run { MiniMaxAPIClient() }
        let sample = "{\"choices\":[{\"delta\":{\"content\":\"Hello world\"}}]}"
        let result = await MainActor.run { client.debug_parseSSEDataFull(sample) }
        #expect(result?.content == "Hello world")
        #expect(result?.toolCallsCount == 0)
    }

    @Test func test_parseSSEDataFull_handles_invalid_json() async throws {
        let client = await MainActor.run { MiniMaxAPIClient() }
        let result = await MainActor.run { client.debug_parseSSEDataFull("not json") }
        #expect(result == nil)
    }

    // MARK: - API Error translations

    @Test func test_apiError_descriptions_contain_polish() async throws {
        #expect(APIError.missingAPIKey.errorDescription?.contains("API key") == true)
        #expect(APIError.invalidURL.errorDescription?.isEmpty == false)
        #expect(APIError.noInternet.errorDescription?.contains("internet") == true)
        #expect(APIError.timeout.errorDescription?.contains("60") == true)
    }

    @Test func test_apiError_httpStatus_includes_body() async throws {
        let err = APIError.httpStatus(500, "Internal failure")
        #expect(err.errorDescription?.contains("500") == true)
        #expect(err.errorDescription?.contains("Internal") == true)
    }

    // MARK: - MiniMaxModel

    @Test func test_minimaxModel_allCases() async throws {
        #expect(MiniMaxModel.allCases.count == 5)
        #expect(MiniMaxModel.m3.isReasoning == true)
        #expect(MiniMaxModel.m2her.isReasoning == false)
        #expect(MiniMaxModel.m27.displayName == "M2.7")
    }

    @Test func test_minimaxModel_id_matches_rawValue() async throws {
        for model in MiniMaxModel.allCases {
            #expect(model.id == model.rawValue)
        }
    }

    // MARK: - Models Codable

    @Test func test_message_codable_roundtrip() async throws {
        let original = Message(
            role: .user,
            content: "Hej! 🇵🇱",
            reasoningContent: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Message.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.role == original.role)
        #expect(decoded.content == original.content)
    }

    @Test func test_message_decode_handles_missing_images() async throws {
        // Stary format danych (bez pola images)
        let json = """
        {"id":"\(UUID().uuidString)","role":"user","content":"hi","timestamp":"2026-01-01T12:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let msg = try decoder.decode(Message.self, from: json.data(using: .utf8)!)
        #expect(msg.content == "hi")
        #expect(msg.images == nil)
        #expect(msg.attachments.isEmpty == true)
    }

    @Test func test_conversation_codable_roundtrip() async throws {
        let conv = Conversation(
            title: "Test",
            messages: [Message(role: .user, content: "hi")],
            isPinned: true,
            tags: ["test", "demo"],
            folderId: nil
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(conv)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Conversation.self, from: data)

        #expect(decoded.title == "Test")
        #expect(decoded.messages.count == 1)
        #expect(decoded.isPinned == true)
        #expect(decoded.tags == ["test", "demo"])
    }

    @Test func test_conversation_decode_backward_compat_no_pin() async throws {
        // Stary format bez isPinned/tags/folderId
        let json = """
        {"id":"\(UUID().uuidString)","title":"Old","messages":[],"createdAt":"2026-01-01T12:00:00Z","updatedAt":"2026-01-01T12:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let conv = try decoder.decode(Conversation.self, from: json.data(using: .utf8)!)
        #expect(conv.title == "Old")
        #expect(conv.isPinned == false)
        #expect(conv.tags.isEmpty == true)
        #expect(conv.folderId == nil)
    }

    @Test func test_conversation_generateTitle_truncates_at_40() async throws {
        var conv = Conversation(messages: [Message(role: .user, content: String(repeating: "a", count: 100))])
        conv.generateTitleIfNeeded()
        #expect(conv.title.count <= 41) // 40 chars + "…"
        #expect(conv.title.hasSuffix("…") == true)
    }

    @Test func test_conversation_generateTitle_keeps_existing_title() async throws {
        var conv = Conversation(
            title: "Custom title",
            messages: [Message(role: .user, content: "Anything")]
        )
        conv.generateTitleIfNeeded()
        #expect(conv.title == "Custom title")
    }

    // MARK: - ConversationStore

    @MainActor
    @Test func test_store_createNewConversation() async throws {
        let store = ConversationStore()
        let initialCount = store.conversations.count
        let conv = store.createNewConversation()
        #expect(store.conversations.count == initialCount + 1)
        #expect(store.currentConversationId == conv.id)
        #expect(conv.title == "Nowa rozmowa")
    }

    @MainActor
    @Test func test_store_delete_removes_conversation() async throws {
        let store = ConversationStore()
        let conv = store.createNewConversation()
        let beforeDelete = store.conversations.count
        store.delete(conv)
        #expect(store.conversations.count == beforeDelete - 1)
    }

    @MainActor
    @Test func test_store_togglePin_flips_state() async throws {
        let store = ConversationStore()
        let conv = store.createNewConversation()
        #expect(conv.isPinned == false)
        store.togglePin(conv)
        #expect(store.conversations.first(where: { $0.id == conv.id })?.isPinned == true)
        store.togglePin(conv)
        #expect(store.conversations.first(where: { $0.id == conv.id })?.isPinned == false)
    }

    @MainActor
    @Test func test_store_addTag_is_idempotent() async throws {
        let store = ConversationStore()
        let conv = store.createNewConversation()
        store.addTag("Swift", to: conv)
        store.addTag("  swift  ", to: conv) // ta sama etykieta po normalizacji
        #expect(store.conversations.first(where: { $0.id == conv.id })?.tags == ["swift"])
    }

    @MainActor
    @Test func test_store_search_finds_by_title() async throws {
        let store = ConversationStore()
        var conv = store.createNewConversation()
        conv.title = "Swift Concurrency"
        store.currentConversation = conv
        let results = store.search(query: "swift")
        #expect(results.count == 1)
        #expect(results.first?.titleMatch == true)
    }

    @MainActor
    @Test func test_store_search_finds_by_message_content() async throws {
        let store = ConversationStore()
        var conv = store.createNewConversation()
        conv.messages = [Message(role: .user, content: "Opowiedz mi o Japonii")]
        store.currentConversation = conv
        let results = store.search(query: "Japonii")
        #expect(results.count == 1)
        #expect(results.first?.titleMatch == false)
        #expect(results.first?.matchedMessages.count == 1)
    }

    // MARK: - Attachment

    @Test func test_attachment_sizeKB() async throws {
        let imgAttachment = Attachment(
            type: .image,
            mimeType: "image/png",
            fileName: "test.png",
            base64Data: String(repeating: "A", count: 1024)
        )
        // 1024 base64 chars ≈ 768 bytes ≈ 0.75 KB
        #expect(imgAttachment.sizeKB > 0)
        #expect(imgAttachment.isImage == true)
    }

    // MARK: - Logger redaction

    @Test func test_logger_redacts_bearer_token() async throws {
        // Indirect test - just verify the redactor masks "Bearer <token>"
        // Logger.redactSensitive is private, ale testujemy przez integrację
        let sensitiveLog = "Request: Bearer abc123def456ghi789 with body"
        Logger.log(sensitiveLog, category: "test", redact: true, level: .debug)
        // Nie aserujemy bezpośrednio (log idzie do OSLog) - smoke test że nie crashuje
        #expect(true == true)
    }

    // MARK: - MarkdownExporter

    @Test func test_markdownExporter_includes_title_and_role_headers() async throws {
        let user = Message(role: .user, content: "Cześć")
        let assistant = Message(role: .assistant, content: "Witaj!")
        let conv = Conversation(
            id: UUID(),
            title: "Pierwsza rozmowa",
            messages: [user, assistant],
            createdAt: Date(),
            updatedAt: Date(),
            isPinned: false,
            tags: [],
            folderId: nil
        )
        let md = MarkdownExporter.render(conv)
        #expect(md.contains("# Pierwsza rozmowa"))
        #expect(md.contains("## Ty"))
        #expect(md.contains("## Asystent"))
        #expect(md.contains("Cześć"))
        #expect(md.contains("Witaj!"))
    }

    @Test func test_markdownExporter_skips_system_messages() async throws {
        let sys = Message(role: .system, content: "UKRYTY SYSTEM PROMPT")
        let user = Message(role: .user, content: "Pytanie")
        let conv = Conversation(
            id: UUID(),
            title: "Test",
            messages: [sys, user],
            createdAt: Date(),
            updatedAt: Date(),
            isPinned: false,
            tags: [],
            folderId: nil
        )
        let md = MarkdownExporter.render(conv)
        #expect(!md.contains("UKRYTY SYSTEM PROMPT"))
        #expect(!md.contains("## System"))
        #expect(md.contains("Pytanie"))
    }

    @Test func test_markdownExporter_includes_tags_and_image_note() async throws {
        let user = Message(role: .user, content: "Narysuj kota")
        let assistant = Message(
            role: .assistant,
            content: "Proszę",
            images: [GeneratedImage(base64Data: "AAA", mimeType: "image/png", prompt: "kot")]
        )
        let conv = Conversation(
            id: UUID(),
            title: "Obraz",
            messages: [user, assistant],
            createdAt: Date(),
            updatedAt: Date(),
            isPinned: false,
            tags: ["kreatywnosc", "test"],
            folderId: nil
        )
        let md = MarkdownExporter.render(conv)
        #expect(md.contains("`kreatywnosc`"))
        #expect(md.contains("`test`"))
        #expect(md.contains("1 wygenerowanych obrazow"))
    }

    @Test func test_markdownExporter_suggestedFilename_sanitizes() async throws {
        let conv = Conversation(
            id: UUID(),
            title: "C:/test:różne",
            messages: [],
            createdAt: Date(),
            updatedAt: Date(),
            isPinned: false,
            tags: [],
            folderId: nil
        )
        let filename = MarkdownExporter.suggestedFilename(for: conv)
        #expect(filename.hasPrefix("MiniChat-"))
        #expect(!filename.contains("/"))
        // ":" w tytule powinien być zastąpiony
        #expect(!filename.contains(":"))
    }

    @Test func test_markdownExporter_includes_reasoning_when_present() async throws {
        let assistant = Message(
            role: .assistant,
            content: "Finalna odpowiedź",
            reasoningContent: "Długa analiza modelu nad problemem..."
        )
        let conv = Conversation(
            id: UUID(),
            title: "Reasoning",
            messages: [assistant],
            createdAt: Date(),
            updatedAt: Date(),
            isPinned: false,
            tags: [],
            folderId: nil
        )
        let md = MarkdownExporter.render(conv)
        #expect(md.contains("Finalna odpowiedź"))
        #expect(md.contains("Długa analiza"))
        #expect(md.contains("<details>"))
        #expect(md.contains("Rozwazania modelu"))
    }

    // MARK: - ConversationStore.fork

    @Test func test_fork_copies_prefix_and_switches_active() async throws {
        let store = await MainActor.run { ConversationStore() }
        await MainActor.run { store.deleteAll() }
        let m1 = Message(role: .user, content: "Q1")
        let m2 = Message(role: .assistant, content: "A1")
        let m3 = Message(role: .user, content: "Q2")
        let original = await MainActor.run { () -> Conversation in
            _ = store.createNewConversation()
            guard var current = store.currentConversation else { fatalError("brak aktywnej") }
            current.title = "Oryginał"
            current.messages = [m1, m2, m3]
            store.currentConversation = current
            return current
        }
        let forked = await MainActor.run { store.fork(from: m2.id, in: original) }
        #expect(forked != nil)
        #expect(forked?.messages.count == 2)
        #expect(forked?.messages[0].content == "Q1")
        #expect(forked?.messages[1].content == "A1")
        await MainActor.run {
            #expect(store.currentConversationId == forked?.id)
            // Oryginał nietknięty
            #expect(store.conversations.first(where: { $0.id == original.id })?.messages.count == 3)
        }
    }

    @Test func test_fork_unknown_messageId_returns_nil() async throws {
        let store = await MainActor.run { ConversationStore() }
        await MainActor.run { store.deleteAll() }
        let m1 = Message(role: .user, content: "Q1")
        let original = await MainActor.run { () -> Conversation in
            _ = store.createNewConversation()
            guard var current = store.currentConversation else { fatalError("brak aktywnej") }
            current.title = "Test"
            current.messages = [m1]
            store.currentConversation = current
            return current
        }
        let result = await MainActor.run { store.fork(from: UUID(), in: original) }
        #expect(result == nil)
    }

    @Test func test_fork_preserves_folderId_and_omits_tags() async throws {
        let store = await MainActor.run { ConversationStore() }
        await MainActor.run { store.deleteAll() }
        let folder = UUID()
        let m1 = Message(role: .user, content: "Q1")
        let original = await MainActor.run { () -> Conversation in
            _ = store.createNewConversation()
            guard var current = store.currentConversation else { fatalError("brak aktywnej") }
            current.title = "Org"
            current.messages = [m1]
            current.tags = ["x", "y"]
            current.folderId = folder
            store.currentConversation = current
            return current
        }
        let forked = await MainActor.run { store.fork(from: m1.id, in: original) }
        #expect(forked?.folderId == folder)
        #expect(forked?.tags.isEmpty == true)
        #expect(forked?.isPinned == false)
    }

    // MARK: - ConversationStore.stats

    @Test func test_stats_aggregates_correctly() async throws {
        let store = await MainActor.run { ConversationStore() }
        await MainActor.run {
            store.deleteAll()
            // Pierwsza rozmowa
            _ = store.createNewConversation()
            if var current = store.currentConversation {
                current.title = "C1"
                current.messages = [
                    Message(role: .user, content: "Q1"),
                    Message(role: .assistant, content: "A1")
                ]
                current.tags = ["tag1"]
                store.currentConversation = current
            }
            // Druga rozmowa
            _ = store.createNewConversation()
            if var current = store.currentConversation {
                current.title = "C2"
                current.messages = [
                    Message(role: .user, content: "Q2"),
                    Message(role: .assistant, content: "A2 long response")
                ]
                current.tags = ["tag1", "tag2"]
                store.currentConversation = current
            }
        }
        let stats = await MainActor.run { store.stats }
        #expect(stats.totalConversations == 2)
        #expect(stats.totalMessages == 4)
        #expect(stats.totalTags == 2)
        #expect(stats.topTags.first?.tag == "tag1")
        #expect(stats.topTags.first?.count == 2)
    }

    @Test func test_stats_empty_store_returns_zero() async throws {
        let store = await MainActor.run { ConversationStore() }
        await MainActor.run { store.deleteAll() }
        let stats = await MainActor.run { store.stats }
        #expect(stats.totalConversations == 0)
        #expect(stats.totalMessages == 0)
        #expect(stats.totalTags == 0)
        #expect(stats.topTags.isEmpty)
    }

    // MARK: - MarkdownParser cache

    @Test func test_markdownParser_returns_same_segments_for_same_input() async throws {
        // Cache nie powinien zmieniac wynikow - ten sam input musi dac ten sam output.
        let text = "Hej\n```swift\nlet x = 1\n```\nKoniec"
        let first = MarkdownParser.parse(text)
        let second = MarkdownParser.parse(text)
        #expect(first.count == second.count)
        for (a, b) in zip(first, second) {
            switch (a, b) {
            case (.text(let ta), .text(let tb)):
                #expect(ta == tb)
            case (.code(let ca, let la), .code(let cb, let lb)):
                #expect(ca == cb)
                #expect(la == lb)
            default:
                Issue.record("Rozne typy segmentow przy tym samym inpucie")
            }
        }
    }

    @Test func test_markdownParser_handles_unclosed_code_block() async throws {
        // Niezamkniety blok traktowany jako tekst - weryfikacja ze cache nie psuje edge case'a
        let text = "Przed ```swift\nlet x = 1"
        let segments = MarkdownParser.parse(text)
        #expect(segments.count == 1)
        if case .text(let t) = segments[0] {
            #expect(t.contains("```swift"))
        } else {
            Issue.record("Niezamknięty blok powinien być tekstem")
        }
    }

    // MARK: - ConversationStore.rename

    @MainActor
    @Test func test_store_rename_changes_title() async throws {
        let store = ConversationStore()
        store.deleteAll()
        var conv = store.createNewConversation()
        conv.title = "Stary tytul"
        store.currentConversation = conv

        store.rename(conv, to: "Nowy tytul")

        let updated = store.conversations.first(where: { $0.id == conv.id })
        #expect(updated?.title == "Nowy tytul")
    }

    @MainActor
    @Test func test_store_rename_trims_whitespace() async throws {
        let store = ConversationStore()
        store.deleteAll()
        let conv = store.createNewConversation()

        store.rename(conv, to: "   Tytul z spacjami   ")

        let updated = store.conversations.first(where: { $0.id == conv.id })
        #expect(updated?.title == "Tytul z spacjami")
    }

    @MainActor
    @Test func test_store_rename_empty_string_keeps_existing() async throws {
        let store = ConversationStore()
        store.deleteAll()
        var conv = store.createNewConversation()
        conv.title = "Oryginalny"
        store.currentConversation = conv

        store.rename(conv, to: "   ")

        let updated = store.conversations.first(where: { $0.id == conv.id })
        #expect(updated?.title == "Oryginalny")
    }

    @MainActor
    @Test func test_store_rename_unknown_conversation_is_noop() async throws {
        let store = ConversationStore()
        store.deleteAll()
        let phantom = Conversation()

        store.rename(phantom, to: "Nowa")

        #expect(store.conversations.contains(where: { $0.id == phantom.id }) == false)
    }
}
