//
//  MarkdownExporter.swift
//  MiniChat
//
//  Renderuje Conversation do Markdowna gotowego do wklejenia / udostępnienia.
//

import Foundation

enum MarkdownExporter {
    private static let maxFilenameTitleLength = 50
    private static let roleLabelUser = "Ty"
    private static let roleLabelAssistant = "Asystent"
    private static let roleLabelSystem = "System"

    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone]
        return f
    }()

    /// Renderuje pełną konwersację do Markdowna.
    static func render(_ conversation: Conversation) -> String {
        var output = "# \(conversation.title)\n\n"
        output += "Data: \(dateFormatter.string(from: conversation.updatedAt))\n"

        if !conversation.tags.isEmpty {
            output += "Tagi: " + conversation.tags.map { "`\($0)`" }.joined(separator: ", ") + "\n"
        }

        output += "\n---\n\n"

        for message in conversation.messages where message.role != .system {
            output += renderMessage(message)
            output += "\n---\n\n"
        }

        return output
    }

    /// Generuje nazwę pliku dla udostępnienia (bez rozszerzenia).
    static func suggestedFilename(for conversation: Conversation) -> String {
        let safeTitle = conversation.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .prefix(maxFilenameTitleLength)
        let datePart = dateFormatter.string(from: conversation.updatedAt)
            .replacingOccurrences(of: ":", with: "-")
        return "MiniChat-\(safeTitle)-\(datePart)"
    }

    // MARK: - Helpers

    private static func renderMessage(_ message: Message) -> String {
        var out = ""
        let roleLabel: String
        switch message.role {
        case .user: roleLabel = roleLabelUser
        case .assistant: roleLabel = roleLabelAssistant
        case .system: roleLabel = roleLabelSystem
        }

        out += "## \(roleLabel)\n\n"

        if !message.attachments.isEmpty {
            let names = message.attachments.map { $0.fileName }.joined(separator: ", ")
            out += "_Zalaczniki: \(names)_\n\n"
        }

        if let images = message.images, !images.isEmpty {
            out += "_\(images.count) wygenerowanych obrazow (pominieto w eksporcie tekstowym)_\n\n"
        }

        let cleaned = TextCleaning.clean(message.content)
        out += cleaned
        out += "\n"

        if let reasoning = message.reasoningContent, !reasoning.isEmpty {
            out += "\n<details>\n<summary>Rozwazania modelu</summary>\n\n"
            out += TextCleaning.clean(reasoning)
            out += "\n\n</details>\n"
        }

        return out
    }
}
