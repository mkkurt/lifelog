import SwiftUI

struct SettingsView: View {
    @StateObject private var aiService = AIService.shared
    @StateObject private var screenCapture = ScreenCaptureService.shared

    @State private var apiKey: String = ""
    @State private var captureInterval: Double = 10.0
    @State private var onlyCaptureOnChange: Bool = true
    @State private var pauseWhenLocked: Bool = true
    @State private var excludedApps: String = ""
    @State private var selectedBackend: AIBackend = .appleIntelligence

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            aiSettings
                .tabItem {
                    Label("AI", systemImage: "brain.head.profile")
                }

            privacySettings
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }

            aboutView
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
        .onAppear(perform: loadSettings)
    }

    // MARK: - General Settings

    private var generalSettings: some View {
        Form {
            Section("Screen Capture") {
                HStack {
                    Text("Capture interval:")
                    Spacer()
                    TextField("Seconds", value: $captureInterval, format: .number)
                        .frame(width: 60)
                        .onChange(of: captureInterval) { _, newValue in
                            saveCaptureInterval(newValue)
                        }
                    Text("seconds")
                }

                Toggle("Only capture on screen change", isOn: $onlyCaptureOnChange)
                    .onChange(of: onlyCaptureOnChange) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "only_capture_on_change")
                    }

                Toggle("Pause when screen is locked", isOn: $pauseWhenLocked)
                    .onChange(of: pauseWhenLocked) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "pause_when_locked")
                    }
            }

            Section("Performance") {
                HStack {
                    Text("Memory usage:")
                    Spacer()
                    Text(String(format: "%.1f MB", PerformanceMonitor.shared.memoryUsage))
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Captures/min:")
                    Spacer()
                    Text("\(PerformanceMonitor.shared.capturesPerMinute)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - AI Settings

    private var aiSettings: some View {
        Form {
            Section("AI Backend") {
                Picker("Backend:", selection: $selectedBackend) {
                    ForEach(AIBackend.allCases, id: \.self) { backend in
                        Text(backend.rawValue).tag(backend)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedBackend) { _, newValue in
                    aiService.setPreferredBackend(newValue)
                }

                if selectedBackend == .appleIntelligence {
                    if aiService.isAppleIntelligenceAvailable() {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Apple Intelligence is available")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    } else {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("Apple Intelligence requires macOS 26+")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                } else {
                    Text("Using cloud-based Gemini 2.5 Flash model")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if selectedBackend == .gemini {
                Section("Gemini API") {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    Text("Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Save API Key") {
                        aiService.setAPIKey(apiKey)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.isEmpty)

                    if aiService.hasAPIKey() {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API key configured")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Privacy Settings

    private var privacySettings: some View {
        Form {
            Section("Excluded Apps") {
                Text("Apps to exclude from screen capture:")
                    .font(.headline)

                TextEditor(text: $excludedApps)
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3))

                Text("One app name per line (e.g., '1Password')")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Data Management") {
                HStack {
                    Button("View Database Location") {
                        showInFinder()
                    }

                    Spacer()

                    Button("Clear All Data") {
                        clearData()
                    }
                    .foregroundColor(.red)
                }
            }

            Section("Permissions") {
                Button("Open Screen Recording Settings") {
                    PrivacyManager.shared.openScreenRecordingSettings()
                }
            }
        }
        .padding()
    }

    // MARK: - About

    private var aboutView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("LifeLog")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .foregroundColor(.secondary)

            Text("A personal memory augmentation system")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Divider()
                .padding(.horizontal, 60)

            VStack(spacing: 8) {
                Text("Built with:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    Label("ScreenCaptureKit", systemImage: "camera")
                    Label("Vision OCR", systemImage: "doc.text")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    Label("Apple Intelligence", systemImage: "brain.head.profile")
                    Label("Gemini AI", systemImage: "brain")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Actions

    private func loadSettings() {
        // Load API key
        if let savedKey = UserDefaults.standard.string(forKey: "gemini_api_key") {
            apiKey = savedKey
        }

        // Load capture settings
        captureInterval = UserDefaults.standard.double(forKey: "capture_interval")
        if captureInterval == 0 {
            captureInterval = 10.0 // Default
        }

        onlyCaptureOnChange = UserDefaults.standard.bool(forKey: "only_capture_on_change")
        pauseWhenLocked = UserDefaults.standard.bool(forKey: "pause_when_locked")

        // Load AI backend preference
        selectedBackend = aiService.preferredBackend
    }

    private func saveCaptureInterval(_ interval: Double) {
        UserDefaults.standard.set(interval, forKey: "capture_interval")
        // TODO: Update ScreenCaptureService configuration
    }

    private func showInFinder() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let appDir = appSupport.appendingPathComponent("LifeLog")

        NSWorkspace.shared.open(appDir)
    }

    private func clearData() {
        let alert = NSAlert()
        alert.messageText = "Clear All Data?"
        alert.informativeText = "This will permanently delete all captured data. This cannot be undone."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete")
        alert.alertStyle = .critical

        if alert.runModal() == .alertSecondButtonReturn {
            // TODO: Implement data clearing
        }
    }
}

#Preview {
    SettingsView()
}
