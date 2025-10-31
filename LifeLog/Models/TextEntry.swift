import Foundation
import CoreGraphics

/// Represents recognized text from a screen capture
struct TextEntry: Identifiable, Codable {
    let id: Int64
    let captureId: Int64
    let timestamp: Date
    let rawText: String
    let confidence: Float
    let appName: String?
    let windowTitle: String?
    let screenRegion: CGRect?

    init(
        id: Int64 = 0,
        captureId: Int64,
        timestamp: Date = Date(),
        rawText: String,
        confidence: Float,
        appName: String? = nil,
        windowTitle: String? = nil,
        screenRegion: CGRect? = nil
    ) {
        self.id = id
        self.captureId = captureId
        self.timestamp = timestamp
        self.rawText = rawText
        self.confidence = confidence
        self.appName = appName
        self.windowTitle = windowTitle
        self.screenRegion = screenRegion
    }
}

/// Result from OCR processing
struct OCRResult {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    let recognizedLanguages: [String]

    var isHighConfidence: Bool {
        confidence > 0.7
    }
}
