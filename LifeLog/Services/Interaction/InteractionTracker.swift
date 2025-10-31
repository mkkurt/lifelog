import Foundation
import AppKit
import ApplicationServices

/// Tracks user interactions (keyboard, mouse, window switches) for behavioral analysis
@MainActor
class InteractionTracker: ObservableObject {
    static let shared = InteractionTracker()

    @Published var isTracking = false
    @Published var currentApp: String?
    @Published var currentWindow: String?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Burst tracking
    private var keystrokeBuffer: [Date] = []
    private var mouseClickBuffer: [Date] = []
    private var mouseMoveBuffer: [Date] = []
    private let burstWindow: TimeInterval = 2.0 // 2 second window for intensity calculation

    // Session tracking
    private var currentSessionId: Int64?
    private var lastInteractionTime: Date?
    private let sessionTimeout: TimeInterval = 300 // 5 minutes of inactivity = new session

    // Throttling
    private var lastEventSaveTime: Date?
    private let saveInterval: TimeInterval = 10.0 // Save aggregated events every 10 seconds

    private init() {
        setupAppObserver()
    }

    // MARK: - Public Interface

    func startTracking() {
        guard !isTracking else { return }

        Task {
            // Check for accessibility permissions
            guard await checkAccessibilityPermissions() else {
                Logger.error("Accessibility permissions not granted", log: Logger.privacy)
                return
            }

            await startSession()
            setupEventTap()
            isTracking = true

            Logger.log("InteractionTracker started", log: Logger.screenCapture)
        }
    }

    func stopTracking() {
        guard isTracking else { return }

        removeEventTap()

        Task {
            await endCurrentSession()
            isTracking = false

            Logger.log("InteractionTracker stopped", log: Logger.screenCapture)
        }
    }

    // MARK: - Permissions

    private func checkAccessibilityPermissions() async -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Session Management

    private func startSession() async {
        let session = Session(
            startTime: Date(),
            endTime: nil,
            primaryTopic: nil,
            appSequence: [],
            windowCount: 0,
            interactionCount: 0,
            outputArtifacts: 0
        )

        currentSessionId = await StorageService.shared.saveSession(session)
        lastInteractionTime = Date()

        Logger.log("Started new session: \(currentSessionId ?? 0)", log: Logger.screenCapture, type: .debug)
    }

    private func endCurrentSession() async {
        guard let sessionId = currentSessionId else { return }

        await StorageService.shared.endSession(sessionId, endTime: Date())
        currentSessionId = nil

        Logger.log("Ended session: \(sessionId)", log: Logger.screenCapture, type: .debug)
    }

    private func checkSessionTimeout() async {
        guard let lastTime = lastInteractionTime else { return }

        let timeSinceLastInteraction = Date().timeIntervalSince(lastTime)
        if timeSinceLastInteraction > sessionTimeout {
            await endCurrentSession()
            await startSession()
        }
    }

    // MARK: - Event Tap Setup

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                       (1 << CGEventType.leftMouseDown.rawValue) |
                       (1 << CGEventType.rightMouseDown.rawValue) |
                       (1 << CGEventType.mouseMoved.rawValue) |
                       (1 << CGEventType.scrollWheel.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let tracker = Unmanaged<InteractionTracker>.fromOpaque(refcon).takeUnretainedValue()

                Task { @MainActor in
                    tracker.handleEvent(type: type, event: event)
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Logger.error("Failed to create event tap", log: Logger.privacy)
            return
        }

        self.eventTap = eventTap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        self.runLoopSource = runLoopSource
    }

    private func removeEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
    }

    // MARK: - Event Handling

    private func handleEvent(type: CGEventType, event: CGEvent) {
        let now = Date()
        lastInteractionTime = now

        Task {
            await checkSessionTimeout()
        }

        switch type {
        case .keyDown:
            keystrokeBuffer.append(now)
            cleanBuffer(&keystrokeBuffer, window: burstWindow)

        case .leftMouseDown, .rightMouseDown:
            mouseClickBuffer.append(now)
            cleanBuffer(&mouseClickBuffer, window: burstWindow)

        case .mouseMoved, .scrollWheel:
            mouseMoveBuffer.append(now)
            cleanBuffer(&mouseMoveBuffer, window: burstWindow)

        default:
            break
        }

        // Throttle event saving
        if let lastSave = lastEventSaveTime, now.timeIntervalSince(lastSave) < saveInterval {
            return
        }

        lastEventSaveTime = now

        Task {
            await saveAggregatedEvents()
        }
    }

    private func cleanBuffer(_ buffer: inout [Date], window: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-window)
        buffer.removeAll { $0 < cutoff }
    }

    private func saveAggregatedEvents() async {
        let now = Date()

        // Save keystroke burst if significant
        if keystrokeBuffer.count > 5 {
            let event = InteractionEvent(
                timestamp: now,
                type: .keystroke,
                appName: currentApp,
                windowTitle: currentWindow,
                intensity: keystrokeBuffer.count,
                sessionId: currentSessionId,
                metadata: nil
            )
            _ = await StorageService.shared.saveInteractionEvent(event)
        }

        // Save mouse click burst if significant
        if mouseClickBuffer.count > 3 {
            let event = InteractionEvent(
                timestamp: now,
                type: .mouseClick,
                appName: currentApp,
                windowTitle: currentWindow,
                intensity: mouseClickBuffer.count,
                sessionId: currentSessionId,
                metadata: nil
            )
            _ = await StorageService.shared.saveInteractionEvent(event)
        }

        // Save mouse movement if significant
        if mouseMoveBuffer.count > 10 {
            let event = InteractionEvent(
                timestamp: now,
                type: .mouseMove,
                appName: currentApp,
                windowTitle: currentWindow,
                intensity: mouseMoveBuffer.count,
                sessionId: currentSessionId,
                metadata: nil
            )
            _ = await StorageService.shared.saveInteractionEvent(event)
        }

        // Clear buffers after saving
        keystrokeBuffer.removeAll()
        mouseClickBuffer.removeAll()
        mouseMoveBuffer.removeAll()
    }

    // MARK: - App/Window Tracking

    private func setupAppObserver() {
        let workspace = NSWorkspace.shared

        // Observe app activation
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }

            let appName = app.localizedName ?? "Unknown"
            self?.handleAppSwitch(to: appName)
        }

        // Set initial app
        if let frontApp = workspace.frontmostApplication {
            currentApp = frontApp.localizedName ?? "Unknown"
        }
    }

    private func handleAppSwitch(to appName: String) {
        let oldApp = currentApp
        currentApp = appName
        currentWindow = nil // Window title requires accessibility API

        Task {
            let event = InteractionEvent(
                timestamp: Date(),
                type: .appSwitch,
                appName: appName,
                windowTitle: nil,
                intensity: 1,
                sessionId: currentSessionId,
                metadata: ["previousApp": oldApp ?? "None"]
            )
            _ = await StorageService.shared.saveInteractionEvent(event)

            Logger.log("App switch: \(oldApp ?? "None") -> \(appName)", log: Logger.screenCapture, type: .debug)
        }
    }

    // MARK: - Statistics

    func getRecentInteractionCount(minutes: Int = 5) async -> Int {
        // This would query the database for recent interactions
        // For now, return a simple count from buffers
        return keystrokeBuffer.count + mouseClickBuffer.count
    }
}
