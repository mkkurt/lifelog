# Building LifeLog - Complete Setup Guide

## Initial Xcode Project Setup

Since the Xcode project file needs to reference all source files, here's how to properly set it up:

### Option 1: Rebuild Project in Xcode (Recommended)

1. **Create New Project**:
   ```
   - Open Xcode
   - File → New → Project
   - macOS → App
   - Product Name: LifeLog
   - Interface: SwiftUI
   - Language: Swift
   - Uncheck "Use Core Data", "Include Tests"
   - Save in: /Users/kutay/Projects/lifelog
   - Choose "Don't add to source control" (we have .gitignore)
   ```

2. **Delete Default Files**:
   - Delete the `LifeLog/LifeLog` group that Xcode created
   - Keep only `LifeLog.xcodeproj`

3. **Add Source Files**:
   - Right-click project root in navigator
   - Add Files to "LifeLog"...
   - Select the `LifeLog` folder
   - Check "Create groups"
   - Check "Copy items if needed" (unchecked, files are already there)
   - Click Add

4. **Configure Build Settings**:
   - Select project in navigator
   - Select "LifeLog" target
   - General tab:
     - Deployment Target: macOS 14.0
     - Bundle Identifier: com.lifelog.LifeLog

5. **Set App as Menu Bar Only**:
   - Select target → Info tab
   - Add new key: "Application is agent (UIElement)" = YES
   - Or set `LSUIElement` = `YES` in Info.plist

6. **Configure Entitlements**:
   - Signing & Capabilities tab
   - Click "+ Capability"
   - Add "App Sandbox"
   - Under App Sandbox:
     - Check "Incoming Connections (Server)"
     - Uncheck most restrictions or set as needed
   - The LifeLog.entitlements file should be automatically created/updated

7. **Build and Run**:
   - Press Cmd+B to build
   - Press Cmd+R to run

### Option 2: Use Existing Project Structure

The project already has the correct file structure. You just need to ensure the `.xcodeproj` references all files:

1. Open `LifeLog.xcodeproj` in Xcode
2. If files appear red (missing references):
   - Right-click each missing file
   - Delete reference (don't move to trash)
   - Add files back using Add Files to "LifeLog"...

## Build Configuration

### Required Frameworks

The following frameworks are needed (should be auto-linked):
- SwiftUI.framework
- AppKit.framework
- ScreenCaptureKit.framework (macOS 12.3+)
- Vision.framework
- SQLite3.framework (built-in)
- CryptoKit.framework

### Compiler Flags

No special compiler flags needed, but ensure:
- Swift Language Version: Swift 5
- Build Active Architecture Only: Yes (for Debug)

### Deployment Target

- Minimum: macOS 14.0 (for ScreenCaptureKit)
- Recommended: macOS 14.0+

## Project Settings Reference

### Info.plist Additions

```xml
<key>LSUIElement</key>
<true/>
<key>NSScreenCaptureUsageDescription</key>
<string>LifeLog needs screen recording permission to capture and analyze your screen content.</string>
```

### Entitlements

Ensure `LifeLog.entitlements` contains:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
</plist>
```

## Troubleshooting Build Issues

### "Cannot find 'ScreenCaptureKit' in scope"

- Ensure deployment target is macOS 12.3 or later
- Check Build Settings → Frameworks, Libraries, and Embedded Content
- ScreenCaptureKit should be auto-linked, but add manually if needed

### "Missing required module 'sqlite3'"

- SQLite3 is built into macOS
- In Build Settings, search for "Header Search Paths"
- Add: `$(SDKROOT)/usr/include/sqlite3`
- In "Other Linker Flags", add: `-lsqlite3`

### Files appearing red in Xcode

- Right-click file → Show in Finder
- If file exists, use "Resolve" or delete reference and re-add
- If file doesn't exist, check the source file was created correctly

### "No such module 'Vision'"

- Vision is available on macOS 10.13+
- Ensure deployment target is set correctly
- Clean build folder: Product → Clean Build Folder

### Build succeeds but app doesn't run

- Check Console.app for crash logs
- Ensure Info.plist has LSUIElement = YES
- Verify entitlements are correctly set

## Xcode Project File Structure

After setup, your project should look like:

```
LifeLog.xcodeproj/
├── project.pbxproj           # Main project file
└── xcshareddata/
    └── xcschemes/
        └── LifeLog.xcscheme  # Build scheme

LifeLog/
├── App/
│   └── LifeLogApp.swift
├── Models/
│   ├── Capture.swift
│   ├── Summary.swift
│   └── TextEntry.swift
├── Services/
│   ├── AI/
│   ├── OCR/
│   ├── Privacy/
│   ├── ScreenCapture/
│   └── Storage/
├── UI/
│   ├── MenuBar/
│   ├── Query/
│   └── Settings/
├── Utils/
│   ├── Logger.swift
│   └── PerformanceMonitor.swift
├── Assets.xcassets/
│   └── AppIcon.appiconset/
└── LifeLog.entitlements
```

## Next Steps After Successful Build

1. Run the app
2. Grant Screen Recording permission
3. Configure Gemini API key
4. Start capturing!

See [QUICKSTART.md](QUICKSTART.md) for usage instructions.

## Advanced Build Options

### Release Build

```bash
xcodebuild -project LifeLog.xcodeproj \
  -scheme LifeLog \
  -configuration Release \
  -derivedDataPath build \
  build
```

### Archive for Distribution

```bash
xcodebuild -project LifeLog.xcodeproj \
  -scheme LifeLog \
  -configuration Release \
  -archivePath build/LifeLog.xcarchive \
  archive
```

### Code Signing

For distribution, you'll need:
- Apple Developer account
- Developer ID Application certificate
- Provisioning profile

Configure in Xcode:
- Target → Signing & Capabilities
- Team: Select your team
- Signing Certificate: Developer ID Application

## Performance Build Optimizations

For maximum performance, in Build Settings:

- Optimization Level: `-O` (Release) or `-Osize` for smaller binary
- Swift Compilation Mode: Whole Module
- Enable Bitcode: No (macOS doesn't use bitcode)
- Strip Debug Symbols: Yes (Release only)
- Dead Code Stripping: Yes

## Questions?

If you encounter build issues:
1. Check Console.app for detailed error messages
2. Review this guide carefully
3. Ensure all prerequisites are met (macOS 14.0+, Xcode 15.0+)
4. Try cleaning build folder and rebuilding
