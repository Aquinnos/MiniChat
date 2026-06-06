//
//  ConversationStore.swift
//  MiniChat
//
//  Trwałe przechowywanie konwersacji w JSON na dysku.
//

import Foundation
import Combine

@MainActor
final class ConversationStore: ObservableObject {
    @Published private(set) var conversations: [Conversation] = []
    @Published var currentConversationId: UUID?

    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("conversations.json")
        load()
    }

    var currentConversation: Conversation? {
        get {
            guard let id = currentConversationId else { return nil }
            return conversations.first(where: { $0.id == id })
        }
        set {
            guard let newValue, let index = conversations.firstIndex(where: { $0.id == newValue.id }) else {
                return
            }
            conversations[index] = newValue
            currentConversationId = newValue.id
            save()
        }
    }

    /// Tworzy nową pustą rozmowę i ustawia ją jako aktywną.
    @discardableResult
    func createNewConversation() -> Conversation {
        let new = Conversation()
        conversations.insert(new, at: 0)
        currentConversationId = new.id
        save()
        return new
    }

    /// Ładuje konwersacje z dysku.
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.conversations = try decoder.decode([Conversation].self, from: data)
            // Otwórz ostatnio edytowaną
            self.currentConversationId = conversations.first?.id
        } catch {
            print("ConversationStore load error: \(error)")
        }
    }

    /// Zapisuje konwersacje na dysk.
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(conversations)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ConversationStore save error: \(error)")
        }
    }

    /// Usuwa konwersację.
    func delete(_ conversation: Conversation) {
        conversations.removeAll(where: { $0.id == conversation.id })
        if currentConversationId == conversation.id {
            currentConversationId = conversations.first?.id
        }
        save()
    }

    /// Ustawia folder konwersacji (helper dla FolderStore)
    func setFolder(_ folderId: UUID?, for conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx].folderId = folderId
            conversations[idx].updatedAt = Date()
            save()
        }
    }

    /// Zwraca konwersacje w danym folderze
    func conversations(in folderId: UUID?) -> [Conversation] {
        conversations.filter { $0.folderId == folderId }
    }

    /// Usuwa wszystkie konwersacje.
    func deleteAll() {
        conversations = []
        currentConversationId = nil
        save()
    }

    // MARK: - Pin / Unpin

    /// Przełącza przypięcie konwersacji
    func togglePin(_ conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx].isPinned.toggle()
            conversations[idx].updatedAt = Date()
            save()
        }
    }

    // MARK: - Tags

    /// Ustawia tagi dla konwersacji (zastępuje istniejące)
    func setTags(_ tags: [String], for conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx].tags = tags
            conversations[idx].updatedAt = Date()
            save()
        }
    }

    /// Dodaje tag (idempotent - jeśli już jest, nie duplikuje)
    func addTag(_ tag: String, to conversation: Conversation) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            if !conversations[idx].tags.contains(trimmed) {
                conversations[idx].tags.append(trimmed)
                conversations[idx].updatedAt = Date()
                save()
            }
        }
    }

    /// Usuwa tag
    func removeTag(_ tag: String, from conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx].tags.removeAll { $0 == tag }
            conversations[idx].updatedAt = Date()
            save()
        }
    }

    /// Zwraca wszystkie unikalne tagi ze wszystkich konwersacji
    var allTags: [String] {
        let set = Set(conversations.flatMap { $0.tags })
        return Array(set).sorted()
    }

    // MARK: - Search

    /// Przeszukuje konwersacje - title + content wszystkich messages
    /// Zwraca pary (Conversation, [matching messages]) dla matching konwersacji
    func search(query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return [] }

        var results: [SearchResult] = []
        for conv in conversations {
            var matchedMessages: [Message] = []
            // Match w tytule
            if conv.title.lowercased().contains(trimmed) {
                // Cała rozmowa pasuje
                results.append(SearchResult(conversation: conv, matchedMessages: conv.messages, titleMatch: true))
                continue
            }
            // Match w treści wiadomości
            for msg in conv.messages {
                if msg.content.lowercased().contains(trimmed) {
                    matchedMessages.append(msg)
                }
            }
            if !matchedMessages.isEmpty {
                results.append(SearchResult(conversation: conv, matchedMessages: matchedMessages, titleMatch: false))
            }
        }
        // Sortuj: pinned first, potem po updatedAt
        return results.sorted { lhs, rhs in
            if lhs.conversation.isPinned != rhs.conversation.isPinned {
                return lhs.conversation.isPinned
            }
            return lhs.conversation.updatedAt > rhs.conversation.updatedAt
        }
    }
}

/// Wynik wyszukiwania
struct SearchResult: Identifiable {
    let id: UUID
    let conversation: Conversation
    let matchedMessages: [Message]
    let titleMatch: Bool

    init(conversation: Conversation, matchedMessages: [Message], titleMatch: Bool) {
        self.id = conversation.id
        self.conversation = conversation
        self.matchedMessages = matchedMessages
        self.titleMatch = titleMatch
    }
}
