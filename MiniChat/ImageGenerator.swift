//
//  ImageGenerator.swift
//  MiniChat
//
//  Klient dla MiniMax image-01 API.
//

import Foundation

struct ImageGenerationResult {
    let imageURL: String?
    let base64Data: String?
    let mimeType: String
    let prompt: String
}

enum ImageGeneratorError: LocalizedError {
    case noAPIKey
    case invalidURL
    case httpError(Int, String?)
    case apiError(Int, String)
    case noData
    case decodeError

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Brak API key"
        case .invalidURL: return "Nieprawidłowy URL"
        case .httpError(let code, let body):
            if let body, !body.isEmpty { return "HTTP \(code): \(body.prefix(200))" }
            return "HTTP \(code)"
        case .apiError(let code, let msg): return "API error \(code): \(msg)"
        case .noData: return "Brak danych"
        case .decodeError: return "Błąd parsowania odpowiedzi"
        }
    }
}

final class ImageGenerator {
    static let shared = ImageGenerator()

    private let baseURL = URL(string: "https://api.minimax.io/v1/image_generation")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    /// Generuje obraz na podstawie promptu. Zwraca URL (expires 24h) i/lub base64.
    func generate(
        prompt: String,
        apiKey: String,
        aspectRatio: String = "1:1",
        useBase64: Bool = true
    ) async throws -> ImageGenerationResult {
        guard !apiKey.isEmpty else { throw ImageGeneratorError.noAPIKey }

        let body: [String: Any] = [
            "model": "image-01",
            "prompt": prompt,
            "aspect_ratio": aspectRatio,
            "response_format": useBase64 ? "base64" : "url",
            "n": 1,
            "prompt_optimizer": true
        ]

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🎨 [ImageGen] Generating: \(prompt.prefix(80))...")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ImageGeneratorError.invalidURL
        }

        guard (200...299).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            print("❌ [ImageGen] HTTP \(http.statusCode): \(bodyStr.prefix(200))")
            throw ImageGeneratorError.httpError(http.statusCode, bodyStr)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImageGeneratorError.decodeError
        }

        // Sprawdź błędy API
        if let baseResp = json["base_resp"] as? [String: Any],
           let statusCode = baseResp["status_code"] as? Int,
           statusCode != 0 {
            let msg = baseResp["status_msg"] as? String ?? "Unknown"
            print("❌ [ImageGen] API error \(statusCode): \(msg)")
            throw ImageGeneratorError.apiError(statusCode, msg)
        }

        // Wyciągnij obraz
        guard let dataObj = json["data"] as? [String: Any] else {
            print("❌ [ImageGen] No data in response")
            throw ImageGeneratorError.noData
        }

        var resultURL: String?
        var resultBase64: String?

        if let urls = dataObj["image_urls"] as? [String], let first = urls.first {
            resultURL = first
        }
        if let b64 = dataObj["image_base64"] as? [String], let first = b64.first {
            resultBase64 = first
        }

        guard resultURL != nil || resultBase64 != nil else {
            print("❌ [ImageGen] No image in response")
            throw ImageGeneratorError.noData
        }

        // Sprawdź success_count
        if let meta = json["metadata"] as? [String: Any],
           let failed = meta["failed_count"] as? Int,
           failed > 0,
           let success = meta["success_count"] as? Int,
           success == 0 {
            print("❌ [ImageGen] All images blocked by content safety")
            throw ImageGeneratorError.apiError(1026, "Treść zablokowana przez filtr bezpieczeństwa")
        }

        print("✅ [ImageGen] Success: url=\(resultURL != nil), base64=\(resultBase64 != nil)")

        return ImageGenerationResult(
            imageURL: resultURL,
            base64Data: resultBase64,
            mimeType: "image/jpeg",
            prompt: prompt
        )
    }
}
