import Foundation
import ScreenCaptureKit
import AppKit

/// Manages privacy and permissions for LifeLog
@MainActor
class PrivacyManager: ObservableObject {
    static let shared = PrivacyManager()

    @Published var hasScreenRecordingPermission: Bool = false
    @Published var isCheckingPermission: Bool = false

    private init() {
        // Don't automatically check permissions on init to avoid duplicate prompts
        // Permission will be checked/requested by AppDelegate
    }

    /// Check all required permissions (non-intrusive, doesn't trigger prompts)
    func checkPermissions() async {
        isCheckingPermission = true
        defer { isCheckingPermission = false }

        // Check screen recording permission silently
        await checkScreenRecordingPermission()

        Logger.log("Permission check complete: hasScreenRecording=\(hasScreenRecordingPermission)", log: Logger.privacy)
    }

    /// Request screen recording permission (shows system prompt if needed)
    func requestScreenRecordingPermission() async -> Bool {
        Logger.log("Requesting screen recording permission...", log: Logger.privacy)

        // Try to get shareable content - this will trigger permission prompt if needed
        // If permission is already granted, this succeeds silently
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            hasScreenRecordingPermission = true
            Logger.log("✅ Screen recording permission granted - found \(content.displays.count) display(s)", log: Logger.privacy)
            return true

        } catch {
            hasScreenRecordingPermission = false
            let errorDesc = error.localizedDescription
            Logger.error("❌ Screen recording permission denied: \(errorDesc)", log: Logger.privacy)

            // Log detailed error info
            if let scError = error as? SCStreamError {
                Logger.error("SCStreamError code: \(scError.errorCode)", log: Logger.privacy)
            }

            return false
        }
    }

    /// Open System Settings to Screen Recording settings
    func openScreenRecordingSettings() {
        // Modern macOS 13+ uses different URL scheme
        if #available(macOS 13.0, *) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture")!)
        } else {
            // Fallback for macOS 12 and earlier
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
        }
    }

    /// Check if app should be excluded from capture
    func shouldExcludeApp(_ bundleIdentifier: String?) -> Bool {
        guard let bundleId = bundleIdentifier else { return false }

        // List of sensitive apps to exclude
        let excludedBundleIds = [
            "com.1password",
            "com.agilebits.onepassword7",
            "com.lastpass.LastPass",
            "com.bitwarden.desktop",
            "com.apple.keychainaccess"
        ]

        return excludedBundleIds.contains(bundleId)
    }

    /// Detect if text might be sensitive (passwords, credit cards, etc.)
    func isSensitiveText(_ text: String) -> Bool {
        // Pattern matching for potentially sensitive data
        let patterns = [
            // Credit card numbers (simple pattern)
            "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b",
            // Social Security Numbers
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",
            // Common password field indicators
            "(?i)password\\s*[:=]",
            // API keys/tokens (long alphanumeric strings)
            "\\b[A-Za-z0-9]{32,}\\b"
        ]

        for pattern in patterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }

        return false
    }

    // MARK: - Private Methods

    private func checkScreenRecordingPermission() async {
        // macOS doesn't provide a direct API to check screen recording permission
        // We need to try to access it
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            hasScreenRecordingPermission = true
        } catch {
            hasScreenRecordingPermission = false
        }
    }
}
