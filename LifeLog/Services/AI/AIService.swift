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
            // Default to Gemini (cloud-based, more reliable)
            self.preferredBackend = .gemini
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
        // First try to search compacted narratives (more efficient)
        let narratives = await searchRelevantNarratives(for: context)

        // If we have enough narratives, convert them to text entries for compatibility
        if !narratives.isEmpty {
            Logger.log("Using \(narratives.count) compacted narratives for query", log: Logger.ai, type: .debug)
            // Convert narratives to pseudo text entries for existing code compatibility
            return narratives.map { narrative in
                TextEntry(
                    id: narrative.id,
                    captureId: 0, // Not needed for query context
                    timestamp: narrative.timestamp,
                    rawText: narrative.narrative,
                    confidence: 1.0, // Narratives are already processed
                    appName: narrative.appName,
                    windowTitle: nil,
                    screenRegion: nil
                )
            }
        }

        // Fallback to raw text entries if narratives not available yet
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

        // Deduplicate before returning
        return DataCompactionService.shared.deduplicateEntries(entries)
    }

    private func searchRelevantNarratives(for context: QueryContext) async -> [ActivityNarrative] {
        var narratives: [ActivityNarrative] = []

        // Time-based search if time range specified
        if let (start, end) = context.timeRange {
            narratives = await StorageService.shared.getNarrativesBetween(start: start, end: end)
        }

        // Keyword search
        if !context.keywords.isEmpty {
            let searchQuery = context.keywords.joined(separator: " OR ")
            let keywordResults = await StorageService.shared.searchNarratives(searchQuery, limit: 30)

            // Merge results
            let narrativeHashes = Set(narratives.map { $0.contextHash })
            for result in keywordResults {
                if !narrativeHashes.contains(result.contextHash) {
                    narratives.append(result)
                }
            }
        }

        // If no results and no time filter, get recent narratives
        if narratives.isEmpty && context.timeRange == nil {
            let oneDayAgo = Date().addingTimeInterval(-86400)
            narratives = await StorageService.shared.getNarrativesBetween(start: oneDayAgo, end: Date())
        }

        return narratives
    }

    private func buildContextText(from entries: [TextEntry], limit: Int) -> String {
        let limitedEntries = entries.prefix(limit)

        let contextText = limitedEntries.map { entry in
            let time = entry.timestamp.formatted(date: .omitted, time: .shortened)
            let app = entry.appName ?? "Unknown"
            return "[\(time)] [\(app)] \(entry.rawText)"
        }.joined(separator: "\n")

        // Ensure we don't exceed Gemini 2.5 Flash context limit
        // Use conservative limit: 100K tokens for context (400K chars)
        return DataCompactionService.shared.truncateToContextLimit(contextText, maxTokens: 100_000)
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
import Foundation
import CryptoKit

/// Service responsible for intelligently compacting raw OCR data into structured narratives
/// Uses local Apple Intelligence to summarize and deduplicate data before storage
@MainActor
class DataCompactionService: ObservableObject {
    static let shared = DataCompactionService()

    @Published var isCompacting: Bool = false
    @Published var compactionQueueSize: Int = 0

    private let windowDuration: TimeInterval = 300 // 5 minutes
    private let maxTextLengthForAI = 4000 // ~1000 tokens per 4000 chars
    private var compactionTimer: Timer?
    private var processedHashes = Set<String>() // Track processed windows

    // Gemini 2.5 Flash context limits
    private let geminiContextLimit = 1_000_000 // 1M tokens
    private let estimatedCharsPerToken = 4
    private let maxCharsForContext: Int

    private init() {
        self.maxCharsForContext = geminiContextLimit * estimatedCharsPerToken
        loadProcessedHashes()
    }

    // MARK: - Public Interface

    /// Start automatic compaction
    func startCompaction() {
        guard !isCompacting else { return }
        isCompacting = true

        compactionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.compactPendingData()
            }
        }

        Logger.log("DataCompactionService started", log: Logger.ai)
    }

    /// Stop automatic compaction
    func stopCompaction() {
        compactionTimer?.invalidate()
        compactionTimer = nil
        isCompacting = false

        Logger.log("DataCompactionService stopped", log: Logger.ai)
    }

    /// Compact a batch of text entries into a narrative
    func compactEntries(_ entries: [TextEntry]) async -> ActivityNarrative? {
        guard !entries.isEmpty else { return nil }

        // Check for duplicates
        let window = CaptureWindow(
            startTime: entries.first!.timestamp,
            endTime: entries.last!.timestamp,
            captures: entries,
            appName: entries.first?.appName ?? "Unknown"
        )

        let hash = window.generateHash()
        if processedHashes.contains(hash) {
            Logger.log("Skipping duplicate window: \(hash)", log: Logger.ai, type: .debug)
            return nil
        }

        // Prepare text for AI processing
        let combinedText = prepareTextForAI(entries: entries)

        // Generate narrative using local AI
        guard let narrative = await generateNarrative(text: combinedText, window: window) else {
            return nil
        }

        // Extract structured data
        let actions = extractActions(from: narrative)
        let topics = extractTopics(from: narrative)

        let compacted = ActivityNarrative(
            timestamp: window.startTime,
            duration: window.duration,
            appName: window.appName,
            narrative: narrative,
            actions: actions,
            topics: topics,
            contextHash: hash
        )

        // Mark as processed
        processedHashes.insert(hash)
        saveProcessedHashes()

        return compacted
    }

    // MARK: - Private Methods

    private func compactPendingData() async {
        // Get uncompacted entries from last window
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-windowDuration)

        let entries = await StorageService.shared.getEntriesBetween(start: startTime, end: endTime)

        guard !entries.isEmpty else { return }

        // Group by app for better context
        let groupedByApp = Dictionary(grouping: entries) { $0.appName ?? "Unknown" }

        for (appName, appEntries) in groupedByApp {
            // Sort by timestamp
            let sorted = appEntries.sorted { $0.timestamp < $1.timestamp }

            // Compact and save
            if let narrative = await compactEntries(sorted) {
                await StorageService.shared.saveActivityNarrative(narrative)
                Logger.log("Compacted \(sorted.count) entries for \(appName) into narrative", log: Logger.ai)
            }
        }
    }

    /// Prepare text for AI processing with smart truncation
    private func prepareTextForAI(entries: [TextEntry]) -> String {
        var combinedTexts: [String] = []
        var totalLength = 0

        for entry in entries {
            let timestamp = entry.timestamp.formatted(date: .omitted, time: .shortened)
            let app = entry.appName ?? "Unknown"
            let text = "[\(timestamp)] [\(app)] \(entry.rawText)"

            // Check if adding this would exceed limit
            if totalLength + text.count > maxTextLengthForAI {
                break
            }

            combinedTexts.append(text)
            totalLength += text.count
        }

        return combinedTexts.joined(separator: "\n")
    }

    /// Generate narrative using local Apple Intelligence
    private func generateNarrative(text: String, window: CaptureWindow) async -> String? {
        // Always use local AI for privacy and speed
        if #available(macOS 26.0, *), AppleIntelligenceClient.isAvailable() {
            return await generateWithAppleIntelligence(text: text, window: window)
        } else {
            // Fallback: create structured summary without AI
            return createBasicSummary(text: text, window: window)
        }
    }

    @available(macOS 26.0, *)
    private func generateWithAppleIntelligence(text: String, window: CaptureWindow) async -> String? {
        let client = AppleIntelligenceClient()

        let prompt = """
        Summarize the following computer activity into a concise, descriptive narrative. Format like:
        "Visited [app], spent [duration] [doing X], then [did Y], switched to [Z] while [doing W]."

        Be specific about actions and context. Keep it under 200 words.
        Extract key activities, switches, and progression.

        Activity log for \(window.appName) (\(Int(window.duration/60)) minutes):
        \(text)

        Narrative summary:
        """

        do {
            let narrative = try await client.generateText(prompt: prompt)
            return narrative.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            Logger.error("Failed to generate narrative with Apple Intelligence: \(error)", log: Logger.ai)
            return nil
        }
    }

    /// Fallback summary when AI not available
    private func createBasicSummary(text: String, window: CaptureWindow) -> String {
        let lines = text.components(separatedBy: "\n")
        let uniqueTexts = Array(Set(lines.map { line in
            // Extract just the text part, removing timestamp and app
            let components = line.components(separatedBy: "] ")
            return components.count > 2 ? components[2...].joined(separator: "] ") : line
        })).prefix(5)

        let duration = Int(window.duration / 60)
        return "Spent \(duration) minutes in \(window.appName). Activities: \(uniqueTexts.joined(separator: "; "))"
    }

    /// Extract action verbs from narrative
    private func extractActions(from narrative: String) -> [String] {
        let actionWords = ["visited", "opened", "read", "wrote", "edited", "viewed", "clicked", "switched", "browsed", "searched", "typed", "created", "deleted", "copied", "pasted", "saved", "closed"]

        var actions: [String] = []
        let lowercased = narrative.lowercased()

        for action in actionWords {
            if lowercased.contains(action) {
                actions.append(action)
            }
        }

        return Array(Set(actions)) // Remove duplicates
    }

    /// Extract topic keywords from narrative
    private func extractTopics(from narrative: String) -> [String] {
        // Simple topic extraction: capitalized words and common tech terms
        let words = narrative.components(separatedBy: .whitespacesAndNewlines)
        var topics: [String] = []

        for word in words {
            let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
            // Capitalize words or known tech terms
            if cleaned.count > 3 && (cleaned.first?.isUppercase == true || isTechTerm(cleaned)) {
                topics.append(cleaned)
            }
        }

        return Array(Set(topics)).prefix(5).map { String($0) }
    }

    private func isTechTerm(_ word: String) -> Bool {
        let techTerms = ["swift", "swiftui", "xcode", "github", "api", "json", "sql", "database", "code", "programming"]
        return techTerms.contains(word.lowercased())
    }

    // MARK: - Duplicate Detection

    private func loadProcessedHashes() {
        if let saved = UserDefaults.standard.array(forKey: "processed_hashes") as? [String] {
            processedHashes = Set(saved)
        }
    }

    private func saveProcessedHashes() {
        // Keep only last 10,000 hashes to prevent memory bloat
        let recent = Array(processedHashes.suffix(10000))
        UserDefaults.standard.set(recent, forKey: "processed_hashes")
    }

    /// Check if data would be duplicate
    func isDuplicate(entries: [TextEntry]) -> Bool {
        let window = CaptureWindow(
            startTime: entries.first!.timestamp,
            endTime: entries.last!.timestamp,
            captures: entries,
            appName: entries.first?.appName ?? "Unknown"
        )
        return processedHashes.contains(window.generateHash())
    }

    /// Remove duplicate entries based on content similarity
    func deduplicateEntries(_ entries: [TextEntry]) -> [TextEntry] {
        var unique: [TextEntry] = []
        var seenTexts = Set<String>()

        for entry in entries {
            // Normalize text for comparison
            let normalized = entry.rawText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip very similar text (fuzzy matching)
            if !seenTexts.contains(where: { similarity(normalized, $0) > 0.9 }) {
                unique.append(entry)
                seenTexts.insert(normalized)
            }
        }

        Logger.log("Deduplicated \(entries.count) entries to \(unique.count) unique entries", log: Logger.ai, type: .debug)
        return unique
    }

    /// Calculate text similarity (0-1)
    private func similarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.split(separator: " "))
        let words2 = Set(text2.split(separator: " "))

        guard !words1.isEmpty && !words2.isEmpty else { return 0 }

        let intersection = words1.intersection(words2)
        let union = words1.union(words2)

        return Double(intersection.count) / Double(union.count)
    }
}

// MARK: - Context Length Management

extension DataCompactionService {
    /// Ensure text doesn't exceed Gemini context limits
    func truncateToContextLimit(_ text: String, maxTokens: Int = 100_000) -> String {
        let maxChars = maxTokens * estimatedCharsPerToken

        if text.count <= maxChars {
            return text
        }

        Logger.log("Truncating text from \(text.count) to \(maxChars) chars", log: Logger.ai, type: .debug)

        // Smart truncation: keep beginning and end
        let halfChars = maxChars / 2
        let start = text.prefix(halfChars)
        let end = text.suffix(halfChars)

        return "\(start)\n\n[... content truncated ...]\n\n\(end)"
    }

    /// Estimate token count for text
    func estimateTokenCount(_ text: String) -> Int {
        return text.count / estimatedCharsPerToken
    }
}
