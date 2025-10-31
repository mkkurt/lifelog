import Foundation

/// Coordinator service for the entire Meaning Engine pipeline
/// Manages InteractionTracker, FeatureExtractor, and HypothesisGenerator
@MainActor
class MeaningEngine: ObservableObject {
    static let shared = MeaningEngine()

    @Published var isRunning = false
    @Published var currentHypotheses: [Hypothesis] = []
    @Published var todayMetrics: DailyMetrics?

    private let interactionTracker = InteractionTracker.shared
    private let featureExtractor = FeatureExtractor.shared
    private let hypothesisGenerator = HypothesisGenerator.shared

    private var metricsUpdateTimer: Task<Void, Never>?

    private init() {}

    // MARK: - Lifecycle

    /// Start the entire Meaning Engine pipeline
    func start() async {
        guard !isRunning else { return }

        Logger.log("Starting Meaning Engine...", log: Logger.storage)

        // Start all components
        interactionTracker.startTracking()
        await featureExtractor.startExtraction()
        await hypothesisGenerator.startGeneration()

        isRunning = true

        // Start metrics update timer
        startMetricsUpdates()

        Logger.log("Meaning Engine started successfully", log: Logger.storage)
    }

    /// Stop the entire Meaning Engine pipeline
    func stop() async {
        guard isRunning else { return }

        Logger.log("Stopping Meaning Engine...", log: Logger.storage)

        // Stop all components
        interactionTracker.stopTracking()
        await featureExtractor.stopExtraction()
        await hypothesisGenerator.stopGeneration()

        isRunning = false

        // Stop metrics timer
        metricsUpdateTimer?.cancel()
        metricsUpdateTimer = nil

        Logger.log("Meaning Engine stopped", log: Logger.storage)
    }

    // MARK: - Metrics Updates

    private func startMetricsUpdates() {
        metricsUpdateTimer = Task { @MainActor in
            while !Task.isCancelled {
                await updateMetrics()

                // Update every 5 minutes
                try? await Task.sleep(nanoseconds: 300_000_000_000)
            }
        }
    }

    private func updateMetrics() async {
        // Update today's metrics
        todayMetrics = await StorageService.shared.getDailyMetrics(for: Date())

        // If no metrics exist, create initial entry
        if todayMetrics == nil {
            let initialMetrics = DailyMetrics(
                date: Date(),
                focusRatio: 0,
                switchesPerHour: 0,
                topicEntropy: 0,
                outputDensity: 0,
                explorationProductionRatio: 0,
                stuckScore: 0,
                deepBlocksCount: 0,
                totalActiveTime: 0
            )
            _ = await StorageService.shared.saveDailyMetrics(initialMetrics)
            todayMetrics = initialMetrics
        }

        Logger.log("Updated daily metrics (quality score: \(todayMetrics?.qualityScore ?? 0))", log: Logger.storage, type: .debug)
    }

    // MARK: - Query Methods

    /// Get active hypotheses (currently ongoing patterns)
    func getActiveHypotheses() async -> [Hypothesis] {
        // Query database for hypotheses without end_time
        // For now, placeholder
        // TODO: Implement StorageService.getActiveHypotheses()
        return []
    }

    /// Get hypotheses for a specific time range
    func getHypotheses(from startTime: Date, to endTime: Date) async -> [Hypothesis] {
        // Query database for hypotheses in time range
        // TODO: Implement StorageService.getHypotheses(from:to:)
        return []
    }

    /// Get features for a specific time range
    func getFeatures(from startTime: Date, to endTime: Date) async -> [Feature] {
        return await StorageService.shared.getFeatures(from: startTime, to: endTime)
    }

    /// Get interaction events for a specific time range
    func getInteractionEvents(from startTime: Date, to endTime: Date) async -> [InteractionEvent] {
        return await StorageService.shared.getInteractionEvents(from: startTime, to: endTime)
    }

    /// Get today's daily metrics
    func getTodayMetrics() async -> DailyMetrics? {
        return await StorageService.shared.getDailyMetrics(for: Date())
    }

    /// Get metrics for a specific date
    func getMetrics(for date: Date) async -> DailyMetrics? {
        return await StorageService.shared.getDailyMetrics(for: date)
    }

    // MARK: - Analytics

    /// Calculate daily metrics from features
    func calculateDailyMetrics(for date: Date = Date()) async -> DailyMetrics? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let features = await StorageService.shared.getFeatures(from: startOfDay, to: endOfDay)

        guard !features.isEmpty else {
            Logger.log("No features found for \(date)", log: Logger.storage, type: .debug)
            return nil
        }

        // Calculate focus ratio (deep work time / total active time)
        let deepWorkFeatures = features.filter { $0.flowIndicator > 0.6 }
        let totalActiveTime = Double(features.count) * 300 // 5 min per window
        let deepWorkTime = Double(deepWorkFeatures.count) * 300
        let focusRatio = totalActiveTime > 0 ? deepWorkTime / totalActiveTime : 0

        // Calculate switches per hour
        let totalSwitches = features.map { $0.taskSwitchRate }.reduce(0, +)
        let hours = totalActiveTime / 3600
        let switchesPerHour = hours > 0 ? totalSwitches / hours : 0

        // Calculate topic entropy (Shannon entropy)
        let topicEntropy = calculateTopicEntropy(features: features)

        // Calculate output density
        let totalOutput = features.map { $0.outputDensity }.reduce(0, +)
        let outputDensity = hours > 0 ? totalOutput / hours : 0

        // Calculate exploration/production ratio
        let totalPassive = features.map { $0.passiveConsumption }.reduce(0, +)
        let totalActive = features.map { $0.activeConsumption }.reduce(0, +)
        let explorationProductionRatio = totalActive > 0 ? totalPassive / totalActive : 0

        // Calculate stuck score
        let stuckFeatures = features.filter { $0.repetitionScore > 0.7 && $0.outputDensity < 0.3 }
        let stuckScore = Double(stuckFeatures.count) / Double(features.count)

        // Count deep blocks
        let deepBlocksCount = deepWorkFeatures.count

        let metrics = DailyMetrics(
            date: date,
            focusRatio: focusRatio,
            switchesPerHour: switchesPerHour,
            topicEntropy: topicEntropy,
            outputDensity: outputDensity,
            explorationProductionRatio: explorationProductionRatio,
            stuckScore: stuckScore,
            deepBlocksCount: deepBlocksCount,
            totalActiveTime: totalActiveTime
        )

        // Save to database
        _ = await StorageService.shared.saveDailyMetrics(metrics)

        return metrics
    }

    private func calculateTopicEntropy(features: [Feature]) -> Double {
        // Shannon entropy of topic distribution
        let topics = features.compactMap { $0.topicLabel }
        guard !topics.isEmpty else { return 0 }

        // Count topic occurrences
        var topicCounts: [String: Int] = [:]
        for topic in topics {
            topicCounts[topic, default: 0] += 1
        }

        // Calculate probabilities and entropy
        let totalCount = Double(topics.count)
        var entropy = 0.0

        for (_, count) in topicCounts {
            let probability = Double(count) / totalCount
            entropy -= probability * log2(probability)
        }

        return entropy
    }

    // MARK: - Insights

    /// Generate a daily brief summary
    func generateDailyBrief(for date: Date = Date()) async -> DailyBrief {
        let metrics = await getMetrics(for: date) ?? DailyMetrics(
            date: date,
            focusRatio: 0,
            switchesPerHour: 0,
            topicEntropy: 0,
            outputDensity: 0,
            explorationProductionRatio: 0,
            stuckScore: 0,
            deepBlocksCount: 0,
            totalActiveTime: 0
        )

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let hypotheses = await getHypotheses(from: startOfDay, to: endOfDay)

        return DailyBrief(
            date: date,
            metrics: metrics,
            hypotheses: hypotheses,
            insights: generateInsights(metrics: metrics, hypotheses: hypotheses)
        )
    }

    private func generateInsights(metrics: DailyMetrics, hypotheses: [Hypothesis]) -> [String] {
        var insights: [String] = []

        // Quality score insight
        if metrics.qualityScore >= 70 {
            insights.append("🎯 Excellent day! Quality score: \(Int(metrics.qualityScore))")
        } else if metrics.qualityScore >= 50 {
            insights.append("👍 Good progress. Quality score: \(Int(metrics.qualityScore))")
        } else {
            insights.append("⚠️ Room for improvement. Quality score: \(Int(metrics.qualityScore))")
        }

        // Focus insights
        if metrics.focusRatio > 0.5 {
            insights.append("✨ Strong focus with \(String(format: "%.0f%%", metrics.focusRatio * 100)) deep work time")
        }

        // Stuck insights
        if metrics.stuckScore > 0.3 {
            insights.append("🔄 Detected stuck patterns - consider taking a break or changing approach")
        }

        // Switch insights
        if metrics.switchesPerHour > 15 {
            insights.append("⚡ High context switching (\(String(format: "%.1f", metrics.switchesPerHour))/hr) - try focusing on fewer tasks")
        }

        // Deep blocks
        if metrics.deepBlocksCount > 0 {
            insights.append("🎨 Achieved \(metrics.deepBlocksCount) deep work block(s)")
        }

        // Hypothesis insights
        let actionableHypotheses = hypotheses.filter { $0.type.actionable }
        if !actionableHypotheses.isEmpty {
            insights.append("💡 \(actionableHypotheses.count) actionable pattern(s) detected")
        }

        return insights
    }

    // MARK: - Status

    /// Get current engine status
    func getStatus() -> MeaningEngineStatus {
        return MeaningEngineStatus(
            isRunning: isRunning,
            interactionTrackerActive: interactionTracker.isTracking,
            featureExtractorActive: true, // Actor, can't check directly
            hypothesisGeneratorActive: true, // Actor, can't check directly
            todayQualityScore: todayMetrics?.qualityScore ?? 0
        )
    }
}

// MARK: - Supporting Types

struct DailyBrief {
    let date: Date
    let metrics: DailyMetrics
    let hypotheses: [Hypothesis]
    let insights: [String]

    var summary: String {
        """
        Daily Brief for \(dateString)
        Quality Score: \(Int(metrics.qualityScore))/100

        Metrics:
        - Focus Ratio: \(String(format: "%.0f%%", metrics.focusRatio * 100))
        - Switches/Hour: \(String(format: "%.1f", metrics.switchesPerHour))
        - Deep Blocks: \(metrics.deepBlocksCount)
        - Active Time: \(String(format: "%.1f", metrics.totalActiveTime / 3600))h

        Insights:
        \(insights.map { "• \($0)" }.joined(separator: "\n"))

        Patterns Detected: \(hypotheses.count)
        """
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct MeaningEngineStatus {
    let isRunning: Bool
    let interactionTrackerActive: Bool
    let featureExtractorActive: Bool
    let hypothesisGeneratorActive: Bool
    let todayQualityScore: Double

    var allComponentsActive: Bool {
        isRunning && interactionTrackerActive && featureExtractorActive && hypothesisGeneratorActive
    }

    var healthStatus: String {
        if allComponentsActive {
            return "✅ All systems operational"
        } else if isRunning {
            return "⚠️ Some components inactive"
        } else {
            return "🔴 Engine stopped"
        }
    }
}
