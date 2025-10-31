import Foundation
import FoundationModels

/// Client for Apple Intelligence Foundation Models (local LLM)
@available(macOS 26.0, *)
class AppleIntelligenceClient {
    private var session: LanguageModelSession?

    init() {
        setupSession()
    }

    private func setupSession() {
        // Initialize session with instructions for LifeLog context
        session = LanguageModelSession(
            instructions: """
            You are an AI assistant helping a user recall information from their computer activity log. \
            The user can see their screen content over time through OCR text recognition. \
            Be specific and reference timestamps or applications when relevant. \
            If the information isn't in the context provided, say so clearly.
            """
        )
    }

    /// Generate text using Apple Intelligence local model
    func generateText(prompt: String) async throws -> String {
        guard let session = session else {
            throw AppleIntelligenceError.sessionNotInitialized
        }

        let response = try await session.respond(to: prompt)
        return response.content
    }

    /// Generate text with streaming for better UX
    func generateTextStream(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let session = self.session else {
                    continuation.finish(throwing: AppleIntelligenceError.sessionNotInitialized)
                    return
                }

                do {
                    let stream = session.streamResponse(to: prompt)

                    for try await partialResponse in stream {
                        // StreamResponse returns snapshots with a content property
                        continuation.yield(partialResponse.content)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Check if Apple Intelligence is available on this device
    @available(macOS 26.0, *)
    static func isAvailable() -> Bool {
        // Additional check could be added for Apple Silicon
        return true
    }
}

// MARK: - Errors

enum AppleIntelligenceError: LocalizedError {
    case sessionNotInitialized
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .sessionNotInitialized:
            return "Apple Intelligence session not initialized"
        case .notAvailable:
            return "Apple Intelligence is not available on this device. Requires macOS 26+ on Apple Silicon."
        }
    }
}
