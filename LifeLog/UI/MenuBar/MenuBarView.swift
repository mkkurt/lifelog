import SwiftUI

struct MenuBarView: View {
    @StateObject private var screenCapture = ScreenCaptureService.shared
    @StateObject private var ocrService = OCRService.shared
    @StateObject private var privacyManager = PrivacyManager.shared
    @StateObject private var performanceMonitor = PerformanceMonitor.shared

    @State private var showingQueryView = false
    @State private var showingSettings = false
    @State private var showingDailyBrief = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main content
            if !privacyManager.hasScreenRecordingPermission {
                permissionRequiredView
            } else if showingQueryView {
                QueryView(isPresented: $showingQueryView)
            } else if showingDailyBrief {
                DailyBriefView(isPresented: $showingDailyBrief)
            } else {
                statusView
            }

            Divider()

            // Footer with actions
            footerView
        }
        .frame(width: 400, height: 500)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "book.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)

            Text("LifeLog")
                .font(.headline)
                .fontWeight(.bold)

            Spacer()

            // Recording indicator
            if screenCapture.isCapturing {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .blinking()

                    Text("Recording")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Permission Required

    private var permissionRequiredView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Permission Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("LifeLog needs screen recording permission to capture and analyze your screen.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button("Open System Settings") {
                    privacyManager.openScreenRecordingSettings()
                }
                .buttonStyle(.borderedProminent)

                Button("Check Permission Again") {
                    Task {
                        await privacyManager.checkPermissions()
                    }
                }
                .buttonStyle(.bordered)
            }

            Text("After granting permission in System Settings, click 'Check Permission Again'.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    // MARK: - Status View

    private var statusView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status cards
                StatusCard(
                    title: "Capture Status",
                    icon: "camera.circle.fill",
                    color: screenCapture.isCapturing ? .green : .gray
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Status:")
                            Spacer()
                            Text(screenCapture.isCapturing ? "Active" : "Stopped")
                                .fontWeight(.semibold)
                                .foregroundColor(screenCapture.isCapturing ? .green : .secondary)
                        }

                        if let lastCapture = screenCapture.lastCaptureTime {
                            HStack {
                                Text("Last capture:")
                                Spacer()
                                Text(lastCapture, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Text("Rate:")
                            Spacer()
                            Text("\(performanceMonitor.capturesPerMinute)/min")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                }

                StatusCard(
                    title: "OCR Processing",
                    icon: "doc.text.magnifyingglass",
                    color: .blue
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Queue:")
                            Spacer()
                            Text("\(ocrService.pendingCount) items")
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("Avg time:")
                            Spacer()
                            Text(String(format: "%.2fs", performanceMonitor.ocrProcessingTime))
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                }

                StatusCard(
                    title: "Performance",
                    icon: "gauge.high",
                    color: .purple
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Memory:")
                            Spacer()
                            Text(String(format: "%.1f MB", performanceMonitor.memoryUsage))
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                }

                // Quick actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)
                        .padding(.horizontal)

                    Button(action: { showingDailyBrief = true }) {
                        Label("View Daily Brief", systemImage: "chart.bar.doc.horizontal")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)

                    Button(action: { showingQueryView = true }) {
                        Label("Ask LifeLog a Question", systemImage: "bubble.left.and.bubble.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                }
            }
            .padding()
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button(action: toggleCapture) {
                Label(
                    screenCapture.isCapturing ? "Stop" : "Start",
                    systemImage: screenCapture.isCapturing ? "stop.circle" : "play.circle"
                )
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(action: { showingSettings = true }) {
                Image(systemName: "gear")
            }
            .buttonStyle(.bordered)

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Actions

    private func toggleCapture() {
        Task {
            if screenCapture.isCapturing {
                await screenCapture.stopCapture()
            } else {
                try? await screenCapture.startCapture()
            }
        }
    }
}

// MARK: - Status Card

struct StatusCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }

            content
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Blinking Animation

struct BlinkingModifier: ViewModifier {
    @State private var isBlinking = false

    func body(content: Content) -> some View {
        content
            .opacity(isBlinking ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isBlinking)
            .onAppear {
                isBlinking = true
            }
    }
}

extension View {
    func blinking() -> some View {
        modifier(BlinkingModifier())
    }
}

#Preview {
    MenuBarView()
}
