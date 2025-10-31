import Foundation
import os.log

/// Centralized logging system for LifeLog
enum Logger {
    private static let subsystem = "com.lifelog.LifeLog"

    static let screenCapture = OSLog(subsystem: subsystem, category: "ScreenCapture")
    static let ocr = OSLog(subsystem: subsystem, category: "OCR")
    static let storage = OSLog(subsystem: subsystem, category: "Storage")
    static let ai = OSLog(subsystem: subsystem, category: "AI")
    static let performance = OSLog(subsystem: subsystem, category: "Performance")
    static let privacy = OSLog(subsystem: subsystem, category: "Privacy")
    static let ui = OSLog(subsystem: subsystem, category: "UI")

    static func log(_ message: String, log: OSLog = .default, type: OSLogType = .default) {
        os_log("%{public}@", log: log, type: type, message)
    }

    static func error(_ message: String, log: OSLog = .default) {
        os_log("%{public}@", log: log, type: .error, message)
    }

    static func debug(_ message: String, log: OSLog = .default) {
        #if DEBUG
        os_log("%{public}@", log: log, type: .debug, message)
        #endif
    }
}
