import Foundation

/// Aggregated features for a time window (1-5 minutes)
struct Feature: Identifiable, Codable {
    let id: Int64
    let windowStart: Date
    let windowEnd: Date
    let sessionId: Int64?

    // Time features
    let blockLength: TimeInterval
    let interruptionRate: Double
    let circadianBand: CircadianBand

    // Context features
    let topicLabel: String?
    let topicContinuity: Double // 0-1
    let topicChurn: Double // switches per hour
    let repetitionScore: Double // 0-1

    // Behavior features
    let taskSwitchRate: Double // switches per hour
    let microDistractionCount: Int
    let flowIndicator: Double // 0-1
    let grindIndicator: Double // 0-1

    // Output features
    let outputDensity: Double // artifacts per hour

    // Media features
    let passiveConsumption: TimeInterval
    let activeConsumption: TimeInterval

    init(
        id: Int64 = 0,
        windowStart: Date,
        windowEnd: Date,
        sessionId: Int64? = nil,
        blockLength: TimeInterval = 0,
        interruptionRate: Double = 0,
        circadianBand: CircadianBand = .unknown,
        topicLabel: String? = nil,
        topicContinuity: Double = 0,
        topicChurn: Double = 0,
        repetitionScore: Double = 0,
        taskSwitchRate: Double = 0,
        microDistractionCount: Int = 0,
        flowIndicator: Double = 0,
        grindIndicator: Double = 0,
        outputDensity: Double = 0,
        passiveConsumption: TimeInterval = 0,
        activeConsumption: TimeInterval = 0
    ) {
        self.id = id
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.sessionId = sessionId
        self.blockLength = blockLength
        self.interruptionRate = interruptionRate
        self.circadianBand = circadianBand
        self.topicLabel = topicLabel
        self.topicContinuity = topicContinuity
        self.topicChurn = topicChurn
        self.repetitionScore = repetitionScore
        self.taskSwitchRate = taskSwitchRate
        self.microDistractionCount = microDistractionCount
        self.flowIndicator = flowIndicator
        self.grindIndicator = grindIndicator
        self.outputDensity = outputDensity
        self.passiveConsumption = passiveConsumption
        self.activeConsumption = activeConsumption
    }

    var windowDuration: TimeInterval {
        windowEnd.timeIntervalSince(windowStart)
    }
}

enum CircadianBand: String, Codable {
    case earlyMorning = "early_morning" // 5-8am
    case morning = "morning" // 8-12pm
    case afternoon = "afternoon" // 12-5pm
    case evening = "evening" // 5-9pm
    case night = "night" // 9pm-1am
    case lateNight = "late_night" // 1-5am
    case unknown

    static func from(hour: Int) -> CircadianBand {
        switch hour {
        case 5..<8: return .earlyMorning
        case 8..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        case 21..<24, 0..<1: return .night
        case 1..<5: return .lateNight
        default: return .unknown
        }
    }
}
