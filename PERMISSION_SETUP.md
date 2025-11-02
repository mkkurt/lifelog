# Screen Recording Permission Setup for Development

## The Problem

macOS tracks screen recording permissions by:
- **Bundle ID** (`com.lifelog.LifeLog`)
- **Code signature**
- **Binary location**

During development, each rebuild creates a new code signature, so macOS treats each build as a "different app" and asks for permission again.

## The Solution

The project now uses **ad-hoc code signing** with the `-` identity, which creates a stable signature based on the bundle identifier. This means:
- ✅ Permission persists across rebuilds
- ✅ No more repeated permission prompts during development
- ✅ The app appears consistently in System Settings

## Setup Instructions

### 1. Remove Old Permission Entries (One Time Only)

Before rebuilding, you need to remove the old permission entries from previous builds:

```bash
# Open System Settings
open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture"
```

Or manually:
1. Open **System Settings**
2. Go to **Privacy & Security** → **Screen Recording**
3. Look for multiple "LifeLog" entries
4. **Remove ALL of them** (click -, grant admin permission)
5. Close System Settings

### 2. Clean Build

```bash
cd /Users/kutay/Projects/lifelog
xcodebuild -project LifeLog.xcodeproj -scheme LifeLog -configuration Debug clean build
```

### 3. Run the App

```bash
# From Xcode: Product → Run (⌘R)
# Or from command line:
open build/Debug/LifeLog.app
```

### 4. Grant Permission (First Time)

1. Click the LifeLog menu bar icon
2. You'll see "Permission Required" screen
3. Click **"Grant Permission"**
4. System prompt will appear
5. Click **"Open System Settings"** in the prompt
6. In System Settings, toggle **LifeLog** to ON
7. Click **"Refresh Status"** in the app

### 5. Verify It Works

1. Check System Settings → Privacy & Security → Screen Recording
2. You should see **ONE** "LifeLog" entry that's enabled
3. Rebuild the app: `⌘R` in Xcode
4. The app should start **WITHOUT asking for permission again**
5. Check System Settings again - still just ONE entry

## Code Signing Settings

The project is now configured with:

```
CODE_SIGN_IDENTITY = "-"
CODE_SIGN_STYLE = Manual
```

This uses ad-hoc signing which:
- Creates a stable signature across rebuilds
- Doesn't require Apple Developer certificates
- Perfect for local development
- Won't work for App Store distribution (use proper signing for release)

## Troubleshooting

### App still asks for permission on every rebuild

**Symptom**: System Settings shows multiple "LifeLog" entries

**Solution**:
1. Quit the app completely
2. Remove ALL LifeLog entries from Screen Recording settings
3. Run: `xcodebuild clean`
4. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/LifeLog-*`
5. Rebuild and run
6. Grant permission once

### Permission toggle is grayed out

**Symptom**: Can't toggle LifeLog permission in System Settings

**Solution**:
1. Quit LifeLog
2. Remove the entry from Screen Recording settings
3. Rebuild and run
4. Grant permission through the app's "Grant Permission" button

### App doesn't appear in System Settings

**Symptom**: After granting permission, LifeLog doesn't show up in Screen Recording settings

**Solution**:
- This is normal for development builds initially
- Once you grant permission through the system prompt, it will appear
- The entry will persist across rebuilds

## For Production Release

When ready to distribute:

1. Create an Apple Developer account
2. Create a Developer ID certificate
3. Update project settings:
   ```
   CODE_SIGN_IDENTITY = "Developer ID Application: Your Name (TEAM_ID)"
   CODE_SIGN_STYLE = Automatic
   DEVELOPMENT_TEAM = "YOUR_TEAM_ID"
   ```
4. Notarize the app with Apple
5. Distribute

## Verification Commands

Check current app signature:
```bash
codesign -dv build/Debug/LifeLog.app
```

Check if app is running:
```bash
ps aux | grep LifeLog
```

Check permission status in database (requires Full Disk Access):
```bash
# This shows raw TCC database - macOS 13+
sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db \
  "SELECT service, client, auth_value FROM access WHERE service='kTCCServiceScreenCapture';"
```
