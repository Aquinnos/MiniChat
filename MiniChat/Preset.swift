//
//  Preset.swift
//  MiniChat
//
//  Custom Preset = własny "GPT" - system prompt + wybrane narzędzia + model.
//  Przykłady: Code Reviewer, Bug Hunter, Translator, API Designer.
//

import Foundation

struct Preset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    var systemPrompt: String
    var allowedTools: Set<ToolName>
    var model: MiniMaxModel
    var temperature: Double  // 0.0 - 2.0
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "🎭",
        systemPrompt: String = "",
        allowedTools: Set<ToolName> = [],
        model: MiniMaxModel = .m3,
        temperature: Double = 0.7,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.systemPrompt = systemPrompt
        self.allowedTools = allowedTools
        self.model = model
        self.temperature = temperature
        self.createdAt = createdAt
    }
}

enum ToolName: String, Codable, CaseIterable, Hashable {
    case webSearch = "web_search"
    case generateImage = "generate_image"
    case getCurrentTime = "get_current_time"
    case readFile = "read_file"

    var displayName: String {
        switch self {
        case .webSearch: return "Wyszukiwanie w internecie"
        case .generateImage: return "Generowanie obrazów"
        case .getCurrentTime: return "Aktualna data i czas"
        case .readFile: return "Czytanie plików"
        }
    }

    var icon: String {
        switch self {
        case .webSearch: return "magnifyingglass"
        case .generateImage: return "paintpalette"
        case .getCurrentTime: return "clock"
        case .readFile: return "doc.text"
        }
    }
}

/// Wbudowane presety - startowy zestaw dla każdego użytkownika
enum BuiltInPresets {
    static let codeReviewer = Preset(
        name: "Code Reviewer",
        emoji: "🔍",
        systemPrompt: """
        Jesteś doświadczonym Senior iOS Reviewerem. Twoje zadanie:
        - Przeglądaj kod Swift/SwiftUI pod kątem bugów, bezpieczeństwa, wydajności
        - Wskazuj konkretne linie i proponuj lepsze rozwiązania
        - Używaj Swift idioms (guard, async/await, value types)
        - Komentuj po polsku, kod po angielsku
        - Bądź krytyczny ale fair - pochwal dobre rozwiązania
        """,
        allowedTools: [.readFile],
        model: .m3,
        temperature: 0.3
    )

    static let bugHunter = Preset(
        name: "Bug Hunter",
        emoji: "🐛",
        systemPrompt: """
        Jesteś ekspertem od debugowania. Gdy dostajesz kod lub opis buga:
        1. Zadaj 2-3 pytania o symptom (kiedy, gdzie, jak często)
        2. Wymień TOP 5 możliwych przyczyn
        3. Dla każdej: jak zweryfikować (log, breakpoint, unit test)
        4. Zacznij od najtańszej do sprawdzenia
        Bądź systematyczny - nie strzelaj na oślep.
        """,
        allowedTools: [.webSearch, .readFile],
        model: .m3,
        temperature: 0.5
    )

    static let translator = Preset(
        name: "Translator",
        emoji: "🌐",
        systemPrompt: """
        Jesteś profesjonalnym tłumaczem. Zasady:
        - Tłumacz ZAWSZE dokładnie, nie parafrazuj
        - Zachowaj ton, rejestr i styl oryginału
        - Jeśli termin techniczny - podaj w nawiasie oryginał
        - Dla tekstu prawnego/medycznego - dodaj notatkę "wymaga weryfikacji specjalisty"
        - Wskaż niejednoznaczności w oryginale
        """,
        allowedTools: [],
        model: .m2,  // tańszy, nie potrzebuje tools
        temperature: 0.3
    )

    static let apiDesigner = Preset(
        name: "API Designer",
        emoji: "🔌",
        systemPrompt: """
        Projektant REST/GraphQL APIs. Zasady:
        - RESTful conventions (plural nouns, kebab-case w URLs)
        - Używaj HTTP status codes poprawnie (200, 201, 204, 400, 401, 403, 404, 409, 422, 500)
        - JSON: snake_case dla pól, camelCase OK w niektórych kontekstach
        - Pagination: cursor-based dla >1000 items, offset dla mniejszych
        - Zawsze wersjonowanie (/v1/) i rate limiting w headerach
        - Dokumentuj w OpenAPI 3.0+
        """,
        allowedTools: [.webSearch],
        model: .m3,
        temperature: 0.4
    )

    static let all: [Preset] = [codeReviewer, bugHunter, translator, apiDesigner]
}
