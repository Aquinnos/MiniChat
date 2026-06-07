//
//  MemoryStore.swift
//  MiniChat
//
//  Pamięć długoterminowa - fakty które model pamięta między konwersacjami.
//  Działa jak Claude "Memory" - model widzi te fakty jako system context.
//

import Foundation
import Combine

struct MemoryFact: Identifiable, Codable, Hashable {
    let id: UUID
    var content: String
    let createdAt: Date

    init(id: UUID = UUID(), content: String, createdAt: Date = Date()) {
        self.id = id
        self.content = content
        self.createdAt = createdAt
    }
}

@MainActor
final class MemoryStore: ObservableObject {
    static let shared = MemoryStore()

    @Published private(set) var facts: [MemoryFact] = []

    private let storageKey = "memory_facts"

    private init() {
        load()
    }

    // MARK: - CRUD

    func add(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Sprawdź czy już istnieje
        if !facts.contains(where: { $0.content.lowercased() == trimmed.lowercased() }) {
            facts.append(MemoryFact(content: trimmed))
            facts.sort { $0.createdAt < $1.createdAt }
            save()
        }
    }

    func remove(_ fact: MemoryFact) {
        facts.removeAll(where: { $0.id == fact.id })
        save()
    }

    func update(_ fact: MemoryFact, newContent: String) {
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = facts.firstIndex(where: { $0.id == fact.id }) {
            facts[idx] = MemoryFact(id: fact.id, content: trimmed, createdAt: fact.createdAt)
            save()
        }
    }

    func clear() {
        facts.removeAll()
        save()
    }

    // MARK: - Persystencja

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(facts)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            Logger.log("Memory save error: \(error)", category: "Memory", level: .error)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            facts = try decoder.decode([MemoryFact].self, from: data)
        } catch {
            Logger.log("Memory load error: \(error)", category: "Memory", level: .error)
        }
    }

    // MARK: - Format dla system prompt

    /// Formatuje pełny kontekst: fakty + lista poprzednich rozmów
    func asSystemMessage(
        previousConversations: [Conversation] = [],
        maxPrevConversations: Int = 10
    ) -> String {
        var sections: [String] = []

        // 1. Fakty o użytkowniku
        if !facts.isEmpty {
            var section = "FAKTY O UŻYTKOWNIKU (pamiętaj je w tej rozmowie):\n\n"
            for (i, fact) in facts.enumerated() {
                section += "\(i + 1). \(fact.content)\n"
            }
            sections.append(section)
        }

        // 2. Lista poprzednich rozmów (kontekst długoterminowy)
        let previous = Array(previousConversations.prefix(maxPrevConversations))
        if !previous.isEmpty {
            var section = "POPRZEDNIE ROZMOWY Z UŻYTKOWNIKIEM (możesz się do nich odwoływać):\n\n"
            for (i, conv) in previous.enumerated() {
                section += "\(i + 1). \"\(conv.title)\""
                section += " — \(conv.messages.count) wiadomości, ostatnia aktywność: \(formatDate(conv.updatedAt))"
                if let snippet = firstUserMessageSnippet(conv) {
                    section += "\n   Pierwsze pytanie: \"\(snippet)\""
                }
                section += "\n"
            }
            section += "\nJeśli użytkownik pyta o coś z poprzednich rozmów, możesz naturalnie nawiązać do tych tematów."
            sections.append(section)
        }

        if sections.isEmpty { return "" }

        return sections.joined(separator: "\n\n---\n\n")
    }

    /// Czy są jakieś fakty lub poprzednie rozmowy
    var hasAny: Bool { !facts.isEmpty }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func firstUserMessageSnippet(_ conv: Conversation) -> String? {
        guard let first = conv.messages.first(where: { $0.role == .user }) else {
            return nil
        }
        let trimmed = first.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(100))
    }
}
