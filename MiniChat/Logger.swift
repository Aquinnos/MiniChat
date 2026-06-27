import Foundation
import os

enum LogLevel {
    case debug, info, error
}

struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.minichat"
    private static let defaultCategory = "MiniChat"
    private static let osLogger = os.Logger(subsystem: subsystem, category: defaultCategory)

    // Precompiled regex dla redakcji - unika kosztownej kompilacji per call.
    // Kompilacja NSRegularExpression trwa ~1ms, a redactor jest wywolywany
    // przy kazdym logu z redact:true (np. przy API errors z tokenami).
    private static let base64Pattern = "[A-Za-z0-9+/=\\\\-]{200,}"
    private static let longBase64Regex: NSRegularExpression = {
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: base64Pattern)
    }()

    static func log(_ message: String, category: String = defaultCategory, redact: Bool = false, level: LogLevel = .info) {
        let msg = redact ? redactSensitive(message) : message
        let prefix: String
        switch level {
        case .debug: prefix = "[DEBUG]"
        case .info: prefix = "[INFO]"
        case .error: prefix = "[ERROR]"
        }
        // Use os.Logger convenience methods for level
        switch level {
        case .debug:
            osLogger.debug("\(prefix) [\(category)] \(msg)")
        case .info:
            osLogger.info("\(prefix) [\(category)] \(msg)")
        case .error:
            osLogger.error("\(prefix) [\(category)] \(msg)")
        }
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
        let range = NSRange(location: 0, length: (out as NSString).length)
        out = longBase64Regex.stringByReplacingMatches(in: out, options: [], range: range, withTemplate: "[BASE64_TRUNC]")
        return out
    }
}
