//
//  CodeBlockView.swift
//  MiniChat
//
//  Pojedynczy blok kodu z syntax highlightingiem, nagłówkiem języka i przyciskiem kopiuj.
//

import SwiftUI
import UIKit

struct CodeBlockView: View {
    let code: String
    let language: String?
    let isUser: Bool

    var body: some View {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let lang = language ?? CodeSyntaxHighlighter.autoDetectLanguageStatic(trimmed)
        let attributed = isUser
            ? CodeSyntaxHighlighter.highlightForUser(trimmed, language: lang)
            : CodeSyntaxHighlighter.highlight(trimmed, language: lang)

        VStack(alignment: .leading, spacing: 0) {
            header(lang: lang)
            codeScroll(attributed: attributed)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isUser ? Color.white.opacity(0.2) : Theme.gold.opacity(0.3), lineWidth: 1)
        )
    }

    private func header(lang: String) -> some View {
        HStack {
            Text(lang.uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(isUser ? .white.opacity(0.85) : Theme.gold)
            Spacer()
            Button {
                UIPasteboard.general.string = code.trimmingCharacters(in: .whitespacesAndNewlines)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(isUser ? .white.opacity(0.7) : Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isUser ? Color.white.opacity(0.15) : Theme.gold.opacity(0.15))
    }

    private func codeScroll(attributed: AttributedString) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(attributed)
                .lineLimit(nil)
                .fixedSize(horizontal: true, vertical: true)
                .padding(10)
                .textSelection(.enabled)
        }
        .background(isUser ? Color.black.opacity(0.2) : Color(white: 0.96))
    }
}
