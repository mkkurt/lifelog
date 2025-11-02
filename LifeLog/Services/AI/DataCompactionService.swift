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
