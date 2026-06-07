//
//  MiniMaxAPIClient.swift
//  MiniChat
//
//  Klient HTTP dla MiniMax ChatCompletion API z obsługą streamingu SSE.
//  Wersja z verbose logami i non-streaming fallback.
//

import Foundation
import os


// MARK: - Models

enum MiniMaxModel: String, CaseIterable, Identifiable, Codable {
    case m3 = "MiniMax-M3"
    case m27 = "MiniMax-M2.7"
    case m27Highspeed = "MiniMax-M2.7-highspeed"
    case m2 = "MiniMax-M2"
    case m2her = "M2-her"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .m3: return "M3"
        case .m27: return "M2.7"
        case .m27Highspeed: return "M2.7 HighSpeed"
        case .m2: return "M2"
        case .m2her: return "M2-her (roleplay)"
        }
    }

    var isReasoning: Bool {
        switch self {
        case .m3, .m27, .m27Highspeed, .m2: return true
        case .m2her: return false
        }
    }

    /// Czy model obsługuje załączniki (obrazki, pliki)
    var supportsAttachments: Bool {
        switch self {
        case .m3: return true
        case .m27, .m27Highspeed, .m2, .m2her: return false
        }
    }

    var description: String {
        switch self {
        case .m3: return "Flagowy — kod, agenci, 1M kontekst, 📎 obrazy i pliki"
        case .m27: return "Poprzedni flagowy, dobry do złożonych zadań"
        case .m27Highspeed: return "M2.7 zoptymalizowany pod szybkość"
        case .m2: return "Stabilny, sprawdzony model"
        case .m2her: return "Tryb rozmowy / roleplay"
        }
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String?)
    case baseResp(code: Int, message: String)
    case decodingError(String)
    case streamingError(String)
    case noData
    case noInternet
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Brak API key. Ustaw go w ustawieniach."
        case .invalidURL:
            return "Nieprawidłowy URL."
        case .invalidResponse:
            return "Nieprawidłowa odpowiedź z serwera."
        case .httpStatus(let code, let body):
            if let body, !body.isEmpty {
                return "HTTP \(code): \(body.prefix(200))"
            }
            return "HTTP \(code)"
        case .baseResp(let code, let message):
            let msg = translateErrorCode(code)
            return msg.isEmpty ? "Błąd API (\(code)): \(message)" : msg
        case .decodingError(let detail):
            return "Błąd dekodowania: \(detail)"
        case .streamingError(let detail):
            return "Błąd streamingu: \(detail)"
        case .noData:
            return "Brak danych w odpowiedzi."
        case .noInternet:
            return "Brak połączenia z internetem."
        case .timeout:
            return "Timeout — model nie odpowiedział w ciągu 60s."
        }
    }

    private func translateErrorCode(_ code: Int) -> String {
        switch code {
        case 1000: return "Nieznany błąd serwera"
        case 1001: return "Timeout — spróbuj ponownie"
        case 1002: return "Limit zapytań — poczekaj chwilę"
        case 1004: return "Błędny klucz API. Sprawdź Ustawienia."
        case 1008: return "Brak środków na koncie. Doładuj konto."
        case 1013: return "Błąd wewnętrzny serwera — spróbuj później"
        case 1027: return "Niedozwolona treść w odpowiedzi"
        case 1039: return "Przekroczono limit tokenów"
        case 2013: return "Nieprawidłowe parametry zapytania"
        default: return ""
        }
    }
}

// MARK: - Stream Chunk

struct StreamChunk {
    let content: String
    let reasoningContent: String
    let finishReason: String?
    let toolCalls: [ToolCall]
    let isToolExecuting: Bool
    let generatedImages: [GeneratedImage]

    init(
        content: String = "",
        reasoningContent: String = "",
        finishReason: String? = nil,
        toolCalls: [ToolCall] = [],
        isToolExecuting: Bool = false,
        generatedImages: [GeneratedImage] = []
    ) {
        self.content = content
        self.reasoningContent = reasoningContent
        self.finishReason = finishReason
        self.toolCalls = toolCalls
        self.isToolExecuting = isToolExecuting
        self.generatedImages = generatedImages
    }

    var isEmpty: Bool {
        content.isEmpty && reasoningContent.isEmpty && toolCalls.isEmpty && generatedImages.isEmpty
    }
}

// MARK: - Tool Call

struct ToolCall: Codable {
    let id: String
    let type: String
    let function: Function

    struct Function: Codable {
        let name: String
        let arguments: String  // JSON string
    }
}

// MARK: - Tool definition (OpenAI-compatible)

enum MiniMaxTool {
    static let webSearch: [String: Any] = [
        "type": "function",
        "function": [
            "name": "web_search",
            "description": "Search the web for TEXT INFORMATION only - news, facts, current events, articles, prices, weather, recent developments. Use this when the user wants to READ or KNOW about something. DO NOT use this tool for images, pictures, photos, wallpapers, art, or any visual content - those require generate_image. Examples: 'what's the news today', 'price of bitcoin 2026', 'how does X work', 'latest iPhone reviews'.",
            "parameters": [
                "type": "object",
                "properties": [
                    "query": [
                        "type": "string",
                        "description": "The search query. Be specific and include year/current month when relevant. Examples: 'reddit trending posts November 2026', 'iPhone 16 release date', 'Bitcoin price today'"
                    ]
                ],
                "required": ["query"]
            ]
        ]
    ]

    static let generateImage: [String: Any] = [
        "type": "function",
        "function": [
            "name": "generate_image",
            "description": "Generate, create, draw or paint an IMAGE/PICTURE/PHOTO/ILLUSTRATION/POSTER/LOGO/WALLPAPER/AVATAR from a text description. YOU MUST USE THIS TOOL whenever the user asks for any VISUAL content, including: image, picture, photo, illustration, poster, logo, wallpaper, avatar, artwork, drawing, painting. This includes requests phrased as: 'show me', 'find me', 'I want', 'give me' + image-related noun. You MUST NOT describe the image in text alone - you MUST call this tool. After generating, briefly describe the result.",
            "parameters": [
                "type": "object",
                "properties": [
                    "prompt": [
                        "type": "string",
                        "description": "Detailed description in English of the image to generate. Be specific about subject, style, lighting, composition, colors, mood. Max 1500 chars. For requests about real people, fictional characters, or copyrighted IP, generate a clearly-described variation (e.g. 'a young wizard with round glasses and a lightning scar, in a magical school uniform') rather than the exact character."
                    ],
                    "aspect_ratio": [
                        "type": "string",
                        "enum": ["1:1", "16:9", "4:3", "3:2", "2:3", "3:4", "9:16", "21:9"],
                        "description": "Aspect ratio. '1:1' for square, '16:9' for desktop wallpaper/landscape, '9:16' for phone wallpaper/portrait, '3:2' or '4:3' for photos."
                    ]
                ],
                "required": ["prompt"]
            ]
        ]
    ]

    static let getCurrentTime: [String: Any] = [
        "type": "function",
        "function": [
            "name": "get_current_time",
            "description": "Returns the current date, time, day of week, and timezone. Use this whenever you need to know the current date or time, schedule something, calculate time differences, or answer questions like 'today', 'tomorrow', 'next week', 'how long ago'. You do NOT know the current date without calling this tool - your training data is outdated.",
            "parameters": [
                "type": "object",
                "properties": [
                    "format": [
                        "type": "string",
                        "enum": ["full", "date_only", "time_only", "iso8601", "timestamp"],
                        "description": "Output format. 'full' (default) = human-readable date+time+day, 'date_only' = just YYYY-MM-DD, 'time_only' = just HH:MM:SS, 'iso8601' = ISO 8601 string, 'timestamp' = Unix epoch seconds."
                    ]
                ],
                "required": []
            ]
        ]
    ]

    static let readFile: [String: Any] = [
        "type": "function",
        "function": [
            "name": "read_file",
            "description": "Reads the TEXT content of a file previously attached to the conversation by the user. Use this to access the contents of attached documents, code files, CSVs, JSONs, logs, configuration files, etc. The file is identified by its filename (visible in the user message as 📎 filename). For binary files (images, PDFs) that were already shown to you as attachments, you do NOT need this tool - their content is already in your context.",
            "parameters": [
                "type": "object",
                "properties": [
                    "file_name": [
                        "type": "string",
                        "description": "The exact filename of the attached file to read (including extension), e.g. 'main.swift', 'data.csv', 'config.json'. Match the filename shown next to the 📎 emoji in the user message."
                    ],
                    "max_chars": [
                        "type": "integer",
                        "description": "Maximum characters to return. Default 8000. Use a smaller value for very large files, or larger (up to 50000) when you need more context."
                    ]
                ],
                "required": ["file_name"]
            ]
        ]
    ]
}

// MARK: - Image tool result (wewnętrzny)

struct GeneratedImage: Codable, Hashable {
    let base64Data: String
    let mimeType: String
    let prompt: String
}

// MARK: - API Client

final class MiniMaxAPIClient {
    // URL API - konfigurowalny w Ustawieniach (niektóre DNS-y nie widzą .io)
    static let defaultBaseURL = "https://api.minimaxi.com/v1/text/chatcompletion_v2"
    static let alternativeBaseURL = "https://api.minimax.io/v1/text/chatcompletion_v2"

    private var baseURLString: String {
        UserDefaults.standard.string(forKey: "api_base_url") ?? Self.defaultBaseURL
    }
    private var baseURL: URL? { URL(string: baseURLString) }
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    /// Wysyła wiadomości do API i zwraca strumień kawałków.
    /// `enableTools` - jeśli true, dodaje wszystkie domyślne narzędzia (4) i obsługuje tool_use loop
    /// `toolsOverride` - jeśli ustawione, używa TYLKO tych tools (niezależnie od enableTools)
    func streamChatCompletion(
        messages: [Message],
        apiKey: String,
        model: MiniMaxModel,
        enableTools: Bool = false,
        toolsOverride: [[String: Any]]? = nil
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let toolCount = toolsOverride?.count ?? (enableTools ? 4 : 0)
                    Logger.log("Starting stream, model=\(model.rawValue), msgs=\(messages.count), tools=\(toolCount)", category: "MiniMax", redact: true)
                    try await performStreamWithTools(
                        messages: messages,
                        apiKey: apiKey,
                        model: model,
                        enableTools: enableTools,
                        toolsOverride: toolsOverride,
                        continuation: continuation
                    )
                    Logger.log("Stream finished", category: "MiniMax")
                    continuation.finish()
                } catch is CancellationError {
                    Logger.log("Stream cancelled", category: "MiniMax")
                    continuation.finish()
                } catch {
                    Logger.log("Stream error: \(error.localizedDescription)", category: "MiniMax", level: .error)


                    if let apiErr = error as? APIError,
                       case .timeout = apiErr {
                        Logger.log("Falling back to non-streaming…", category: "MiniMax")
                        do {
                            let fullText = try await performNonStream(
                                messages: messages,
                                apiKey: apiKey,
                                model: model
                            )
                            if !fullText.isEmpty {
                                continuation.yield(StreamChunk(
                                    content: fullText,
                                    reasoningContent: "",
                                    finishReason: "stop"
                                ))
                            }
                        } catch {
                            Logger.log("Non-stream fallback also failed: \(error.localizedDescription)", category: "MiniMax", level: .error)
                        }
                    }
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Streaming

    /// Główna logika: wykonuje request z tools (web_search, generate_image)
    private func performStreamWithTools(
        messages: [Message],
        apiKey: String,
        model: MiniMaxModel,
        enableTools: Bool,
        toolsOverride: [[String: Any]]? = nil,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {
        guard !apiKey.isEmpty else { throw APIError.missingAPIKey }

        let apiMessages = buildAPIMessages(from: messages, model: model)

        // Ustal listę tools: override > domyślne (gdy enableTools) > puste
        let tools: [[String: Any]]
        if let override = toolsOverride {
            tools = override
        } else if enableTools {
            tools = [MiniMaxTool.webSearch, MiniMaxTool.generateImage, MiniMaxTool.getCurrentTime, MiniMaxTool.readFile]
        } else {
            tools = []
        }

        // Flat lista załączników z całej konwersacji (dla read_file tool)
        let allAttachments = messages.flatMap { $0.attachments }

        // PIERWSZY REQUEST
        // Jeśli tools włączone, BUFORUJ content (nie yieluj od razu) - zobaczymy czy były tool_calls
        // Jeśli były - pokażemy reasoning + "🔍/🎨" + drugi stream (odpowiedź)
        // Jeśli nie - pokażemy zebrany content normalnie
        let shouldBuffer = !tools.isEmpty
        let (firstResponse, firstFinishReason, firstToolCalls) = try await performSingleStream(
            messages: apiMessages,
            apiKey: apiKey,
            model: model,
            tools: tools,
            continuation: continuation,
            bufferContent: shouldBuffer
        )

        // Sprawdź tool_calls
        let toolCall = firstToolCalls.first(where: {
            $0.function.name == "web_search" ||
            $0.function.name == "generate_image" ||
            $0.function.name == "get_current_time" ||
            $0.function.name == "read_file"
        })

        guard let toolCall = toolCall, !tools.isEmpty else {
            // Brak tool_call - wyślij buforowany content (jeśli był buforowany)
            if shouldBuffer && !firstResponse.isEmpty {
                continuation.yield(StreamChunk(
                    content: firstResponse,
                    isToolExecuting: false
                ))
            }
            return
        }

        // Wykonaj tool
        let toolResult = try await executeTool(
            toolCall: toolCall,
            apiKey: apiKey,
            attachments: allAttachments
        )

        // Yield "executing" message
        let displayMessage = displayMessageForTool(toolCall, result: toolResult)
        if !displayMessage.isEmpty {
            continuation.yield(StreamChunk(
                content: displayMessage,
                isToolExecuting: true
            ))
        }

        // Yield wygenerowane obrazy
        if !toolResult.images.isEmpty {
            continuation.yield(StreamChunk(
                content: "",
                isToolExecuting: false,
                generatedImages: toolResult.images
            ))
        }

        // Wyślij tool result z powrotem do modelu
        let messagesWithToolResult = apiMessages + [
            [
                "role": "assistant",
                "name": "MiniMax AI",
                "content": firstResponse.isEmpty ? " " : firstResponse,
                "tool_calls": [[
                    "id": toolCall.id,
                    "type": "function",
                    "function": [
                        "name": toolCall.function.name,
                        "arguments": toolCall.function.arguments
                    ]
                ]]
            ],
            [
                "role": "tool",
                "tool_call_id": toolCall.id,
                "content": toolResult.textResult
            ]
        ]

        continuation.yield(StreamChunk(content: "", isToolExecuting: false))

        // DRUGI REQUEST - streaming finalnej odpowiedzi (normalnie yielujemy)
        _ = try await performSingleStream(
            messages: messagesWithToolResult,
            apiKey: apiKey,
            model: model,
            tools: tools,
            continuation: continuation
        )
    }

    /// Wykonuje tool call i zwraca tekst do zwrócenia do modelu + ewentualne obrazy
    private struct ToolExecutionResult {
        let textResult: String
        let images: [GeneratedImage]
    }

    private func executeTool(toolCall: ToolCall, apiKey: String, attachments: [Attachment] = []) async throws -> ToolExecutionResult {
        guard let argsData = toolCall.function.arguments.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            return ToolExecutionResult(textResult: "Błąd: nieprawidłowe argumenty", images: [])
        }

        switch toolCall.function.name {
        case "web_search":
            guard let query = args["query"] as? String else {
                return ToolExecutionResult(textResult: "Brak argumentu 'query'", images: [])
            }
            Logger.log("Web search query: \(query.prefix(200))", category: "MiniMax", redact: true)
            do {
                let results = try await WebSearch.smartSearch(query: query)
                let formatted = WebSearcher.formatResults(results)
                return ToolExecutionResult(textResult: formatted, images: [])
            } catch {
                Logger.log("Web search failed: \(error)", category: "MiniMax", redact: true, level: .error)
                return ToolExecutionResult(textResult: "Błąd wyszukiwania: \(error.localizedDescription)", images: [])
            }

        case "generate_image":
            guard let prompt = args["prompt"] as? String else {
                return ToolExecutionResult(textResult: "Brak argumentu 'prompt'", images: [])
            }
            let aspectRatio = (args["aspect_ratio"] as? String) ?? "1:1"
            Logger.log("Generate image prompt: \(prompt.prefix(80))", category: "MiniMax", redact: true, level: .debug)
            do {
                let result = try await ImageGenerator.shared.generate(
                    prompt: prompt,
                    apiKey: apiKey,
                    aspectRatio: aspectRatio,
                    useBase64: true
                )
                var images: [GeneratedImage] = []
                var textResult = "Wygenerowałem obraz: \"\(prompt)\""

                if let b64 = result.base64Data {
                    images.append(GeneratedImage(
                        base64Data: b64,
                        mimeType: result.mimeType,
                        prompt: prompt
                    ))
                    textResult += "\n\n[Obraz wygenerowany pomyślnie — wyświetlony w czacie]"
                } else if let url = result.imageURL {
                    textResult += "\n\n[Obraz dostępny pod URL: \(url) — URL wygasa po 24h]"
                }

                return ToolExecutionResult(textResult: textResult, images: images)
            } catch {
                Logger.log("Image generation failed: \(error)", category: "MiniMax", redact: true, level: .error)
                return ToolExecutionResult(textResult: "Błąd generowania obrazu: \(error.localizedDescription)", images: [])
            }

        case "get_current_time":
            let format = (args["format"] as? String) ?? "full"
            Logger.log("Get current time (format: \(format))", category: "MiniMax", level: .debug)
            let now = Date()
            let result: String
            switch format {
            case "date_only":
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "pl_PL")
                f.timeZone = TimeZone.current
                result = f.string(from: now)
            case "time_only":
                let f = DateFormatter()
                f.dateFormat = "HH:mm:ss"
                f.timeZone = TimeZone.current
                result = f.string(from: now)
            case "iso8601":
                let f = ISO8601DateFormatter()
                result = f.string(from: now)
            case "timestamp":
                result = String(Int(now.timeIntervalSince1970))
            default:  // "full"
                let f = DateFormatter()
                f.dateFormat = "EEEE, d MMMM yyyy 'o' HH:mm:ss"
                f.locale = Locale(identifier: "pl_PL")
                f.timeZone = TimeZone.current
                let tzName = TimeZone.current.identifier
                result = "\(f.string(from: now)) (strefa: \(tzName))"
            }
            return ToolExecutionResult(textResult: "🕐 \(result)", images: [])

        case "read_file":
            guard let fileName = args["file_name"] as? String else {
                return ToolExecutionResult(textResult: "Brak argumentu 'file_name'", images: [])
            }
            let maxChars = (args["max_chars"] as? Int) ?? 8000
            Logger.log("Read file request: \(fileName) (maxChars: \(maxChars))", category: "MiniMax", redact: true, level: .debug)

            // Szukaj załącznika po nazwie
            guard let attachment = attachments.first(where: { $0.fileName == fileName }) else {
                let available = attachments.map { $0.fileName }.joined(separator: ", ")
                let availMsg = available.isEmpty ? "Brak załączonych plików w konwersacji." : "Dostępne pliki: \(available)"
                return ToolExecutionResult(textResult: "❌ Nie znaleziono pliku '\(fileName)'. \(availMsg)", images: [])
            }
            guard let base64 = attachment.base64Data, let data = Data(base64Encoded: base64) else {
                return ToolExecutionResult(textResult: "❌ Nie można odczytać danych pliku '\(fileName)'", images: [])
            }
            // Sprawdź czy to tekst
            guard let text = String(data: data, encoding: .utf8) else {
                let mime = attachment.mimeType
                return ToolExecutionResult(textResult: "📄 Plik '\(fileName)' (\(data.count) bajtów, \(mime)) nie jest tekstem UTF-8. Nie można wyświetlić zawartości.", images: [])
            }
            // Zwróć preview
            let total = text.count
            if total > maxChars {
                let preview = String(text.prefix(maxChars))
                return ToolExecutionResult(
                    textResult: "📄 \(fileName) — \(total) znaków (pokazano pierwsze \(maxChars)):\n\n```\n\(preview)\n... (obcięto, \(total - maxChars) znaków zostało)\n```",
                    images: []
                )
            }
            return ToolExecutionResult(
                textResult: "📄 \(fileName) — \(total) znaków:\n\n```\n\(text)\n```",
                images: []
            )

        default:
            return ToolExecutionResult(textResult: "Nieznane narzędzie: \(toolCall.function.name)", images: [])
        }
    }

    /// Krótka wiadomość do wyświetlenia w UI podczas wykonywania tool
    private func displayMessageForTool(_ toolCall: ToolCall, result: ToolExecutionResult) -> String {
        switch toolCall.function.name {
        case "web_search":
            return "🔍 Szukam: \(extractQueryFromArgs(toolCall.function.arguments))\n\n"
        case "generate_image":
            if !result.images.isEmpty {
                return "🎨 Generuję obraz...\n\n"
            }
            return ""
        case "get_current_time":
            return "🕐 Pobieram czas...\n\n"
        case "read_file":
            if let data = toolCall.function.arguments.data(using: .utf8),
               let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = args["file_name"] as? String {
                return "📂 Czytam plik: \(name)\n\n"
            }
            return "📂 Czytam plik...\n\n"
        default:
            return ""
        }
    }

    private func extractQueryFromArgs(_ args: String) -> String {
        if let data = args.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let q = dict["query"] as? String {
            return q
        }
        return ""
    }

    /// Wykonuje pojedynczy streaming request.
    /// Parametr `bufferContent` - jeśli true, content jest zbierany w pamięci ale NIE yielowany
    /// (używane dla pierwszego streama, żeby zobaczyć czy były tool_calls przed wyświetleniem).
    /// Zwraca zebrany content - caller decyduje czy go yielować.
    private func performSingleStream(
        messages: [[String: Any]],
        apiKey: String,
        model: MiniMaxModel,
        tools: [[String: Any]],
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation,
        bufferContent: Bool = false
    ) async throws -> (content: String, finishReason: String?, toolCalls: [ToolCall]) {
        var body: [String: Any] = [
            "model": model.rawValue,
            "messages": messages,
            "stream": true
        ]
        if !tools.isEmpty {
            body["tools"] = tools
        }

        guard let url = URL(string: baseURLString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        Logger.log("Sending streaming request (tools=\(tools.count))", category: "MiniMax", redact: true, level: .debug)

        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        Logger.log("HTTP \(httpResponse.statusCode)", category: "MiniMax", redact: true)
        let ct = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "?"
        Logger.log("Content-Type: \(ct)", category: "MiniMax", redact: true)

        guard (200...299).contains(httpResponse.statusCode) else {
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
                if errorBody.count > 1000 { break }
            }
            throw APIError.httpStatus(httpResponse.statusCode, errorBody)
        }

        // Stream SSE
        var chunkCount = 0
        var totalContent = 0
        var totalReasoning = 0
        var lineCount = 0
        var firstLineLogged = false
        var allContent = ""
        var toolCallsMap: [Int: (id: String, name: String, args: String)] = [:]
        var finishReason: String?
        let streamTimeout: TimeInterval = 60
        let maxBufferSize = 100_000 // limit buffered content to 100 KB
        var bufferTruncatedLogged = false

        for try await line in bytes.lines {
            if Task.isCancelled { break }
            lineCount += 1
            let lastChunkTime = Date()

            if !firstLineLogged && lineCount <= 3 {
            // Avoid printing potentially sensitive payloads; only log line length and index
            Logger.log("Line #\(lineCount) (len=\(line.count))", category: "MiniMax", redact: true, level: .debug)
            if lineCount == 3 { firstLineLogged = true }
            }

            if Date().timeIntervalSince(lastChunkTime) > streamTimeout {
                Logger.log("Stream timeout", category: "MiniMax", level: .error)
                if chunkCount == 0 { throw APIError.timeout }
                break
            }

            if line.hasPrefix("data:") {
                let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                if payload == "[DONE]" { break }
                if payload.isEmpty { continue }

                if let parsed = parseSSEDataFull(payload) {
                    chunkCount += 1
                    totalContent += parsed.content.count
                    totalReasoning += parsed.reasoning.count
                    // Append to buffer with limit to avoid unbounded memory growth
                    if allContent.count + parsed.content.count <= maxBufferSize {
                        allContent += parsed.content
                    } else {
                        let remaining = max(0, maxBufferSize - allContent.count)
                        if remaining > 0 {
                            allContent += String(parsed.content.prefix(remaining))
                        }
                        if !bufferTruncatedLogged {
                            Logger.log("Buffer limit exceeded (\(maxBufferSize) chars). Truncating further tool output.", category: "MiniMax", level: .error)
                            bufferTruncatedLogged = true
                        }
                    }

                    // Yield do UI - zależy od trybu
                    if bufferContent {
                        // Buforujemy - nie yielujemy content. Tylko reasoning (dla widocznego "myślenia")
                        if !parsed.reasoning.isEmpty {
                            continuation.yield(StreamChunk(
                                content: "",
                                reasoningContent: parsed.reasoning
                            ))
                        }
                    } else {
                        if !parsed.content.isEmpty || !parsed.reasoning.isEmpty {
                            continuation.yield(StreamChunk(
                                content: parsed.content,
                                reasoningContent: parsed.reasoning
                            ))
                        }
                    }

                    if let reason = parsed.finishReason {
                        finishReason = reason
                    }

                    // Zbieraj tool_calls (z poprawnym mergowaniem partial deltas)
                    for tc in parsed.toolCalls {
                        if let existing = toolCallsMap[tc.index] {
                            // Kolejne deltas mogą mieć puste name/id (przyszły w pierwszym delta)
                            // Zachowaj poprzednie wartości jeśli nowe są puste
                            toolCallsMap[tc.index] = (
                                id: tc.id.isEmpty ? existing.id : tc.id,
                                name: tc.name.isEmpty ? existing.name : tc.name,
                                args: existing.args + tc.argsDelta
                            )
                        } else {
                            toolCallsMap[tc.index] = (id: tc.id, name: tc.name, args: tc.argsDelta)
                        }
                    }
                }
            }
        }

        Logger.log("Stream ended: \(chunkCount) chunks, \(totalContent) content, \(totalReasoning) reasoning, \(lineCount) lines", category: "MiniMax")

        // Złóż tool_calls
        var toolCalls: [ToolCall] = []
        for (index, data) in toolCallsMap {
            toolCalls.append(ToolCall(
                id: data.id,
                type: "function",
                function: .init(name: data.name, arguments: data.args)
            ))
            _ = index
        }
        toolCalls.sort { $0.id < $1.id }

        return (allContent, finishReason, toolCalls)
    }

    // Stary performStream (dla kompatybilności)
    // Stary performStream - deleguje do nowej logiki
    private func performStream(
        messages: [Message],
        apiKey: String,
        model: MiniMaxModel,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {
        try await performStreamWithTools(
            messages: messages,
            apiKey: apiKey,
            model: model,
            enableTools: false,
            continuation: continuation
        )
    }

    /// Pomocnik: dołącza tekst do pierwszego elementu typu "text" w contentArray.
    /// Jeśli nie ma jeszcze elementu text - tworzy go z oryginalnej treści user message.
    private func appendToFirstText(_ contentArray: inout [[String: Any]], text: String, originalContent: String) {
        if contentArray.isEmpty {
            contentArray.append(["type": "text", "text": originalContent + text])
        } else if var first = contentArray.first,
                  first["type"] as? String == "text",
                  let existing = first["text"] as? String {
            first["text"] = existing + text
            contentArray[0] = first
        }
    }

    /// Buduje tablicę wiadomości w formacie API
    private func buildAPIMessages(from messages: [Message], model: MiniMaxModel) -> [[String: Any]] {
        messages.map { msg in
            var dict: [String: Any] = [
                "role": msg.role.rawValue
            ]
            if msg.role == .system { dict["name"] = "MiniMax AI" }
            else if msg.role == .user { dict["name"] = "User" }
            else if msg.role == .assistant { dict["name"] = "MiniMax AI" }

            if !msg.attachments.isEmpty {
                var contentArray: [[String: Any]] = []
                if !msg.content.isEmpty {
                    contentArray.append(["type": "text", "text": msg.content])
                }
                for att in msg.attachments {
                    if att.isImage, let base64 = att.base64Data, model.supportsAttachments {
                        // M3 - wyślij obraz jako image_url
                        contentArray.append([
                            "type": "image_url",
                            "image_url": ["url": "data:\(att.mimeType);base64,\(base64)"]
                        ])
                    } else if let text = att.textContent {
                        // Plik tekstowy (txt, json, csv, pdf z wyciągniętym tekstem) - wstaw treść
                        let fileDesc = "\n\n[Plik: \(att.fileName)]\n```\n\(text)\n```"
                        appendToFirstText(&contentArray, text: fileDesc, originalContent: msg.content)
                    } else if att.base64Data != nil {
                        // Plik binarny (PDF, DOCX, PPTX, XLSX, image dla non-M3) bez tekstu
                        let fileInfo = "\n\n📎 Załączony plik: \(att.fileName) (typ: \(att.mimeType)). Użyj narzędzia read_file(file_name=\"\(att.fileName)\") żeby odczytać jego zawartość."
                        appendToFirstText(&contentArray, text: fileInfo, originalContent: msg.content)
                    }
                }
                dict["content"] = contentArray
            } else {
                dict["content"] = msg.content
            }
            return dict
        }
    }

    /// Parsuje linię SSE i zwraca pełne dane (content, reasoning, tool_calls, finish_reason)
    private struct SSEDataFull {
        let content: String
        let reasoning: String
        let toolCalls: [PartialToolCall]
        let finishReason: String?

        struct PartialToolCall {
            let index: Int
            let id: String
            let name: String
            let argsDelta: String
        }
    }

    private func parseSSEDataFull(_ json: String) -> SSEDataFull? {
        guard let data = json.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var content = ""
        var reasoning = ""
        var toolCalls: [SSEDataFull.PartialToolCall] = []
        var finishReason: String?

        if let choices = obj["choices"] as? [[String: Any]] {
            for choice in choices {
                if let reason = choice["finish_reason"] as? String {
                    finishReason = reason
                }
                if let delta = choice["delta"] as? [String: Any] {
                    if let r = delta["reasoning_content"] as? String { reasoning += r }
                    if let c = delta["content"] as? String { content += c }
                    if let calls = delta["tool_calls"] as? [[String: Any]] {
                        for call in calls {
                            let index = (call["index"] as? Int) ?? 0
                            let id = (call["id"] as? String) ?? ""
                            var name = ""
                            var args = ""
                            if let fn = call["function"] as? [String: Any] {
                                name = (fn["name"] as? String) ?? ""
                                args = (fn["arguments"] as? String) ?? ""
                            }
                            toolCalls.append(.init(index: index, id: id, name: name, argsDelta: args))
                        }
                    }
                }
            }
        }

        return SSEDataFull(content: content, reasoning: reasoning, toolCalls: toolCalls, finishReason: finishReason)
    }

    // Debug helper exposed for tests (only returns summary, safe for test assertions)
    #if DEBUG
    func debug_parseSSEDataFull(_ json: String) -> (content: String, reasoning: String, toolCallsCount: Int, finishReason: String?)? {
        guard let parsed = parseSSEDataFull(json) else { return nil }
        return (parsed.content, parsed.reasoning, parsed.toolCalls.count, parsed.finishReason)
    }
    #endif

    private func parseSSELine(_ json: String) -> StreamChunk? {
        guard let data = json.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var content = ""
        var reasoning = ""
        var finishReason: String?

        if let baseResp = obj["base_resp"] as? [String: Any],
           let statusCode = baseResp["status_code"] as? Int,
           statusCode != 0 {
            let statusMsg = baseResp["status_msg"] as? String ?? ""
        Logger.log("base_resp=\(statusCode): \(statusMsg)", category: "MiniMax", redact: true, level: .error)
        }

        if let choices = obj["choices"] as? [[String: Any]] {
            for choice in choices {
                if let reason = choice["finish_reason"] as? String {
                    finishReason = reason
                }

                if let delta = choice["delta"] as? [String: Any] {
                    if let r = delta["reasoning_content"] as? String, !r.isEmpty {
                        reasoning += r
                    }
                    if let c = delta["content"] as? String, !c.isEmpty {
                        content += c
                    }
                }

                if let message = choice["message"] as? [String: Any] {
                    if let c = message["content"] as? String, !c.isEmpty {
                        content += c
                    }
                }
            }
        }

        return StreamChunk(
            content: content,
            reasoningContent: reasoning,
            finishReason: finishReason
        )
    }

    // MARK: - Non-streaming fallback

    private func performNonStream(
        messages: [Message],
        apiKey: String,
        model: MiniMaxModel
    ) async throws -> String {
        let apiMessages: [[String: Any]] = messages.map { msg in
            var dict: [String: Any] = [
                "role": msg.role.rawValue,
                "content": msg.content
            ]
            if msg.role == .system { dict["name"] = "MiniMax AI" }
            else if msg.role == .user { dict["name"] = "User" }
            else if msg.role == .assistant { dict["name"] = "MiniMax AI" }
            return dict
        }

        let body: [String: Any] = [
            "model": model.rawValue,
            "messages": apiMessages,
            "stream": false
        ]

        guard let url = URL(string: baseURLString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        Logger.log("Sending non-streaming request", category: "MiniMax", redact: true, level: .debug)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpStatus(code, bodyStr)
        }

        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingError("Nie udało się sparsować odpowiedzi")
        }

        if let choices = obj["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        return ""
    }
}
