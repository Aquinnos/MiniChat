//
//  WebSearcher.swift
//  MiniChat
//
//  DuckDuckGo HTML search - darmowy backend dla web search tool.
//

import Foundation
import os

struct WebSearchResult: Codable {
    let title: String
    let snippet: String
    let url: String
}

enum WebSearchError: LocalizedError {
    case invalidQuery
    case noResults
    case networkError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidQuery: return "Nieprawidłowe zapytanie"
        case .noResults: return "Brak wyników"
        case .networkError(let msg): return "Błąd sieci: \(msg)"
        case .parseError: return "Błąd parsowania wyników"
        }
    }
}

/// DuckDuckGo HTML scraping - darmowe, bez limitu
/// Korzysta z publicznego endpointu HTML (html.duckduckgo.com)
final class WebSearcher {
    static let shared = WebSearcher()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Language": "en-US,en;q=0.9,pl;q=0.8"
        ]
        self.session = URLSession(configuration: config)
    }

    /// Szuka w DuckDuckGo i zwraca top N wyników
    func search(query: String, maxResults: Int = 5) async throws -> [WebSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WebSearchError.invalidQuery }

        var components = URLComponents(string: "https://html.duckduckgo.com/html/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "kl", value: "us-en")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        // Log only masked preview to avoid leaking long user inputs
        let preview = trimmed.count > 80 ? String(trimmed.prefix(80)) + "..." : trimmed
        Logger.log("DuckDuckGo query preview: \(preview) len=\(trimmed.count)", category: "WebSearch", redact: true)

        // Simple retry once on transient failure
        var data: Data
        var response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            (data, response) = try await session.data(for: request)
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            Logger.log("WebSearch HTTP \(code)", category: "WebSearch", redact: true, level: .error)
            throw WebSearchError.networkError("HTTP \(code)")
        }

        Logger.log("WebSearch fetched \(data.count) bytes", category: "WebSearch")

        guard let html = String(data: data, encoding: .utf8) else {
            throw WebSearchError.parseError
        }

        // Limit parsed HTML to first 20k characters to reduce regex cost
        let htmlToParse = String(html.prefix(20_000))
        let results = parse(html: htmlToParse, maxResults: maxResults)
        Logger.log("WebSearch parsed \(results.count) results", category: "WebSearch")

        if results.isEmpty {
            throw WebSearchError.noResults
        }
        return results
    }

    /// Parser HTML - odporny na oba formaty DuckDuckGo:
    /// - desktop: class="result-link" / class="result-snippet"
    /// - mobile/iPhone: class="result__a" / class="result__snippet"
    private func parse(html: String, maxResults: Int) -> [WebSearchResult] {
        var results: [WebSearchResult] = []
        let nsHTML = html as NSString
        let fullRange = NSRange(location: 0, length: nsHTML.length)

        // Regex: łap cały tag <a> z class zawierającym result-link LUB result__a
        let pattern = #"<a\b[^>]*class=['"](?:result-link|result__a)['"][^>]*>.*?</a>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) else {
            Logger.log("Failed to compile WebSearch regex", category: "WebSearch", level: .error)
            return []
        }

        let matches = regex.matches(in: html, options: [], range: fullRange)

        for (i, match) in matches.enumerated() {
            if i >= maxResults { break }
            let tagRange = match.range
            guard tagRange.location != NSNotFound else { continue }
            let fullTag = nsHTML.substring(with: tagRange)

            // Wyciągnij URL z href
            guard let url = extractHref(from: fullTag) else { continue }

            // Pomiń wewnętrzne URL-e DDG (z wyjątkiem redirect)
            if url.contains("duckduckgo.com") && !url.contains("redirect") { continue }

            // Wyciągnij tytuł (tekst wewnątrz <a>...</a>)
            let title = extractTitle(from: fullTag)

            if title.isEmpty { continue }
            results.append(WebSearchResult(title: title, snippet: "", url: url))
        }

        // Snippety - oba formaty
        let snippetPattern = #"<a\b[^>]*class=['"](?:result-snippet|result__snippet)['"][^>]*>(.*?)</a>"#
        if let snippetRegex = try? NSRegularExpression(
            pattern: snippetPattern,
            options: [.dotMatchesLineSeparators, .caseInsensitive]
        ) {
            let snippetMatches = snippetRegex.matches(in: html, options: [], range: fullRange)
            for (i, snipMatch) in snippetMatches.enumerated() {
                guard i < results.count else { break }
                guard snipMatch.numberOfRanges >= 2 else { continue }
                let snippetRange = snipMatch.range(at: 1)
                let snippet = stripHTML(nsHTML.substring(with: snippetRange))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                results[i] = WebSearchResult(
                    title: results[i].title,
                    snippet: snippet,
                    url: results[i].url
                )
            }
        }

        return results
    }

    private func extractHref(from tag: String) -> String? {
        // Szukaj href="..." lub href='...'
        let pattern = #"href\s*=\s*['"]([^'"]+)['"]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: (tag as NSString).length)
        guard let match = regex.firstMatch(in: tag, range: range),
              match.numberOfRanges >= 2 else { return nil }
        return (tag as NSString).substring(with: match.range(at: 1))
    }

    private func extractTitle(from tag: String) -> String {
        // Wyciągnij tekst między pierwszym > a ostatnim </a>
        guard let openBracket = tag.firstIndex(of: ">") else { return "" }
        guard let closeBracket = tag.range(of: "</a>", options: .backwards) else { return "" }
        let afterOpen = tag.index(after: openBracket)
        if afterOpen >= closeBracket.lowerBound { return "" }
        let contentRange = afterOpen..<closeBracket.lowerBound
        return stripHTML(String(tag[contentRange]))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripHTML(_ html: String) -> String {
        var result = html
        let tagPattern = "<[^>]+>"
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let range = NSRange(location: 0, length: (result as NSString).length)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        result = result
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&ndash;", with: "–")
            .replacingOccurrences(of: "&mdash;", with: "—")
        return result
    }

    /// Formatuje wyniki wyszukiwania jako tekst do zwrócenia do modelu
    static func formatResults(_ results: [WebSearchResult]) -> String {
        if results.isEmpty {
            return "Brak wyników wyszukiwania."
        }
        var output = "Wyniki wyszukiwania w internecie:\n\n"
        for (i, r) in results.enumerated() {
            output += "[\(i + 1)] \(r.title)\n"
            output += "URL: \(r.url)\n"
            if !r.snippet.isEmpty {
                output += "Opis: \(r.snippet)\n"
            }
            output += "\n"
        }
        return output
    }
}
