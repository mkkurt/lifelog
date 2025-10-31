import SwiftUI

@main
struct LifeLogApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var performanceMonitor = PerformanceMonitor.shared

    var body: some Scene {
        // Menu bar app doesn't need a window scene
        Settings {
            SettingsView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock
        NSApp.setActivationPolicy(.accessory)

        // Initialize menu bar
        menuBarController = MenuBarController()

        Logger.log("LifeLog started", log: Logger.ui)

        // Check permissions on startup
        Task {
            // Small delay to ensure UI is ready
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Check/request permission (this handles both checking and requesting)
            await checkAndRequestPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop capture before quitting
        Task {
            await ScreenCaptureService.shared.stopCapture()
        }
    }

    private func checkAndRequestPermission() async {
        let privacyManager = PrivacyManager.shared

        // This single call both checks and requests permission
        // If permission is already granted, it succeeds silently
        // If not granted, it triggers the system prompt
        let granted = await privacyManager.requestScreenRecordingPermission()

        if !granted {
            // Permission was denied, show our help alert
            await MainActor.run {
                showPermissionAlert()
            }
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "LifeLog needs screen recording permission to capture your screen and perform OCR. Please grant permission in System Preferences."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            PrivacyManager.shared.openScreenRecordingSettings()
        }
    }
}
