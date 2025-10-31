import Foundation

/// Represents an inferred hypothesis about user behavior
struct Hypothesis: Identifiable, Codable {
    let id: Int64
    let timestamp: Date
    let type: HypothesisType
    let confidence: Double // 0-1
    let evidence: [String] // list of supporting feature descriptions
    let startTime: Date
    let endTime: Date?
    let metadata: [String: String]?

    init(
        id: Int64 = 0,
        timestamp: Date = Date(),
        type: HypothesisType,
        confidence: Double,
        evidence: [String] = [],
        startTime: Date,
        endTime: Date? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.confidence = confidence
        self.evidence = evidence
        self.startTime = startTime
        self.endTime = endTime
        self.metadata = metadata
    }

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var isActive: Bool {
        endTime == nil
    }
}

enum HypothesisType: String, Codable, CaseIterable {
    case deepWork = "deep_work"
    case stuck = "stuck"
    case exploration = "exploration"
    case drift = "drift"
    case scatter = "scatter"
    case complexityBuildup = "complexity_buildup"
    case looping = "looping"
    case flow = "flow"
    case grind = "grind"

    var displayName: String {
        switch self {
        case .deepWork: return "Deep Work Block"
        case .stuck: return "Stuck Point"
        case .exploration: return "Exploration"
        case .drift: return "Drift/Distraction"
        case .scatter: return "Scatter/Fragmentation"
        case .complexityBuildup: return "Complexity Build-up"
        case .looping: return "Looping Pattern"
        case .flow: return "Flow State"
        case .grind: return "Grinding"
        }
    }

    var description: String {
        switch self {
        case .deepWork: return "Sustained focus on a single topic with steady progress"
        case .stuck: return "Repeated cycles on same topic with low output"
        case .exploration: return "Active learning and information gathering"
        case .drift: return "Passive consumption with low relevance to goals"
        case .scatter: return "Frequent context switches and short focus blocks"
        case .complexityBuildup: return "Rising tool/source diversity requiring scope management"
        case .looping: return "Repetitive return to same sources without progress"
        case .flow: return "Deep engagement with high productivity"
        case .grind: return "High effort with slow progress"
        }
    }

    var actionable: Bool {
        switch self {
        case .stuck, .drift, .scatter, .complexityBuildup, .looping: return true
        case .deepWork, .exploration, .flow, .grind: return false
        }
    }
}

/// Represents evidence supporting a hypothesis
struct Evidence: Identifiable, Codable {
    let id: Int64
    let hypothesisId: Int64
    let featureId: Int64
    let weight: Double // contribution to confidence
    let reason: String // human-readable explanation

    init(
        id: Int64 = 0,
        hypothesisId: Int64,
        featureId: Int64,
        weight: Double,
        reason: String
    ) {
        self.id = id
        self.hypothesisId = hypothesisId
        self.featureId = featureId
        self.weight = weight
        self.reason = reason
    }
}
