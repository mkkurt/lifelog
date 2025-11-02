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
            // Only show header when on main status view
            if !showingQueryView && !showingDailyBrief {
                headerView
                Divider()
            }

            // Main content
            Group {
                if !privacyManager.hasScreenRecordingPermission {
                    permissionRequiredView
                } else if showingQueryView {
                    QueryView(isPresented: $showingQueryView)
                } else if showingDailyBrief {
                    DailyBriefView(isPresented: $showingDailyBrief)
                } else {
                    statusView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Only show footer on main status view
            if !showingQueryView && !showingDailyBrief && privacyManager.hasScreenRecordingPermission {
                Divider()
                footerView
            }
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
                        .modifier(BlinkingModifier(isEnabled: true))

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
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 20)

                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.orange)

                VStack(spacing: 8) {
                    Text("Permission Required")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("LifeLog needs screen recording permission to capture and analyze your screen.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button("Grant Permission") {
                        Task {
                            let granted = await privacyManager.requestScreenRecordingPermission()
                            if granted {
                                // Permission granted, start all services
                                try? await screenCapture.startCapture()
                                await MeaningEngine.shared.start()
                                await DataCompactionService.shared.startCompaction()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: 200)

                    Button("Open System Settings") {
                        privacyManager.openScreenRecordingSettings()

                        // Start polling for permission changes
                        Task {
                            // Poll every 1 second for up to 60 seconds
                            for _ in 0..<60 {
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                await privacyManager.checkPermissions()

                                // If permission granted, start all services and break
                                if privacyManager.hasScreenRecordingPermission {
                                    try? await screenCapture.startCapture()
                                    await MeaningEngine.shared.start()
                                    await DataCompactionService.shared.startCompaction()
                                    break
                                }
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: 200)

                    Button("Refresh Status") {
                        Task {
                            await privacyManager.checkPermissions()

                            // Auto-start all services if permission is now granted
                            if privacyManager.hasScreenRecordingPermission && !screenCapture.isCapturing {
                                try? await screenCapture.startCapture()
                                await MeaningEngine.shared.start()
                                await DataCompactionService.shared.startCompaction()
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: 200)
                }
                .padding(.vertical, 8)

                Text("Click 'Grant Permission' to trigger the system prompt, or manually enable in System Settings and click 'Refresh Status'.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 20)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Status View

    private var statusView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Recording status banner
                recordingStatusBanner

                // Quick action cards
                HStack(spacing: 12) {
                    QuickActionCard(
                        icon: "brain.head.profile",
                        title: "Ask a Question",
                        subtitle: "Query your activity",
                        color: .blue,
                        action: { showingQueryView = true }
                    )

                    QuickActionCard(
                        icon: "chart.bar.doc.horizontal",
                        title: "Daily Brief",
                        subtitle: "View insights",
                        color: .purple,
                        action: { showingDailyBrief = true }
                    )
                }
                .padding(.horizontal)

                // Today's activity summary
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "calendar.circle.fill")
                            .foregroundColor(.orange)
                        Text("Today's Activity")
                            .font(.headline)
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        if let lastCapture = screenCapture.lastCaptureTime {
                            ActivityRow(
                                icon: "camera.fill",
                                label: "Last captured",
                                value: lastCapture.formatted(.relative(presentation: .named))
                            )
                        }

                        ActivityRow(
                            icon: "text.magnifyingglass",
                            label: "OCR queue",
                            value: ocrService.pendingCount == 0 ? "Up to date" : "\(ocrService.pendingCount) pending"
                        )

                        ActivityRow(
                            icon: "memorychip",
                            label: "Memory usage",
                            value: String(format: "%.0f MB", performanceMonitor.memoryUsage)
                        )
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
    }

    private var recordingStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: screenCapture.isCapturing ? "record.circle.fill" : "record.circle")
                .font(.title)
                .foregroundColor(screenCapture.isCapturing ? .red : .secondary)
                .modifier(BlinkingModifier(isEnabled: screenCapture.isCapturing))

            VStack(alignment: .leading, spacing: 4) {
                Text(screenCapture.isCapturing ? "Recording Active" : "Recording Paused")
                    .font(.headline)
                    .foregroundColor(screenCapture.isCapturing ? .primary : .secondary)

                Text(screenCapture.isCapturing
                     ? "Capturing \(performanceMonitor.capturesPerMinute) times/min"
                     : "Tap Start to begin recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(screenCapture.isCapturing
                    ? Color.green.opacity(0.1)
                    : Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .padding(.horizontal)
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

// MARK: - Supporting Views

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct ActivityRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Blinking Animation

struct BlinkingModifier: ViewModifier {
    let isEnabled: Bool
    @State private var isBlinking = false

    func body(content: Content) -> some View {
        content
            .opacity(isEnabled && isBlinking ? 0.3 : 1.0)
            .animation(isEnabled ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isBlinking)
            .onChange(of: isEnabled) { _, newValue in
                isBlinking = newValue
            }
            .onAppear {
                isBlinking = isEnabled
            }
    }
}

#Preview {
    MenuBarView()
}
