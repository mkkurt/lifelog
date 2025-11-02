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

        // Check permissions on startup (silently - don't trigger prompts)
        Task {
            // Small delay to ensure UI is ready
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Check permission status silently (won't show prompt)
            await PrivacyManager.shared.checkPermissions()

            // Start Meaning Engine and Data Compaction if permission granted
            if await PrivacyManager.shared.hasScreenRecordingPermission {
                await MeaningEngine.shared.start()
                Logger.log("Meaning Engine started", log: Logger.ui)

                // Start data compaction service for intelligent summarization
                await DataCompactionService.shared.startCompaction()
                Logger.log("Data Compaction Service started", log: Logger.ui)
            } else {
                Logger.log("Screen recording permission not granted - services not started", log: Logger.ui)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop all services before quitting
        Task {
            await ScreenCaptureService.shared.stopCapture()
            await MeaningEngine.shared.stop()
            await DataCompactionService.shared.stopCompaction()
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
