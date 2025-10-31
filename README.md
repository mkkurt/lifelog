# LifeLog

> A personal memory augmentation system that captures, indexes, and makes searchable everything you see and do on your Mac.

## Vision

LifeLog solves the problem: **"I can't remember what was on my mind, what I was going to do, what email I was going to write, what I was tinkering with."**

This application continuously records your screen, performs OCR, and uses AI to help you remember and search through your digital life.

## Features

### Core Capabilities
- **Continuous Screen Capture**: Smart interval-based screen recording with change detection
- **Intelligent OCR**: High-performance text recognition using Apple's Vision framework
- **Full-Text Search**: Lightning-fast search with SQLite FTS5 indexing
- **AI-Powered Queries**: Natural language search using Gemini AI
- **Privacy-First**: All data stored locally, with sensitive content filtering
- **High Performance**: Optimized for minimal CPU and memory usage (<5% CPU target)

### Technical Highlights
- Built with SwiftUI and modern macOS APIs
- ScreenCaptureKit for efficient screen recording
- Vision framework for accurate OCR
- SQLite with FTS5 for instant search
- Gemini AI integration for intelligent queries
- Menu bar app (no Dock icon)
- Comprehensive privacy controls

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Menu Bar UI                             │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                   Application Core                           │
└─────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│   Screen     │ │     OCR      │ │      AI      │ │   Storage    │
│   Capture    │ │   Service    │ │   Service    │ │    Layer     │
└──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed technical documentation.

## Requirements

- macOS 14.0 or later (for ScreenCaptureKit)
- Xcode 15.0 or later
- Swift 5.9 or later
- Screen Recording permission
- Gemini API key (get one at [Google AI Studio](https://makersuite.google.com/app/apikey))

## Building and Running

### Using Xcode

1. Open `LifeLog.xcodeproj` in Xcode
2. Build the project (`Cmd+B`)
3. Run the app (`Cmd+R`)
4. Grant Screen Recording permission when prompted
5. Enter your Gemini API key in Settings

### Using Command Line

```bash
# Build
xcodebuild -project LifeLog.xcodeproj -scheme LifeLog -configuration Debug build

# Run
open build/Debug/LifeLog.app
```

## Setup

### 1. Grant Permissions

On first launch, you'll be prompted to grant Screen Recording permission:
- System Preferences → Privacy & Security → Screen Recording
- Enable LifeLog
- Restart the app

### 2. Configure Gemini API

1. Get a free API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Open LifeLog Settings (gear icon)
3. Navigate to AI tab
4. Paste your API key and save

### 3. Start Recording

Click the menu bar icon and press "Start" to begin capturing your screen.

## Usage

### Menu Bar Controls

- **Left Click**: Open main panel
- **Right Click**: Quick menu with options
- **Recording Indicator**: Red dot shows active recording

### Natural Language Queries

Click "Ask LifeLog a Question" and try queries like:

- "What was I working on this morning?"
- "What email was I going to write?"
- "What command did I run earlier?"
- "Show me what I was doing around 2pm"
- "What websites did I visit yesterday?"

### Settings

Configure:
- Capture interval (default: 10 seconds)
- Excluded apps (password managers, etc.)
- Privacy controls
- Data management

## Project Structure

```
LifeLog/
├── App/
│   └── LifeLogApp.swift              # App entry point
├── Models/
│   ├── Capture.swift                 # Capture data model
│   ├── TextEntry.swift               # OCR text entry model
│   └── Summary.swift                 # AI summary model
├── Services/
│   ├── ScreenCapture/
│   │   ├── ScreenCaptureService.swift       # Screen recording
│   │   └── ScreenCaptureConfiguration.swift  # Capture config
│   ├── OCR/
│   │   └── OCRService.swift          # Vision OCR processing
│   ├── Storage/
│   │   └── StorageService.swift      # SQLite + FTS5 storage
│   ├── AI/
│   │   ├── AIService.swift           # AI query processing
│   │   └── GeminiClient.swift        # Gemini API client
│   └── Privacy/
│       └── PrivacyManager.swift      # Privacy & permissions
├── UI/
│   ├── MenuBar/
│   │   ├── MenuBarController.swift   # Menu bar logic
│   │   └── MenuBarView.swift         # Main UI
│   ├── Query/
│   │   └── QueryView.swift           # Query interface
│   └── Settings/
│       └── SettingsView.swift        # Settings panel
└── Utils/
    ├── Logger.swift                   # Logging system
    └── PerformanceMonitor.swift       # Performance metrics
```

## Privacy & Security

### Data Storage

All data is stored locally on your Mac:
- Database: `~/Library/Application Support/LifeLog/lifelog.db`
- No cloud sync (by default)
- No telemetry or analytics

### Privacy Features

- **App Exclusions**: Automatically excludes password managers
- **Sensitive Content Filtering**: Detects and filters passwords, credit cards
- **User Control**: Configure excluded apps and capture behavior
- **Local Processing**: OCR runs entirely on-device
- **Secure Storage**: SQLite database with optional encryption

### Sensitive Apps (Auto-Excluded)

- 1Password
- LastPass
- Bitwarden
- Keychain Access

You can add more in Settings.

## Performance

### Target Metrics

- CPU Usage: <5% average
- Memory Usage: <200MB
- Capture Rate: ~6 per minute (configurable)
- OCR Processing: <1s per capture
- Search Response: <100ms

### Optimization Strategies

- Smart change detection (skip identical frames)
- Async OCR processing
- Efficient SQLite indexing
- Lazy loading of historical data
- Background processing with low QoS

## Development Roadmap

### Phase 1: Core Foundation ✅
- [x] Screen capture service
- [x] OCR integration
- [x] SQLite storage
- [x] Basic UI

### Phase 2: Intelligence ✅
- [x] Gemini AI integration
- [x] Natural language queries
- [x] Basic summarization

### Phase 3: Polish (In Progress)
- [ ] Performance optimization
- [ ] Advanced privacy controls
- [ ] Enhanced UI/UX
- [ ] Export/import features
- [ ] Keyboard shortcuts

### Phase 4: Advanced Features (Future)
- [ ] Apple Intelligence integration
- [ ] Proactive suggestions
- [ ] Timeline visualization
- [ ] Context restoration
- [ ] Workflow automation
- [ ] Plugin system

## Troubleshooting

### Screen Recording Permission Denied

1. Open System Preferences → Privacy & Security → Screen Recording
2. Unlock settings (click lock icon)
3. Enable LifeLog
4. Restart the app

### OCR Not Working

- Ensure capture is running (check menu bar icon)
- Check Console.app for error logs
- Verify Vision framework is available (macOS 14+)

### Slow Performance

- Increase capture interval in Settings
- Reduce number of excluded apps
- Check Performance Monitor in main panel
- Close other resource-intensive apps

### Gemini API Errors

- Verify API key is correct
- Check internet connection
- Ensure you haven't exceeded rate limits
- Try generating a new API key

## FAQ

**Q: How much disk space does it use?**
A: Approximately 1-5MB per hour of active use (text only, no images stored)

**Q: Can I use it offline?**
A: Screen capture and OCR work offline. AI queries require internet for Gemini API.

**Q: Is my data private?**
A: Yes, all data stays on your Mac. Only AI queries are sent to Gemini (with context).

**Q: Can I export my data?**
A: The database is standard SQLite format. Export features coming in Phase 3.

**Q: Does it work on multiple displays?**
A: Currently captures primary display. Multi-display support planned.

## Contributing

This is a personal project, but suggestions and ideas are welcome!

## License

Private/Proprietary - Not for distribution

## Acknowledgments

Built with:
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit) - macOS screen recording
- [Vision Framework](https://developer.apple.com/documentation/vision) - Apple's OCR
- [Gemini AI](https://ai.google.dev/) - Google's AI model
- [SQLite](https://www.sqlite.org/) - Database engine

---

**Note**: This is a powerful tool that records everything on your screen. Use responsibly and be mindful of privacy when screen sharing or recording sensitive information.
