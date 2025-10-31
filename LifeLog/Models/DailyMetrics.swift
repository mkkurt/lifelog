import Foundation

/// Daily aggregated metrics
struct DailyMetrics: Identifiable, Codable {
    let id: Int64
    let date: Date
    let focusRatio: Double // deep_block_time / total_active_time
    let switchesPerHour: Double
    let topicEntropy: Double // Shannon entropy of topic distribution
    let outputDensity: Double // artifacts per hour
    let explorationProductionRatio: Double // consumption / production
    let stuckScore: Double // weighted average of stuck indicators
    let deepBlocksCount: Int
    let totalActiveTime: TimeInterval

    init(
        id: Int64 = 0,
        date: Date,
        focusRatio: Double = 0,
        switchesPerHour: Double = 0,
        topicEntropy: Double = 0,
        outputDensity: Double = 0,
        explorationProductionRatio: Double = 0,
        stuckScore: Double = 0,
        deepBlocksCount: Int = 0,
        totalActiveTime: TimeInterval = 0
    ) {
        self.id = id
        self.date = date
        self.focusRatio = focusRatio
        self.switchesPerHour = switchesPerHour
        self.topicEntropy = topicEntropy
        self.outputDensity = outputDensity
        self.explorationProductionRatio = explorationProductionRatio
        self.stuckScore = stuckScore
        self.deepBlocksCount = deepBlocksCount
        self.totalActiveTime = totalActiveTime
    }

    /// Quality score (0-100) based on key metrics
    var qualityScore: Double {
        let focusWeight = 0.3
        let switchWeight = 0.2
        let outputWeight = 0.25
        let stuckWeight = 0.25

        // Normalize and invert where needed
        let focusScore = min(focusRatio, 1.0) * 100
        let switchScore = max(0, 100 - (switchesPerHour * 2)) // lower is better
        let outputScore = min(outputDensity * 20, 100) // assume 5/hr = 100
        let stuckPenalty = max(0, 100 - (stuckScore * 100))

        return (focusScore * focusWeight) +
               (switchScore * switchWeight) +
               (outputScore * outputWeight) +
               (stuckPenalty * stuckWeight)
    }

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
