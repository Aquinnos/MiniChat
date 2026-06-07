//
//  ExaSearcher.swift
//  MiniChat
//
//  Exa.ai — AI-native search API (darmowy tier na start).
//  Endpoint: https://api.exa.ai/search
//  Wyniki są preprocesowane dla LLM (czysty tekst + highlights).
//  Fallback do DuckDuckGo jeśli brak klucza lub błąd.
//

import Foundation

final class ExaSearcher {
    static let shared = ExaSearcher()

    /// Computed — czyta Keychain przy każdym wywołaniu, więc zmiana klucza w Ustawieniach
    /// działa natychmiast (nie trzeba restartować aplikacji).
    private var apiKey: String {
        KeychainHelper.readExa() ?? ""
    }
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    /// Szuka przez Exa API. Domyślnie type=auto (łączy neural + keyword),
    /// useAutoprompt=true (Exa optymalizuje query pod siebie).
    func search(query: String, maxResults: Int = 5) async throws -> [WebSearchResult] {
        guard isConfigured else {
            throw WebSearchError.networkError("Exa API key nie jest skonfigurowany")
        }

        let url = URL(string: "https://api.exa.ai/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        // type=auto = łączy neural (semantyczne) + keyword (dokładne dopasowanie)
        // contents.text = max 1000 znaków, contents.highlights = kluczowe fragmenty
        let body: [String: Any] = [
            "query": query,
            "numResults": maxResults,
            "type": "auto",
            "useAutoprompt": true,
            "contents": [
                "text": ["maxCharacters": 1500],
                "highlights": ["numSentences": 3, "highlightsPerUrl": 2]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let preview = query.count > 80 ? String(query.prefix(80)) + "..." : query
        Logger.log("ExaSearch query preview: \(preview) len=\(query.count)", category: "ExaSearch", redact: true)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            Logger.log("ExaSearch HTTP \(code) body preview: \(body.prefix(300))", category: "ExaSearch", redact: true, level: .error)
            throw WebSearchError.networkError("HTTP \(code): \(String(body.prefix(200)))")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WebSearchError.parseError
        }

        guard let results = json["results"] as? [[String: Any]] else {
            print("⚠️ [ExaSearch] No results in response")
            throw WebSearchError.noResults
        }

        var webResults: [WebSearchResult] = []
        for r in results.prefix(maxResults) {
            guard let title = r["title"] as? String,
                  let url = r["url"] as? String else { continue }

            // Preferuj highlights (lepsze dla LLM) nad pełny tekst
            var snippet = ""
            if let highlights = r["highlights"] as? [String], !highlights.isEmpty {
                snippet = highlights.joined(separator: " ... ")
            } else if let text = r["text"] as? String {
                snippet = String(text.prefix(500))
            }

            webResults.append(WebSearchResult(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                snippet: snippet.trimmingCharacters(in: .whitespacesAndNewlines),
                url: url
            ))
        }

        print("✅ [ExaSearch] Got \(webResults.count) results")
        if webResults.isEmpty {
            throw WebSearchError.noResults
        }
        return webResults
    }
}

// MARK: - Unified entry point

/// Wybiera provider na podstawie konfiguracji:
/// 1) Exa (jeśli klucz) - najlepsza jakość dla AI
/// 2) DuckDuckGo - fallback (darmowe, ale słabsze dla trendów)
enum WebSearch {
    static func smartSearch(query: String, maxResults: Int = 5) async throws -> [WebSearchResult] {
        if ExaSearcher.shared.isConfigured {
            do {
                return try await ExaSearcher.shared.search(query: query, maxResults: maxResults)
            } catch {
                print("⚠️ [WebSearch] Exa failed, falling back to DDG: \(error)")
                return try await WebSearcher.shared.search(query: query, maxResults: maxResults)
            }
        }
        return try await WebSearcher.shared.search(query: query, maxResults: maxResults)
    }
}
