import Foundation
import os

enum LogLevel {
    case debug, info, error
}

struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.minichat"
    private static let defaultCategory = "MiniChat"
    private static let osLogger = os.Logger(subsystem: subsystem, category: defaultCategory)

    static func log(_ message: String, category: String = defaultCategory, redact: Bool = false, level: LogLevel = .info) {
        let msg = redact ? redactSensitive(message) : message
        let prefix: String
        switch level {
        case .debug: prefix = "🔍"
        case .info: prefix = "ℹ️"
        case .error: prefix = "❌"
        }
        print("\(prefix) [\(category)] \(msg)")
    }

    private static func redactSensitive(_ s: String) -> String {
        var out = s
        if let range = out.range(of: "Bearer ") {
            let after = out[range.upperBound...]
            if let end = after.firstIndex(where: { $0 == " " || $0 == "," || $0 == "\n" }) {
                let token = after[..<end]
                out = out.replacingOccurrences(of: String(token), with: "[REDACTED]")
            } else {
                out = out.replacingOccurrences(of: String(after), with: "[REDACTED]")
            }
        }
        let longBase64Pattern = "[A-Za-z0-9+/=\\\\-]{200,}"
        if let regex = try? NSRegularExpression(pattern: longBase64Pattern) {
            let range = NSRange(location: 0, length: (out as NSString).length)
            out = regex.stringByReplacingMatches(in: out, options: [], range: range, withTemplate: "[BASE64_TRUNC]")
        }
        return out
    }
}
