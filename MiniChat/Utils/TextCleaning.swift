//
//  TextCleaning.swift
//  MiniChat
//
//  Normalizacja tekstu z modelu - Unicode NFC, białe znaki, smart quotes,
//  literalne escape sequences, wielokrotne nowe linie.
//

import Foundation

enum TextCleaning {
    /// Czyści tekst z modelu: normalizuje Unicode, usuwa białe znaki,
    /// zamienia smart quotes na polskie, parsuje literalne escape sequences.
    /// NIE usuwa ZWJ (\u{200D}) - potrzebne dla złożonych znaków.
    nonisolated static func clean(_ text: String) -> String {
        var result = text

        // Normalizacja Unicode - NFC (composed) - naprawia "rozsypane" polskie znaki
        result = result.precomposedStringWithCanonicalMapping

        // Bezpieczne białe znaki (NIE ZWJ - potrzebne dla złożonych znaków)
        result = result.replacingOccurrences(of: "\u{200B}", with: "")  // zero-width space
        result = result.replacingOccurrences(of: "\u{FEFF}", with: "")  // BOM
        result = result.replacingOccurrences(of: "\u{00A0}", with: " ") // non-breaking space

        // Smart quotes → polskie
        result = result.replacingOccurrences(of: "\u{201C}", with: "„")
        result = result.replacingOccurrences(of: "\u{201D}", with: "\"")

        // Literalne escape sequences (gdyby model zwrócił tekst zamiast znaków)
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        result = result.replacingOccurrences(of: "\\\"", with: "\"")
        result = result.replacingOccurrences(of: "\\t", with: "\t")

        // Wielokrotne nowe linie → max 3
        result = result.replacingOccurrences(of: "\n{4,}", with: "\n\n\n", options: .regularExpression)

        return result
    }
}
