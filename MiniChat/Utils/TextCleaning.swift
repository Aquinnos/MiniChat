//
//  TextCleaning.swift
//  MiniChat
//
//  Normalizacja tekstu z modelu - Unicode NFC, białe znaki, smart quotes,
//  literalne escape sequences, wielokrotne nowe linie.
//

import Foundation

enum TextCleaning {
    /// Precompiled regex dla wielokrotnych nowych linii. Kompilacja regexa
    /// trwa ~1ms - cache pozwala uniknąć kosztu przy każdym wywołaniu clean()
    /// (który jest wywoływany per stream chunk).
    nonisolated private static let multipleNewlinesRegex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "\n{4,}")
    }()

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

        // Wielokrotne nowe linie → max 3 (precompiled regex)
        let nsString = result as NSString
        let range = NSRange(location: 0, length: nsString.length)
        result = multipleNewlinesRegex.stringByReplacingMatches(
            in: result, options: [], range: range, withTemplate: "\n\n\n"
        )

        return result
    }
}
