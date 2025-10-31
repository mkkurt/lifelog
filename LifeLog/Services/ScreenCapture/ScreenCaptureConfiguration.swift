import Foundation

/// Configuration for screen capture behavior
struct ScreenCaptureConfiguration {
    /// Interval between captures in seconds
    var captureInterval: TimeInterval = 10.0

    /// Minimum time between captures even if content changes
    var minimumCaptureInterval: TimeInterval = 2.0

    /// Quality of screen capture (0.0 - 1.0)
    var captureQuality: CGFloat = 0.8

    /// Whether to capture only when screen content changes
    var onlyCaptureOnChange: Bool = true

    /// Threshold for detecting screen changes (0.0 - 1.0)
    /// Lower = more sensitive to changes
    var changeThreshold: Double = 0.05

    /// Maximum number of captures to keep in memory before flushing
    var maxCapturesInMemory: Int = 10

    /// Apps to exclude from capture
    var excludedApps: Set<String> = [
        "1Password",
        "Keychain Access",
        "LastPass",
        "Bitwarden"
    ]

    /// Whether to pause during screensavers
    var pauseOnScreensaver: Bool = true

    /// Whether to pause when screen is locked
    var pauseOnLock: Bool = true

    static let `default` = ScreenCaptureConfiguration()
}
