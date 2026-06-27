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
        excludeFromBackup()
    }

    private func excludeFromBackup() {
        var url = fileURL
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        do {
            try url.setResourceValues(resourceValues)
        } catch {
            Logger.log("Nie udało się wyłączyć backupu iCloud: \(error)", category: "ConversationStore", level: .error)
        }
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

    /// Przełącza aktywną rozmowę na podaną (np. z deep-linku z notyfikacji).
    /// No-op jeśli rozmowa nie istnieje.
    func switchToConversation(id: UUID) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        currentConversationId = id
    }

    /// Tworzy fork konwersacji: nową rozmowę zawierającą wiadomości do podanej (inclusive)
    /// i ustawia ją jako aktywną. Oryginał pozostaje nietknięty.
    /// Zwraca nową konwersację lub nil jeśli messageId nie znaleziony.
    @discardableResult
    func fork(from messageId: UUID, in source: Conversation) -> Conversation? {
        guard let cutIndex = source.messages.firstIndex(where: { $0.id == messageId }) else {
            Logger.log("fork: messageId nie znaleziony", category: "ConversationStore", level: .error)
            return nil
        }
        let prefixMessages = Array(source.messages.prefix(through: cutIndex))
        let forked = Conversation(
            title: "Fork: \(source.title)",
            messages: prefixMessages,
            createdAt: Date(),
            updatedAt: Date(),
            isPinned: false,
            tags: [],
            folderId: source.folderId
        )
        conversations.insert(forked, at: 0)
        currentConversationId = forked.id
        save()
        Logger.log("fork: utworzono \(forked.id) z \(prefixMessages.count) wiadomości", category: "ConversationStore", level: .info)
        return forked
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
            Logger.log("ConversationStore load error: \(error)", category: "ConversationStore", level: .error)
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
            Logger.log("ConversationStore save error: \(error)", category: "ConversationStore", level: .error)
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

    /// Ustawia folder konwersacji (helper dla FolderStore).
    /// Operacja czysto organizacyjna - nie zmienia updatedAt.
    func setFolder(_ folderId: UUID?, for conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx].folderId = folderId
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

    /// Przełącza przypięcie konwersacji. Operacja czysto organizacyjna - nie zmienia updatedAt.
    func togglePin(_ conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx].isPinned.toggle()
            save()
        }
    }

    // MARK: - Tags

    /// Ustawia tagi dla konwersacji (zastępuje istniejące). Operacja czysto organizacyjna.
    func setTags(_ tags: [String], for conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx].tags = tags
            save()
        }
    }

    /// Dodaje tag (idempotent - jeśli już jest, nie duplikuje). Operacja czysto organizacyjna.
    func addTag(_ tag: String, to conversation: Conversation) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return }
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            if !conversations[idx].tags.contains(trimmed) {
                conversations[idx].tags.append(trimmed)
                save()
            }
        }
    }

    /// Usuwa tag. Operacja czysto organizacyjna.
    func removeTag(_ tag: String, from conversation: Conversation) {
        if let idx = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[idx].tags.removeAll { $0 == tag }
            save()
        }
    }

    // MARK: - Rename

    /// Zmienia tytuł konwersacji. Pusta lub biała spacjami wartość jest ignorowana
    /// (zostaje aktualny tytuł). Traktuje jak edycję treści - aktualizuje updatedAt.
    func rename(_ conversation: Conversation, to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = conversations.firstIndex(where: { $0.id == conversation.id }) else { return }
        conversations[idx].title = trimmed
        conversations[idx].updatedAt = Date()
        save()
    }

    /// Zwraca wszystkie unikalne tagi ze wszystkich konwersacji
    var allTags: [String] {
        let set = Set(conversations.flatMap { $0.tags })
        return Array(set).sorted()
    }

    // MARK: - Stats

    /// Wylicza statystyki ze wszystkich konwersacji (top tagi, najdłuższa rozmowa,
    /// dzienna aktywność z ostatnich 30 dni, łączne znaki).
    var stats: ConversationStats {
        guard !conversations.isEmpty else { return .empty }

        let totalMessages = conversations.reduce(0) { $0 + $1.messages.count }
        let totalCharacters = conversations.reduce(0) { acc, conv in
            acc + conv.messages.reduce(0) { $0 + $1.content.count }
        }

        // Top tagi
        var tagCounts: [String: Int] = [:]
        for conv in conversations {
            for tag in conv.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        let topTags = tagCounts
            .map { ConversationStats.TagCount(tag: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }

        // Najdłuższa rozmowa
        let longest = conversations
            .map { (conv: $0, count: $0.messages.count) }
            .max(by: { $0.count < $1.count })
        let longestConv: ConversationStats.ConversationLength? = longest.map {
            ConversationStats.ConversationLength(
                conversationId: $0.conv.id,
                title: $0.conv.title,
                messageCount: $0.count
            )
        }

        // Dzienna aktywność z ostatnich 30 dni
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var dailyBuckets: [Date: Int] = [:]
        for offset in 0..<30 {
            if let day = calendar.date(byAdding: .day, value: -offset, to: today) {
                dailyBuckets[day] = 0
            }
        }
        for conv in conversations {
            let day = calendar.startOfDay(for: conv.updatedAt)
            if dailyBuckets[day] != nil {
                dailyBuckets[day, default: 0] += 1
            }
        }
        let daily = dailyBuckets
            .map { ConversationStats.DailyActivity(date: $0.key, count: $0.value) }
            .sorted { $0.date < $1.date }

        return ConversationStats(
            totalConversations: conversations.count,
            totalMessages: totalMessages,
            totalTags: tagCounts.count,
            topTags: topTags,
            longestConversation: longestConv,
            dailyActivity: daily,
            totalCharacters: totalCharacters
        )
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
