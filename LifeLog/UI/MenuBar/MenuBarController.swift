import AppKit
import SwiftUI

/// Controls the menu bar item and popover
@MainActor
class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    @Published var isRecording: Bool = false

    init() {
        setupMenuBar()
        setupPopover()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusIcon()
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Update icon based on recording state
        Task {
            for await _ in NotificationCenter.default.notifications(named: .captureStateChanged) {
                updateStatusIcon()
            }
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 400, height: 500)
        popover?.behavior = .transient // Auto-dismiss on outside click
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }

        // Use SF Symbols
        let iconName = isRecording ? "record.circle.fill" : "record.circle"
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "LifeLog")
        button.image?.isTemplate = true
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }

        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showMenu()
        } else {
            if let popover = popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Query LifeLog", action: #selector(showQuery), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        let recordingItem = NSMenuItem(
            title: isRecording ? "Stop Recording" : "Start Recording",
            action: #selector(toggleRecording),
            keyEquivalent: ""
        )
        recordingItem.target = self
        menu.addItem(recordingItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func showQuery() {
        togglePopover(nil)
    }

    @objc private func toggleRecording() {
        Task {
            if isRecording {
                await ScreenCaptureService.shared.stopCapture()
                isRecording = false
            } else {
                do {
                    try await ScreenCaptureService.shared.startCapture()
                    isRecording = true
                } catch {
                    showError(error.localizedDescription)
                }
            }
            updateStatusIcon()
        }
    }

    @objc private func showSettings() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}

extension Notification.Name {
    static let captureStateChanged = Notification.Name("captureStateChanged")
}
