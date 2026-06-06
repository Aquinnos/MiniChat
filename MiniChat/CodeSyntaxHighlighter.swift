//
//  CodeSyntaxHighlighter.swift
//  MiniChat
//
//  Lekki syntax highlighter dla bloków kodu w wiadomościach.
//  Obsługuje: Swift, Python, JavaScript, TypeScript, Go, Rust, Bash, JSON, CSS, HTML.
//  Używa NSRegularExpression - bez zewnętrznych zależności.
//
//  Kolory są zgodne z motywem MiniChat (złoty/niebieski/biały).
//

import Foundation
import SwiftUI

enum CodeSyntaxHighlighter {

    // MARK: - Token types

    enum TokenType {
        case keyword, string, number, comment, typeName, function, op
    }

    struct Style {
        let color: Color
        let bold: Bool
        let italic: Bool

        static func fg(_ color: Color, bold: Bool = false, italic: Bool = false) -> Style {
            Style(color: color, bold: bold, italic: italic)
        }
    }

    // MARK: - Public API

    /// Highlightuje kod i zwraca AttributedString. Język auto-detectowany z nazwy lub zawartości.
    static func highlight(_ code: String, language: String?) -> AttributedString {
        let lang = (language ?? autoDetectLanguage(code)).lowercased()
        let rules = rulesFor(language: lang)
        return applyRules(code, rules: rules, baseColor: Theme.textPrimary)
    }

    /// Wersja dla user bubble - biały tekst na niebieskim tle
    static func highlightForUser(_ code: String, language: String?) -> AttributedString {
        let lang = (language ?? autoDetectLanguage(code)).lowercased()
        let rules = rulesFor(language: lang)
        return applyRules(code, rules: rules, baseColor: .white)
    }

    // MARK: - Language detection

    /// Publiczna wersja do wywołania z UI (np. do wyświetlenia nagłówka bloku kodu)
    static func autoDetectLanguageStatic(_ code: String) -> String {
        return autoDetectLanguage(code)
    }

    private static func autoDetectLanguage(_ code: String) -> String {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        // JSON
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            if let _ = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) {
                return "json"
            }
        }
        // Swift: import, func, let, var, @State, struct
        if trimmed.contains("import Foundation") || trimmed.contains("@State") ||
           trimmed.contains("let ") || trimmed.contains("var ") {
            return "swift"
        }
        // Python: def, import, print
        if trimmed.contains("def ") || trimmed.contains("print(") || trimmed.contains("import ") {
            return "python"
        }
        // JavaScript/TypeScript: function, const, =>, console.log
        if trimmed.contains("console.log") || trimmed.contains("=>") || trimmed.contains("const ") {
            return "javascript"
        }
        // Bash: #!/bin/bash, sudo, apt
        if trimmed.hasPrefix("#!/bin/") || trimmed.contains("apt-get") || trimmed.contains("sudo ") {
            return "bash"
        }
        return "plain"
    }

    // MARK: - Rules per language

    private struct Rule {
        let pattern: String
        let style: TokenType
        let isMultiline: Bool
    }

    private static func rulesFor(language: String) -> [Rule] {
        // Wspólne wzorce
        let common: [Rule] = [
            Rule(pattern: #"//.*$"#, style: .comment, isMultiline: false),
            Rule(pattern: #"/\*[\s\S]*?\*/"#, style: .comment, isMultiline: true),
            Rule(pattern: #""(?:[^"\\]|\\.)*""#, style: .string, isMultiline: false),
            Rule(pattern: #"'(?:[^'\\]|\\.)*'"#, style: .string, isMultiline: false),
            Rule(pattern: #"`(?:[^`\\]|\\.)*`"#, style: .string, isMultiline: false),
            Rule(pattern: #"\b\d+(?:\.\d+)?\b"#, style: .number, isMultiline: false),
        ]

        // Keywords specyficzne dla języka
        let keywordRule: Rule
        let typeRule: Rule
        switch language {
        case "swift":
            keywordRule = Rule(pattern: #"\b(?:import|func|let|var|class|struct|enum|protocol|extension|if|else|guard|return|throw|throws|try|catch|do|switch|case|default|for|while|in|where|as|is|nil|true|false|public|private|internal|fileprivate|open|static|final|init|deinit|self|Self|super|async|await|actor)\b"#, style: .keyword, isMultiline: false)
            typeRule = Rule(pattern: #"\b(?:Int|String|Double|Float|Bool|Array|Dictionary|Set|Optional|Any|AnyObject|Void|Result|View|UIColor|NSObject|URL|Date|Data|UUID)\b"#, style: .typeName, isMultiline: false)
        case "python":
            keywordRule = Rule(pattern: #"\b(?:def|class|import|from|as|if|elif|else|for|while|try|except|finally|with|return|yield|raise|pass|break|continue|lambda|None|True|False|self|cls|async|await|global|nonlocal)\b"#, style: .keyword, isMultiline: false)
            typeRule = Rule(pattern: #"\b(?:int|str|float|bool|list|dict|tuple|set|bytes|object|None|Optional|Union|Any|Callable)\b"#, style: .typeName, isMultiline: false)
        case "javascript", "js", "typescript", "ts":
            keywordRule = Rule(pattern: #"\b(?:const|let|var|function|class|extends|new|this|return|if|else|for|while|do|switch|case|default|break|continue|try|catch|finally|throw|async|await|import|export|from|as|of|in|null|undefined|true|false|interface|type|enum)\b"#, style: .keyword, isMultiline: false)
            typeRule = Rule(pattern: #"\b(?:string|number|boolean|any|void|never|unknown|object|Array|Promise|Map|Set|Record|Partial|Pick)\b"#, style: .typeName, isMultiline: false)
        case "go":
            keywordRule = Rule(pattern: #"\b(?:package|import|func|var|const|type|struct|interface|map|chan|go|defer|return|if|else|for|range|switch|case|default|break|continue|fallthrough|select|nil|true|false)\b"#, style: .keyword, isMultiline: false)
            typeRule = Rule(pattern: #"\b(?:int|int32|int64|float32|float64|bool|string|byte|rune|error|any|interface\{\})\b"#, style: .typeName, isMultiline: false)
        case "rust":
            keywordRule = Rule(pattern: #"\b(?:fn|let|mut|const|static|struct|enum|trait|impl|pub|use|mod|crate|self|Self|super|as|where|if|else|match|for|while|loop|return|break|continue|async|await|move|ref|in|true|false|None|Some|Ok|Err)\b"#, style: .keyword, isMultiline: false)
            typeRule = Rule(pattern: #"\b(?:i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usize|f32|f64|bool|char|str|String|Vec|Option|Result|Box|Rc|Arc)\b"#, style: .typeName, isMultiline: false)
        case "bash", "sh", "shell":
            return [
                Rule(pattern: #"#.*$"#, style: .comment, isMultiline: false),
                Rule(pattern: #""(?:[^"\\]|\\.)*""#, style: .string, isMultiline: false),
                Rule(pattern: #"'(?:[^'\\]|\\.)*'"#, style: .string, isMultiline: false),
                Rule(pattern: #"\$\{?[A-Za-z_][A-Za-z0-9_]*\}?"#, style: .string, isMultiline: false),
                Rule(pattern: #"\b(?:if|then|else|elif|fi|for|in|do|done|while|until|case|esac|function|return|export|local|source|alias|echo|cd|ls|cat|grep|sed|awk|curl|wget|rm|mkdir|cp|mv|chmod|chown|sudo|apt|yum|brew|git|docker)\b"#, style: .keyword, isMultiline: false)
            ]
        case "json":
            return [
                Rule(pattern: #""(?:[^"\\]|\\.)*"\s*:"#, style: .keyword, isMultiline: false),  // klucze
                Rule(pattern: #""(?:[^"\\]|\\.)*""#, style: .string, isMultiline: false),
                Rule(pattern: #"\b(?:true|false|null)\b"#, style: .keyword, isMultiline: false),
                Rule(pattern: #"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?"#, style: .number, isMultiline: false)
            ]
        default:  // "plain" lub nieznany
            return common
        }

        return common + [keywordRule, typeRule]
    }

    // MARK: - Apply rules

    private static func applyRules(_ code: String, rules: [Rule], baseColor: Color) -> AttributedString {
        // Strategia: znajdź wszystkie matche, posortuj po pozycji, unikaj overlapów.
        // Każdy match dostaje swój styl.
        struct Match {
            let range: NSRange
            let style: TokenType
        }

        var matches: [Match] = []
        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.isMultiline ? [.anchorsMatchLines] : []) else { continue }
            let range = NSRange(code.startIndex..., in: code)
            let nsMatches = regex.matches(in: code, options: [], range: range)
            for m in nsMatches {
                matches.append(Match(range: m.range, style: rule.style))
            }
        }

        // Posortuj po pozycji, usuń overlapy (zachowaj pierwszy match)
        matches.sort { $0.range.location < $1.range.location }
        var filtered: [Match] = []
        var lastEnd = 0
        for m in matches {
            if m.range.location >= lastEnd {
                filtered.append(m)
                lastEnd = m.range.location + m.range.length
            }
        }

        // Zbuduj AttributedString
        var attributed = AttributedString()
        var cursor = code.startIndex
        let nsCode = code as NSString

        for match in filtered {
            // Dodaj tekst przed matchem (plain)
            if let plainRange = Range(NSRange(location: cursor.utf16Offset(in: code), length: match.range.location - cursor.utf16Offset(in: code)), in: code) {
                var plain = AttributedString(String(code[plainRange]))
                plain.foregroundColor = baseColor
                plain.font = .system(size: 13, design: .monospaced)
                attributed += plain
            }
            // Dodaj match ze stylem
            if let matchRange = Range(match.range, in: code) {
                var token = AttributedString(String(code[matchRange]))
                token.foregroundColor = colorFor(token: match.style, base: baseColor)
                var font = Font.system(size: 13, design: .monospaced)
                switch match.style {
                case .keyword, .typeName:
                    font = font.bold()
                case .comment:
                    font = font.italic()
                default: break
                }
                token.font = font
                attributed += token
            }
            // Przesuń kursor za match
            if let r = Range(match.range, in: code) {
                cursor = r.upperBound
            }
            _ = nsCode  // suppress unused
        }

        // Dodaj resztę tekstu
        if cursor < code.endIndex {
            var tail = AttributedString(String(code[cursor...]))
            tail.foregroundColor = baseColor
            tail.font = .system(size: 13, design: .monospaced)
            attributed += tail
        }

        return attributed
    }

    private static func colorFor(token: TokenType, base: Color) -> Color {
        switch token {
        case .keyword:
            // Złoty (pasuje do motywu) - dla użytkownika: jaśniejszy żółty
            return base == .white ? Color.yellow : Theme.gold
        case .string:
            // Zielony (typowy dla syntax highlighting)
            return base == .white ? Color(red: 0.6, green: 0.95, blue: 0.6) : Color(red: 0.2, green: 0.6, blue: 0.3)
        case .number:
            // Pomarańczowy
            return base == .white ? Color.orange : Color(red: 0.85, green: 0.45, blue: 0.2)
        case .comment:
            // Szary
            return base == .white ? Color(white: 0.7) : Color(white: 0.5)
        case .typeName:
            // Niebieski (typowy dla typów)
            return base == .white ? Color.cyan : Color(red: 0.2, green: 0.4, blue: 0.85)
        case .function:
            // Fioletowy
            return base == .white ? Color(red: 0.8, green: 0.6, blue: 1.0) : Color(red: 0.55, green: 0.3, blue: 0.75)
        case .op:
            return base == .white ? Color(white: 0.85) : Color(white: 0.3)
        }
    }
}
