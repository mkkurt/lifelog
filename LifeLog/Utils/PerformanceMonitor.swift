import Foundation

/// Monitors app performance metrics
@MainActor
class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()

    @Published var cpuUsage: Double = 0
    @Published var memoryUsage: Double = 0
    @Published var capturesPerMinute: Int = 0
    @Published var ocrProcessingTime: TimeInterval = 0

    private var captureCount: Int = 0
    private var monitorTimer: Timer?

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetrics()
            }
        }
    }

    func recordCapture() {
        captureCount += 1
    }

    func recordOCRTime(_ time: TimeInterval) {
        // Exponential moving average
        ocrProcessingTime = ocrProcessingTime * 0.7 + time * 0.3
    }

    private func updateMetrics() {
        capturesPerMinute = captureCount * 12 // 5-second intervals
        captureCount = 0

        // Update CPU and memory usage
        updateResourceUsage()
    }

    private func updateResourceUsage() {
        // Get memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size) / 1_048_576 // Convert to MB
            memoryUsage = usedMemory
        }
    }

    deinit {
        monitorTimer?.invalidate()
    }
}
