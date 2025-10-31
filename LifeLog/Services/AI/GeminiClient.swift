import Foundation

/// Client for Google Gemini API
class GeminiClient {
    var apiKey: String?

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-2.5-flash"

    init() {
        // Load API key from UserDefaults if available
        self.apiKey = UserDefaults.standard.string(forKey: "gemini_api_key")
    }

    /// Generate text using Gemini
    func generateText(prompt: String, temperature: Float = 0.7) async throws -> String {
        guard let apiKey = apiKey else {
            throw GeminiError.noAPIKey
        }

        let endpoint = "\(baseURL)/models/\(model):generateContent?key=\(apiKey)"

        guard let url = URL(string: endpoint) else {
            throw GeminiError.invalidURL
        }

        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": 2048
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let candidates = json?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.parseError
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Generate text with streaming (future enhancement)
    func generateTextStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        // TODO: Implement streaming for better UX
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await generateText(prompt: prompt)
                    continuation.yield(result)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No Gemini API key configured. Please add your API key in settings."
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from Gemini API"
        case .apiError(let code, let message):
            return "Gemini API error (\(code)): \(message)"
        case .parseError:
            return "Failed to parse Gemini response"
        }
    }
}
