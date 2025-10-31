# LifeLog Quick Start Guide

## Prerequisites

1. **macOS 14.0+** (Sonoma or later)
2. **Xcode 15.0+**
3. **Gemini API Key** - Get it free at https://makersuite.google.com/app/apikey

## Build & Run (5 minutes)

### Step 1: Open in Xcode

```bash
cd /path/to/lifelog
open LifeLog.xcodeproj
```

### Step 2: Build the Project

Press `Cmd+B` or click Product → Build

**Note**: First build may take 1-2 minutes as Xcode processes all source files.

### Step 3: Run the App

Press `Cmd+R` or click Product → Run

The app will launch and appear in your menu bar (top right, look for the record icon).

### Step 4: Grant Screen Recording Permission

1. A dialog will appear requesting Screen Recording permission
2. Click "Open System Preferences"
3. In Privacy & Security → Screen Recording, enable LifeLog
4. **Restart the app** (Quit and run again)

### Step 5: Configure Gemini API

1. Click the menu bar icon
2. Click the gear (⚙️) icon for Settings
3. Go to the "AI" tab
4. Paste your Gemini API key
5. Click "Save API Key"

### Step 6: Start Recording

1. Click the menu bar icon
2. Click "Start" button
3. You'll see a red blinking dot indicating recording is active

## First Query

After a few minutes of use:

1. Click menu bar icon
2. Click "Ask LifeLog a Question"
3. Try: "What have I been working on?"

## Troubleshooting

### "Failed to build" error

- Make sure you're using Xcode 15.0+
- Check macOS version is 14.0+
- Clean build folder: Product → Clean Build Folder

### App doesn't appear in menu bar

- Check Activity Monitor - is LifeLog running?
- Look far right in menu bar (it may be hidden)
- Try quitting and relaunching

### Screen Recording permission not working

1. System Preferences → Privacy & Security → Screen Recording
2. Remove LifeLog from list if present
3. Re-add by clicking the + button
4. Fully quit and restart LifeLog

### Gemini API errors

- Verify API key is correct (no extra spaces)
- Check you have internet connection
- Ensure you haven't exceeded free tier limits

## Next Steps

- Read [README.md](README.md) for full documentation
- Review [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
- Customize excluded apps in Settings → Privacy
- Adjust capture interval in Settings → General

## Quick Tips

- **Right-click menu bar icon** for quick actions
- **Cmd+Q** won't work - use "Quit" from menu or close button
- Check **Performance Monitor** in main panel to verify efficiency
- Data stored in: `~/Library/Application Support/LifeLog/`

## Common Use Cases

### "What was that email I wanted to write?"

1. Open query interface
2. Ask: "What email content did I see today?"
3. LifeLog will search your screen captures

### "What command did I run?"

Ask: "What terminal commands did I use this morning?"

### "Restore my context after interruption"

Ask: "What was I working on before the meeting?"

---

**Ready to use!** LifeLog is now capturing your screen and ready to answer questions about your digital life.
