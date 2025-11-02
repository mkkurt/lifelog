import Foundation
import Vision
import CoreGraphics
import AppKit

/// Service responsible for performing OCR on captured screens
@MainActor
class OCRService: ObservableObject {
    static let shared = OCRService()

    @Published var isProcessing: Bool = false
    @Published var pendingCount: Int = 0

    private let processingQueue = DispatchQueue(label: "com.lifelog.ocr", qos: .utility)
    private let maxConcurrentOCR = 2
    nonisolated private let semaphore: DispatchSemaphore

    private init() {
        self.semaphore = DispatchSemaphore(value: maxConcurrentOCR)
    }

    /// Process a captured image with OCR
    func processCapture(image: CGImage, capture: Capture, context: CaptureContext) async {
        pendingCount += 1
        isProcessing = true

        defer {
            Task { @MainActor in
                pendingCount -= 1
                if pendingCount == 0 {
                    isProcessing = false
                }
            }
        }

        let startTime = Date()

        await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                self?.semaphore.wait()
                defer { self?.semaphore.signal() }

                self?.performOCR(on: image, capture: capture, context: context) { result in
                    let processingTime = Date().timeIntervalSince(startTime)

                    Task { @MainActor in
                        PerformanceMonitor.shared.recordOCRTime(processingTime)

                        switch result {
                        case .success(let ocrResults):
                            Logger.log("OCR found \(ocrResults.count) text regions in \(String(format: "%.2f", processingTime))s", log: Logger.ocr, type: .debug)

                            // Save to storage
                            await self?.saveOCRResults(ocrResults, for: capture, context: context)

                        case .failure(let error):
                            Logger.error("OCR failed: \(error.localizedDescription)", log: Logger.ocr)
                        }

                        continuation.resume()
                    }
                }
            }
        }
    }

    // MARK: - Private Methods

    nonisolated private func performOCR(
        on image: CGImage,
        capture: Capture,
        context: CaptureContext,
        completion: @escaping (Result<[OCRResult], Error>) -> Void
    ) {
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.success([]))
                return
            }

            let results = observations.compactMap { observation -> OCRResult? in
                guard let topCandidate = observation.topCandidates(1).first else {
                    return nil
                }

                // Filter low confidence results
                guard topCandidate.confidence > 0.5 else {
                    return nil
                }

                return OCRResult(
                    text: topCandidate.string,
                    confidence: topCandidate.confidence,
                    boundingBox: observation.boundingBox,
                    recognizedLanguages: [observation.topCandidates(1).first?.string ?? "en"]
                )
            }

            completion(.success(results))
        }

        // Configure for accuracy and speed balance
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-GB"]

        // Automatically detect language if needed
        request.automaticallyDetectsLanguage = true

        // Perform request
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }

    private func saveOCRResults(
        _ results: [OCRResult],
        for capture: Capture,
        context: CaptureContext
    ) async {
        guard !results.isEmpty else { return }

        // Combine all text
        let combinedText = results
            .map { $0.text }
            .joined(separator: " ")

        // Skip if text is too short or just noise
        guard combinedText.count > 10 else { return }

        // Calculate average confidence
        let avgConfidence = results.reduce(0.0) { $0 + $1.confidence } / Float(results.count)

        let textEntry = TextEntry(
            captureId: capture.id,
            timestamp: capture.timestamp,
            rawText: combinedText,
            confidence: avgConfidence,
            appName: context.activeApp,
            windowTitle: context.activeWindowTitle,
            screenRegion: nil // Could calculate overall bounding box
        )

        // Save raw text entry (for debugging and backup)
        // Note: Raw entries will be kept for a short time, then cleaned up
        await StorageService.shared.saveTextEntry(textEntry)

        Logger.log("Saved text entry: \(combinedText.prefix(50))...", log: Logger.ocr, type: .debug)

        // Note: Data compaction happens in background via DataCompactionService
        // which batches entries into narratives every 5 minutes
    }
}
