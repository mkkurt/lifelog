import Foundation
import ScreenCaptureKit
import AppKit
import CryptoKit

/// Service responsible for capturing screen content
@MainActor
class ScreenCaptureService: ObservableObject {
    static let shared = ScreenCaptureService()

    @Published var isCapturing: Bool = false
    @Published var lastCaptureTime: Date?

    private var captureTimer: Timer?
    private var configuration: ScreenCaptureConfiguration
    private var lastScreenHash: String?
    private var availableDisplays: [SCDisplay] = []

    private let captureQueue = DispatchQueue(label: "com.lifelog.capture", qos: .utility)

    private init(configuration: ScreenCaptureConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public Methods

    /// Start continuous screen capture
    func startCapture() async throws {
        guard !isCapturing else { return }

        Logger.log("Starting screen capture", log: Logger.screenCapture)

        // Request permission and get available displays
        try await requestPermissionAndSetup()

        isCapturing = true

        // Start capture timer
        startCaptureTimer()
    }

    /// Stop screen capture
    func stopCapture() {
        guard isCapturing else { return }

        Logger.log("Stopping screen capture", log: Logger.screenCapture)

        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false
    }

    /// Update configuration
    func updateConfiguration(_ newConfig: ScreenCaptureConfiguration) {
        self.configuration = newConfig

        // Restart timer with new interval if capturing
        if isCapturing {
            startCaptureTimer()
        }
    }

    // MARK: - Private Methods

    private func requestPermissionAndSetup() async throws {
        // Get available displays
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        availableDisplays = content.displays

        guard !availableDisplays.isEmpty else {
            throw ScreenCaptureError.noDisplaysAvailable
        }

        Logger.log("Found \(availableDisplays.count) display(s)", log: Logger.screenCapture)
    }

    private func startCaptureTimer() {
        captureTimer?.invalidate()

        captureTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.captureInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performCapture()
            }
        }

        // Fire immediately
        Task {
            await performCapture()
        }
    }

    private func performCapture() async {
        guard isCapturing else { return }

        let startTime = Date()

        do {
            // Capture all displays (or just main display for better performance)
            let mainDisplay = availableDisplays.first!

            // Check if we should exclude current app
            if let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName,
               configuration.excludedApps.contains(activeApp) {
                Logger.log("Skipping capture - excluded app: \(activeApp)", log: Logger.screenCapture, type: .debug)
                return
            }

            // Create capture configuration
            let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(mainDisplay.width)
            config.height = Int(mainDisplay.height)
            config.scalesToFit = true
            config.pixelFormat = kCVPixelFormatType_32BGRA

            // Capture single frame
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )

            // Convert to data and hash
            guard let imageData = imageRepresentation(from: image) else {
                throw ScreenCaptureError.imageConversionFailed
            }

            let hash = hashImage(imageData)

            // Check if screen content changed
            if configuration.onlyCaptureOnChange {
                if let lastHash = lastScreenHash, lastHash == hash {
                    Logger.log("Screen unchanged, skipping", log: Logger.screenCapture, type: .debug)
                    return
                }
            }

            lastScreenHash = hash

            // Get context information
            let context = await getCaptureContext()

            // Create and save capture record to database
            let capture = Capture(
                timestamp: Date(),
                screenHash: hash,
                imagePath: nil // We'll process with OCR immediately
            )

            // Save capture and get the ID
            let captureId = await StorageService.shared.saveCapture(capture)

            // Create updated capture with the real ID from database
            let captureWithId = Capture(
                id: captureId,
                timestamp: capture.timestamp,
                screenHash: capture.screenHash,
                imagePath: capture.imagePath
            )

            await MainActor.run {
                lastCaptureTime = Date()
                PerformanceMonitor.shared.recordCapture()
            }

            // Send to OCR service for processing
            await OCRService.shared.processCapture(image: image, capture: captureWithId, context: context)

            let processingTime = Date().timeIntervalSince(startTime)
            Logger.log("Capture completed in \(String(format: "%.2f", processingTime))s", log: Logger.screenCapture, type: .debug)

        } catch {
            Logger.error("Capture failed: \(error.localizedDescription)", log: Logger.screenCapture)
        }
    }

    private func getCaptureContext() async -> CaptureContext {
        let mainDisplay = availableDisplays.first!
        let activeApp = NSWorkspace.shared.frontmostApplication

        return CaptureContext(
            displayID: mainDisplay.displayID,
            displayName: mainDisplay.frame.debugDescription,
            activeApp: activeApp?.localizedName,
            activeWindowTitle: nil, // Would need Accessibility API
            screenBounds: mainDisplay.frame
        )
    }

    private func imageRepresentation(from cgImage: CGImage) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: configuration.captureQuality]
        )
    }

    private func hashImage(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

enum ScreenCaptureError: LocalizedError {
    case noDisplaysAvailable
    case permissionDenied
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .noDisplaysAvailable:
            return "No displays available for capture"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .imageConversionFailed:
            return "Failed to convert captured image"
        }
    }
}
