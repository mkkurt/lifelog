import Foundation

/// AI-generated summary of a time period
struct Summary: Identifiable, Codable {
    let id: Int64
    let startTime: Date
    let endTime: Date
    let summary: String
    let keywords: [String]
    let activityType: ActivityType?

    enum ActivityType: String, Codable {
        case coding
        case writing
        case browsing
        case communication
        case meeting
        case entertainment
        case other
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Query response from AI
struct QueryResponse {
    let query: String
    let response: String
    let relevantEntries: [TextEntry]
    let confidence: Float
    let timestamp: Date

    init(query: String, response: String, relevantEntries: [TextEntry] = [], confidence: Float = 1.0) {
        self.query = query
        self.response = response
        self.relevantEntries = relevantEntries
        self.confidence = confidence
        self.timestamp = Date()
    }
}
