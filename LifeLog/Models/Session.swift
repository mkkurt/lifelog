import Foundation

/// Represents a continuous work session
struct Session: Identifiable, Codable {
    let id: Int64
    let startTime: Date
    let endTime: Date?
    let primaryTopic: String?
    let appSequence: [String] // apps used in order
    let windowCount: Int
    let interactionCount: Int
    let outputArtifacts: Int

    init(
        id: Int64 = 0,
        startTime: Date = Date(),
        endTime: Date? = nil,
        primaryTopic: String? = nil,
        appSequence: [String] = [],
        windowCount: Int = 0,
        interactionCount: Int = 0,
        outputArtifacts: Int = 0
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.primaryTopic = primaryTopic
        self.appSequence = appSequence
        self.windowCount = windowCount
        self.interactionCount = interactionCount
        self.outputArtifacts = outputArtifacts
    }

    var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    var isActive: Bool {
        endTime == nil
    }
}
