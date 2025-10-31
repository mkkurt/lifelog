import Foundation

/// Represents a single user interaction event
struct InteractionEvent: Identifiable, Codable {
    let id: Int64
    let timestamp: Date
    let type: InteractionType
    let appName: String?
    let windowTitle: String?
    let intensity: Int // count of events in burst
    let sessionId: Int64?
    let metadata: [String: String]?

    init(
        id: Int64 = 0,
        timestamp: Date = Date(),
        type: InteractionType,
        appName: String? = nil,
        windowTitle: String? = nil,
        intensity: Int = 1,
        sessionId: Int64? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.appName = appName
        self.windowTitle = windowTitle
        self.intensity = intensity
        self.sessionId = sessionId
        self.metadata = metadata
    }
}

enum InteractionType: String, Codable {
    case keystroke
    case mouseClick
    case mouseMove
    case windowSwitch
    case appSwitch
    case scroll
    case focusGained
    case focusLost
}
