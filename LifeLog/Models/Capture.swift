import Foundation
import CoreGraphics

/// Represents a single screen capture instance
struct Capture: Identifiable, Codable {
    let id: Int64
    let timestamp: Date
    let screenHash: String
    let imagePath: String?

    init(id: Int64 = 0, timestamp: Date = Date(), screenHash: String, imagePath: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.screenHash = screenHash
        self.imagePath = imagePath
    }
}

/// Metadata about the capture context
struct CaptureContext: Codable {
    let displayID: CGDirectDisplayID
    let displayName: String?
    let activeApp: String?
    let activeWindowTitle: String?
    let screenBounds: CGRect

    var dictionary: [String: Any] {
        [
            "displayID": displayID,
            "displayName": displayName ?? "",
            "activeApp": activeApp ?? "",
            "activeWindowTitle": activeWindowTitle ?? "",
            "bounds": [
                "x": screenBounds.origin.x,
                "y": screenBounds.origin.y,
                "width": screenBounds.size.width,
                "height": screenBounds.size.height
            ]
        ]
    }
}
