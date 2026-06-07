import Foundation
import os

enum LogLevel {
    case debug, info, error
}

struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.minichat"
    private static let defaultCategory = "MiniChat"
    static func log(_ message: String, category: String = defaultCategory, redact: Bool = false, level: OSLogType = .default) {
        let msg = redact ? redactSensitive(message) : message
        if #available(iOS 14.0, macOS 11.0, *) {
            let logger = os.Logger(subsystem: subsystem, category: category)
            switch level {
            case .debug:
                logger.debug("%{public}@(msg)", msg)
            case .info:
                logger.info("%{public}@(msg)", msg)
            case .error:
                logger.error("%{public}@(msg)", msg)
            default:
                logger.log("%{public}@(msg)", msg)
            }
        } else {
            // Fallback
            print("[\(category)] \(msg)")
        }
    }

    // Simple redaction heuristics
    private static func redactSensitive(_ s: String) -> String {
        var out = s
        // Redact Bearer tokens
        if let range = out.range(of: "Bearer ") {
            // find token after Bearer
            let after = out[range.upperBound...]
            if let end = after.firstIndex(where: { $0 == " " || $0 == "," || $0 == "\n" }) {
                let token = after[..<end]
                out = out.replacingOccurrences(of: String(token), with: "[REDACTED]")
            } else {
                out = out.replacingOccurrences(of: String(after), with: "[REDACTED]")
            }
        }
        // Truncate long base64-ish strings
        let longBase64Pattern = "[A-Za-z0-9+/=\\\\-]{200,}"
        if let regex = try? NSRegularExpression(pattern: longBase64Pattern) {
            let range = NSRange(location: 0, length: (out as NSString).length)
            out = regex.stringByReplacingMatches(in: out, options: [], range: range, withTemplate: "[BASE64_TRUNC]")
        }
        return out
    }
}
