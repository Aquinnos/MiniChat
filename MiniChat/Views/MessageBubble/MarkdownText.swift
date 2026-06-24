//
//  MarkdownText.swift
//  MiniChat
//
//  Renderowanie markdown z obsługą code blocków (```lang\n...\n```)
//  i syntax highlightingiem. Segmenty: text + code.
//

import SwiftUI

enum MarkdownSegment {
    case text(String)
    case code(String, language: String?)
}

enum MarkdownParser {
    /// Parsuje markdown dzieląc go na segmenty tekstowe i bloki kodu.
    /// Obsługuje format ```lang\n...\n```. Niezamknięty blok traktowany jako tekst.
    static func parse(_ text: String) -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        var currentText = ""
        var i = text.startIndex

        while i < text.endIndex {
            if let codeStart = text.range(of: "```", range: i..<text.endIndex) {
                if codeStart.lowerBound > i {
                    currentText.append(contentsOf: text[i..<codeStart.lowerBound])
                }
                let afterFence = codeStart.upperBound
                let langEnd = text.range(of: "\n", range: afterFence..<text.endIndex)?.lowerBound ?? text.endIndex
                let lang = String(text[afterFence..<langEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
                let langOrNil = lang.isEmpty ? nil : lang

                if let codeEnd = text.range(of: "```", range: langEnd..<text.endIndex) {
                    let codeContent = String(text[langEnd..<codeEnd.lowerBound])
                    if !currentText.isEmpty {
                        segments.append(.text(currentText))
                        currentText = ""
                    }
                    segments.append(.code(codeContent, language: langOrNil))
                    i = codeEnd.upperBound
                } else {
                    currentText.append(contentsOf: text[codeStart.lowerBound..<text.endIndex])
                    i = text.endIndex
                    break
                }
            } else {
                currentText.append(contentsOf: text[i..<text.endIndex])
                break
            }
        }

        if !currentText.isEmpty {
            segments.append(.text(currentText))
        }
        return segments
    }
}

struct MarkdownText: View {
    let text: String
    let color: Color
    let isUser: Bool

    var body: some View {
        let segments = MarkdownParser.parse(text)
        let hasCodeBlock = segments.contains { if case .code = $0 { return true } else { return false } }

        if !hasCodeBlock {
            inlineText(text)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case .text(let t):
                        inlineText(t)
                    case .code(let code, let lang):
                        CodeBlockView(code: code, language: lang, isUser: isUser)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func inlineText(_ text: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: false,
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
                .foregroundColor(color)
        } else {
            Text(text)
                .foregroundColor(color)
        }
    }
}
