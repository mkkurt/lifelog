import Foundation

/// AI Backend Type
enum AIBackend: String, CaseIterable {
    case appleIntelligence = "Apple Intelligence"
    case gemini = "Gemini"
}

/// Service for AI-powered summarization and queries
@MainActor
class AIService: ObservableObject {
    static let shared = AIService()

    @Published var isProcessing: Bool = false
    @Published var preferredBackend: AIBackend = .appleIntelligence

    private let geminiClient: GeminiClient
    private var appleIntelligenceClient: (any AnyObject)?
    private let processingQueue = DispatchQueue(label: "com.lifelog.ai", qos: .userInitiated)

    private init() {
        self.geminiClient = GeminiClient()

        // Initialize Apple Intelligence if available
        if #available(macOS 26.0, *) {
            if AppleIntelligenceClient.isAvailable() {
                self.appleIntelligenceClient = AppleIntelligenceClient()
            }
        }

        // Load preferred backend from UserDefaults
        if let savedBackend = UserDefaults.standard.string(forKey: "ai_backend"),
           let backend = AIBackend(rawValue: savedBackend) {
            self.preferredBackend = backend
        } else {
            // Default to Apple Intelligence if available, otherwise Gemini
            self.preferredBackend = appleIntelligenceClient != nil ? .appleIntelligence : .gemini
        }
    }

    // MARK: - Configuration

    func setAPIKey(_ apiKey: String) {
        geminiClient.apiKey = apiKey
        UserDefaults.standard.set(apiKey, forKey: "gemini_api_key")
    }

    func hasAPIKey() -> Bool {
        return geminiClient.apiKey != nil
    }

    func setPreferredBackend(_ backend: AIBackend) {
        self.preferredBackend = backend
        UserDefaults.standard.set(backend.rawValue, forKey: "ai_backend")
    }

    func isAppleIntelligenceAvailable() -> Bool {
        return appleIntelligenceClient != nil
    }

    // MARK: - Query Processing

    /// Process a natural language query about the lifelog
    func processQuery(_ query: String) async -> QueryResponse {
        isProcessing = true
        defer { isProcessing = false }

        Logger.log("Processing query: \(query)", log: Logger.ai)

        do {
            // Step 1: Extract keywords and time context from query
            let context = extractQueryContext(query)

            // Step 2: Search relevant entries
            let relevantEntries = await searchRelevantEntries(for: context)

            guard !relevantEntries.isEmpty else {
                return QueryResponse(
                    query: query,
                    response: "I couldn't find any relevant information in your lifelog for that query.",
                    relevantEntries: [],
                    confidence: 0.0
                )
            }

            // Step 3: Build context for AI
            let contextText = buildContextText(from: relevantEntries, limit: 10)

            // Step 4: Query AI backend
            let prompt = buildQueryPrompt(query: query, context: contextText)
            let response = try await generateWithBackend(prompt: prompt)

            // Save query to log
            await saveQuery(query, response: response, entries: relevantEntries)

            return QueryResponse(
                query: query,
                response: response,
                relevantEntries: relevantEntries,
                confidence: 0.9
            )

        } catch {
            Logger.error("Query processing failed: \(error.localizedDescription)", log: Logger.ai)
            return QueryResponse(
                query: query,
                response: "Sorry, I encountered an error processing your query: \(error.localizedDescription)",
                confidence: 0.0
            )
        }
    }

    /// Generate a summary for a time period
    func generateSummary(from start: Date, to end: Date) async -> String {
        Logger.log("Generating summary from \(start) to \(end)", log: Logger.ai)

        let entries = await StorageService.shared.getEntriesBetween(start: start, end: end)

        guard !entries.isEmpty else {
            return "No activity recorded during this period."
        }

        let contextText = buildContextText(from: entries, limit: 100)

        let prompt = """
        Summarize the following activity log from a user's computer screen. \
        Focus on what the user was working on, key topics, and patterns of activity. \
        Be concise but informative.

        Time period: \(start.formatted()) to \(end.formatted())

        Activity log:
        \(contextText)

        Summary:
        """

        do {
            let summary = try await generateWithBackend(prompt: prompt)
            return summary
        } catch {
            Logger.error("Summary generation failed: \(error.localizedDescription)", log: Logger.ai)
            return "Failed to generate summary: \(error.localizedDescription)"
        }
    }

    // MARK: - Backend Selection

    /// Generate text using the selected backend
    private func generateWithBackend(prompt: String) async throws -> String {
        switch preferredBackend {
        case .appleIntelligence:
            if #available(macOS 26.0, *), let client = appleIntelligenceClient as? AppleIntelligenceClient {
                Logger.log("Using Apple Intelligence", log: Logger.ai)
                return try await client.generateText(prompt: prompt)
            } else {
                // Fallback to Gemini if Apple Intelligence not available
                Logger.log("Apple Intelligence not available, falling back to Gemini", log: Logger.ai)
                return try await geminiClient.generateText(prompt: prompt)
            }
        case .gemini:
            Logger.log("Using Gemini", log: Logger.ai)
            return try await geminiClient.generateText(prompt: prompt)
        }
    }

    // MARK: - Private Methods

    private func extractQueryContext(_ query: String) -> QueryContext {
        var timeRange: (Date, Date)?

        // Simple time parsing
        let now = Date()
        let calendar = Calendar.current

        if query.localizedCaseInsensitiveContains("today") {
            let startOfDay = calendar.startOfDay(for: now)
            timeRange = (startOfDay, now)
        } else if query.localizedCaseInsensitiveContains("yesterday") {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
                let startOfYesterday = calendar.startOfDay(for: yesterday)
                let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday)!
                timeRange = (startOfYesterday, endOfYesterday)
            }
        } else if query.localizedCaseInsensitiveContains("this week") {
            if let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) {
                timeRange = (startOfWeek, now)
            }
        }

        // Extract keywords (remove common words)
        let keywords = extractKeywords(from: query)

        return QueryContext(keywords: keywords, timeRange: timeRange)
    }

    private func extractKeywords(from text: String) -> [String] {
        let stopWords = Set(["what", "when", "where", "who", "how", "was", "were", "is", "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "from", "about", "i", "you", "my", "me"])

        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }

        return Array(Set(words)) // Remove duplicates
    }

    private func searchRelevantEntries(for context: QueryContext) async -> [TextEntry] {
        var entries: [TextEntry] = []

        // Time-based search if time range specified
        if let (start, end) = context.timeRange {
            entries = await StorageService.shared.getEntriesBetween(start: start, end: end)
        }

        // Keyword search
        if !context.keywords.isEmpty {
            let searchQuery = context.keywords.joined(separator: " OR ")
            let keywordResults = await StorageService.shared.searchText(searchQuery, limit: 50)

            // Merge results
            let entryIds = Set(entries.map { $0.id })
            for result in keywordResults {
                if !entryIds.contains(result.id) {
                    entries.append(result)
                }
            }
        }

        // If no results and no time filter, get recent entries
        if entries.isEmpty && context.timeRange == nil {
            let oneDayAgo = Date().addingTimeInterval(-86400)
            entries = await StorageService.shared.getEntriesBetween(start: oneDayAgo, end: Date())
        }

        return entries
    }

    private func buildContextText(from entries: [TextEntry], limit: Int) -> String {
        let limitedEntries = entries.prefix(limit)

        return limitedEntries.map { entry in
            let time = entry.timestamp.formatted(date: .omitted, time: .shortened)
            let app = entry.appName ?? "Unknown"
            return "[\(time)] [\(app)] \(entry.rawText)"
        }.joined(separator: "\n")
    }

    private func buildQueryPrompt(query: String, context: String) -> String {
        return """
        You are an AI assistant helping a user recall information from their computer activity log. \
        The user can see their screen content over time through OCR text recognition.

        Answer the user's question based on the context provided. Be specific and reference \
        timestamps or applications when relevant. If the information isn't in the context, say so.

        User question: \(query)

        Context from activity log:
        \(context)

        Answer:
        """
    }

    private func saveQuery(_ query: String, response: String, entries: [TextEntry]) async {
        // Save to query log for future reference
        // This could be implemented in StorageService
        Logger.log("Query saved to log", log: Logger.ai, type: .debug)
    }
}

// MARK: - Supporting Types

private struct QueryContext {
    let keywords: [String]
    let timeRange: (Date, Date)?
}
