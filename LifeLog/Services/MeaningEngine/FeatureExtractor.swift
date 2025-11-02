import Foundation

/// Extracts behavioral features from interaction events and screen captures
/// Aggregates raw signals into 1-5 minute windows with calculated metrics
actor FeatureExtractor {
    static let shared = FeatureExtractor()

    private let windowDuration: TimeInterval = 300 // 5 minutes
    private var isRunning = false
    private var extractionTimer: Task<Void, Never>?

    private init() {}

    // MARK: - Public Interface

    func startExtraction() {
        guard !isRunning else { return }
        isRunning = true

        extractionTimer = Task {
            while !Task.isCancelled {
                await extractFeatures()

                // Wait for next extraction cycle (every minute)
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
            }
        }

        Logger.log("FeatureExtractor started", log: Logger.storage)
    }

    func stopExtraction() {
        isRunning = false
        extractionTimer?.cancel()
        extractionTimer = nil

        Logger.log("FeatureExtractor stopped", log: Logger.storage)
    }

    // MARK: - Feature Extraction

    private func extractFeatures() async {
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-windowDuration)

        // Get recent interaction events
        let events = await getInteractionEvents(from: startTime, to: endTime)

        // Get recent text entries for topic analysis
        let textEntries = await StorageService.shared.getEntriesBetween(start: startTime, end: endTime)

        // Get active session
        let session = await StorageService.shared.getActiveSession()

        // Calculate features
        let feature = await calculateFeatures(
            events: events,
            textEntries: textEntries,
            sessionId: session?.id,
            windowStart: startTime,
            windowEnd: endTime
        )

        // Save to database
        let featureId = await StorageService.shared.saveFeature(feature)

        Logger.log("Extracted feature \(featureId) for window \(startTime) - \(endTime)", log: Logger.storage, type: .debug)
    }

    private func getInteractionEvents(from startTime: Date, to endTime: Date) async -> [InteractionEvent] {
        return await StorageService.shared.getInteractionEvents(from: startTime, to: endTime)
    }

    // MARK: - Feature Calculation

    private func calculateFeatures(
        events: [InteractionEvent],
        textEntries: [TextEntry],
        sessionId: Int64?,
        windowStart: Date,
        windowEnd: Date
    ) async -> Feature {
        // Time features
        let blockLength = calculateBlockLength(events: events)
        let interruptionRate = calculateInterruptionRate(events: events)
        let circadianBand = CircadianBand.from(hour: Calendar.current.component(.hour, from: windowStart))

        // Context features
        let topicLabel = extractTopicLabel(textEntries: textEntries)
        let topicContinuity = await calculateTopicContinuity(
            currentTopic: topicLabel,
            windowStart: windowStart
        )
        let topicChurn = calculateTopicChurn(events: events)
        let repetitionScore = calculateRepetitionScore(textEntries: textEntries)

        // Behavior features
        let taskSwitchRate = calculateTaskSwitchRate(events: events)
        let microDistractionCount = calculateMicroDistractions(events: events)
        let flowIndicator = calculateFlowIndicator(
            blockLength: blockLength,
            interruptionRate: interruptionRate,
            taskSwitchRate: taskSwitchRate
        )
        let grindIndicator = calculateGrindIndicator(
            repetitionScore: repetitionScore,
            taskSwitchRate: taskSwitchRate
        )

        // Output features
        let outputDensity = await calculateOutputDensity(windowStart: windowStart, windowEnd: windowEnd)

        // Media features
        let (passiveConsumption, activeConsumption) = calculateMediaConsumption(events: events)

        return Feature(
            windowStart: windowStart,
            windowEnd: windowEnd,
            sessionId: sessionId,
            blockLength: blockLength,
            interruptionRate: interruptionRate,
            circadianBand: circadianBand,
            topicLabel: topicLabel,
            topicContinuity: topicContinuity,
            topicChurn: topicChurn,
            repetitionScore: repetitionScore,
            taskSwitchRate: taskSwitchRate,
            microDistractionCount: microDistractionCount,
            flowIndicator: flowIndicator,
            grindIndicator: grindIndicator,
            outputDensity: outputDensity,
            passiveConsumption: passiveConsumption,
            activeConsumption: activeConsumption
        )
    }

    // MARK: - Time Features

    private func calculateBlockLength(events: [InteractionEvent]) -> TimeInterval {
        guard !events.isEmpty else { return 0 }

        // Calculate average time between app switches
        let appSwitches = events.filter { $0.type == .appSwitch }
        guard appSwitches.count > 1 else { return windowDuration }

        var totalBlockLength: TimeInterval = 0
        for i in 0..<(appSwitches.count - 1) {
            let blockDuration = appSwitches[i + 1].timestamp.timeIntervalSince(appSwitches[i].timestamp)
            totalBlockLength += blockDuration
        }

        return totalBlockLength / Double(appSwitches.count - 1)
    }

    private func calculateInterruptionRate(events: [InteractionEvent]) -> Double {
        // Interruptions = context switches per hour
        let switches = events.filter { $0.type == .appSwitch || $0.type == .windowSwitch }
        let hours = windowDuration / 3600
        return Double(switches.count) / hours
    }

    // MARK: - Context Features

    private func extractTopicLabel(textEntries: [TextEntry]) -> String? {
        guard !textEntries.isEmpty else { return nil }

        // Simple topic extraction: most common app or first significant text
        let appCounts = textEntries.reduce(into: [String: Int]()) { counts, entry in
            if let app = entry.appName {
                counts[app, default: 0] += 1
            }
        }

        let mostCommonApp = appCounts.max(by: { $0.value < $1.value })?.key
        return mostCommonApp
    }

    private func calculateTopicContinuity(currentTopic: String?, windowStart: Date) async -> Double {
        guard let currentTopic = currentTopic else { return 0 }

        // Look at previous window
        let previousWindowEnd = windowStart
        let previousWindowStart = previousWindowEnd.addingTimeInterval(-windowDuration)

        let previousEntries = await StorageService.shared.getEntriesBetween(
            start: previousWindowStart,
            end: previousWindowEnd
        )

        let previousTopic = extractTopicLabel(textEntries: previousEntries)

        // Simple comparison: 1.0 if same topic, 0.0 if different
        return (previousTopic == currentTopic) ? 1.0 : 0.0
    }

    private func calculateTopicChurn(events: [InteractionEvent]) -> Double {
        // Topic switches per hour (approximated by app switches)
        let switches = events.filter { $0.type == .appSwitch }
        let hours = windowDuration / 3600
        return Double(switches.count) / hours
    }

    private func calculateRepetitionScore(textEntries: [TextEntry]) -> Double {
        guard textEntries.count > 1 else { return 0 }

        // Calculate similarity between consecutive text entries
        var totalSimilarity = 0.0
        var comparisons = 0

        for i in 0..<(textEntries.count - 1) {
            let similarity = textSimilarity(
                textEntries[i].rawText,
                textEntries[i + 1].rawText
            )
            totalSimilarity += similarity
            comparisons += 1
        }

        return comparisons > 0 ? totalSimilarity / Double(comparisons) : 0
    }

    private func textSimilarity(_ text1: String, _ text2: String) -> Double {
        // Simple word-based similarity
        let words1 = Set(text1.lowercased().split(separator: " "))
        let words2 = Set(text2.lowercased().split(separator: " "))

        guard !words1.isEmpty && !words2.isEmpty else { return 0 }

        let intersection = words1.intersection(words2)
        let union = words1.union(words2)

        return Double(intersection.count) / Double(union.count)
    }

    // MARK: - Behavior Features

    private func calculateTaskSwitchRate(events: [InteractionEvent]) -> Double {
        // Total context switches (app + window) per hour
        let switches = events.filter {
            $0.type == .appSwitch || $0.type == .windowSwitch
        }
        let hours = windowDuration / 3600
        return Double(switches.count) / hours
    }

    private func calculateMicroDistractions(events: [InteractionEvent]) -> Int {
        // Count rapid app switches (< 30 seconds apart)
        let appSwitches = events.filter { $0.type == .appSwitch }.sorted { $0.timestamp < $1.timestamp }

        guard appSwitches.count > 1 else { return 0 }

        var distractions = 0
        for i in 0..<(appSwitches.count - 1) {
            let timeBetween = appSwitches[i + 1].timestamp.timeIntervalSince(appSwitches[i].timestamp)
            if timeBetween < 30 {
                distractions += 1
            }
        }

        return distractions
    }

    private func calculateFlowIndicator(
        blockLength: TimeInterval,
        interruptionRate: Double,
        taskSwitchRate: Double
    ) -> Double {
        // Flow = long blocks + low interruptions + low switches
        // Normalize to 0-1 scale

        let blockScore = min(blockLength / 300, 1.0) // 5 min = perfect
        let interruptionScore = max(0, 1.0 - (interruptionRate / 12)) // 0 interruptions = perfect
        let switchScore = max(0, 1.0 - (taskSwitchRate / 12)) // 0 switches = perfect

        return (blockScore * 0.4) + (interruptionScore * 0.3) + (switchScore * 0.3)
    }

    private func calculateGrindIndicator(
        repetitionScore: Double,
        taskSwitchRate: Double
    ) -> Double {
        // Grind = high repetition + low switches (stuck on same thing)
        // Normalize to 0-1 scale

        let repetitionWeight = 0.6
        let lowSwitchScore = max(0, 1.0 - (taskSwitchRate / 6)) // Low switches indicate grinding

        return (repetitionScore * repetitionWeight) + (lowSwitchScore * (1 - repetitionWeight))
    }

    // MARK: - Output Features

    private func calculateOutputDensity(windowStart: Date, windowEnd: Date) async -> Double {
        // This would query artifacts table for recent outputs
        // For now, return 0 as placeholder
        // TODO: Implement artifact counting
        let hours = windowDuration / 3600
        return 0.0 / hours
    }

    // MARK: - Media Features

    private func calculateMediaConsumption(events: [InteractionEvent]) -> (passive: TimeInterval, active: TimeInterval) {
        // Classify apps as passive (browsers, video players) or active (editors, terminals)
        let passiveApps = ["Safari", "Chrome", "Firefox", "YouTube", "Netflix", "Spotify"]
        let activeApps = ["Xcode", "Terminal", "iTerm", "Code", "TextEdit", "Notes"]

        var passiveTime: TimeInterval = 0
        var activeTime: TimeInterval = 0

        let appSwitches = events.filter { $0.type == .appSwitch }.sorted { $0.timestamp < $1.timestamp }

        for i in 0..<appSwitches.count {
            guard let appName = appSwitches[i].appName else { continue }

            let duration: TimeInterval
            if i < appSwitches.count - 1 {
                duration = appSwitches[i + 1].timestamp.timeIntervalSince(appSwitches[i].timestamp)
            } else {
                duration = Date().timeIntervalSince(appSwitches[i].timestamp)
            }

            // Classify app time
            if passiveApps.contains(where: { appName.contains($0) }) {
                passiveTime += duration
            } else if activeApps.contains(where: { appName.contains($0) }) {
                activeTime += duration
            }
        }

        return (passiveTime, activeTime)
    }

    // MARK: - Manual Extraction

    /// Extract features for a specific time range (useful for backfilling)
    func extractFeaturesFor(start: Date, end: Date) async -> Feature? {
        let events = await getInteractionEvents(from: start, to: end)
        let textEntries = await StorageService.shared.getEntriesBetween(start: start, end: end)
        let session = await StorageService.shared.getActiveSession()

        let feature = await calculateFeatures(
            events: events,
            textEntries: textEntries,
            sessionId: session?.id,
            windowStart: start,
            windowEnd: end
        )

        let featureId = await StorageService.shared.saveFeature(feature)
        return featureId > 0 ? feature : nil
    }
}
