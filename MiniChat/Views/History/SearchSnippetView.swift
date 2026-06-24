//
//  SearchSnippetView.swift
//  MiniChat
//
//  Fragment tekstu z podświetlonym matchem (dla wyników wyszukiwania w historii).
//

import SwiftUI

struct SearchSnippetView: View {
    let content: String
    let query: String

    var body: some View {
        if let snippet = buildSnippet() {
            Text(snippet)
                .font(.caption)
                .lineLimit(2)
        } else {
            Text(String(content.prefix(120)))
                .font(.caption)
                .foregroundColor(Theme.textSecondary)
                .lineLimit(2)
        }
    }

    private func buildSnippet() -> AttributedString? {
        let lower = content.lowercased()
        let q = query.lowercased()
        guard let range = lower.range(of: q) else { return nil }

        let prefix = range.lowerBound == lower.startIndex ? "" : "…"
        let suffix = range.upperBound == lower.endIndex ? "" : "…"
        let nsContent = content as NSString
        let matchStart = lower.distance(from: lower.startIndex, to: range.lowerBound)
        let matchLen = q.count
        let beforeStart = max(0, matchStart - 40)
        let beforeLen = max(0, matchStart - beforeStart)
        let beforeText = nsContent.substring(with: NSRange(location: beforeStart, length: beforeLen))
        let matchText = nsContent.substring(with: NSRange(location: matchStart, length: matchLen))
        let afterLen = max(0, min(40, content.count - matchStart - matchLen))
        let afterText = nsContent.substring(with: NSRange(location: matchStart + matchLen, length: afterLen))

        var attributed = AttributedString("\(prefix)\(beforeText)\(matchText)\(afterText)\(suffix)")
        if let highlightedRange = attributed.range(of: matchText) {
            attributed[highlightedRange].foregroundColor = Theme.gold
            attributed[highlightedRange].font = .caption.bold()
        }
        return attributed
    }
}
