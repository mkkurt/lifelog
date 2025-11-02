import Foundation

/// Represents a compacted, narrative summary of user activity
/// This replaces raw OCR text with intelligent, structured summaries
struct ActivityNarrative: Identifiable, Codable {
    let id: Int64
    let timestamp: Date
    let duration: TimeInterval
    let appName: String
    let narrative: String // e.g., "Visited Firefox, spent 5 minutes reading documentation about SwiftUI..."
    let actions: [String] // Extracted key actions: ["read documentation", "switched tabs", "wrote code"]
    let topics: [String] // Extracted topics: ["SwiftUI", "macOS development"]
    let contextHash: String // Hash of source data to prevent duplicates

    init(
        id: Int64 = 0,
        timestamp: Date = Date(),
        duration: TimeInterval,
        appName: String,
        narrative: String,
        actions: [String] = [],
        topics: [String] = [],
        contextHash: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.duration = duration
        self.appName = appName
        self.narrative = narrative
        self.actions = actions
        self.topics = topics
        self.contextHash = contextHash
    }
}

/// Window of raw captures to be compacted
struct CaptureWindow {
    let startTime: Date
    let endTime: Date
    let captures: [TextEntry]
    let appName: String

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    /// Generate a unique hash for this window to prevent duplicate processing
    func generateHash() -> String {
        let combined = captures.map { "\($0.timestamp.timeIntervalSince1970):\($0.rawText)" }.joined(separator: "|")
        return combined.sha256Hash()
    }
}

// MARK: - String Extensions

extension String {
    func sha256Hash() -> String {
        guard let data = self.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { buffer in
            // Simple hash for duplicate detection
            // In production, use CryptoKit.SHA256
            var h: UInt32 = 5381
            for byte in buffer {
                h = ((h << 5) &+ h) &+ UInt32(byte)
            }
            let hashString = String(h, radix: 16)
            let bytes = hashString.utf8
            for (i, byte) in bytes.enumerated() where i < 32 {
                hash[i] = byte
            }
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
