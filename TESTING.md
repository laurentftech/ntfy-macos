# Testing ntfy-macos App Bundle

## What We Built

We've created a complete ntfy-macos application with proper macOS app bundle structure to enable UNUserNotificationCenter to work correctly.

## App Bundle Structure

```
ntfy-macos.app/
├── Contents/
    ├── Info.plist          # App metadata
    └── MacOS/
        └── ntfy-macos      # Executable
```

## Building

The project now includes NSApplication initialization which allows the native notification system to work:

```bash
# Build release version
swift build -c release

# Create app bundle
mkdir -p .build/release/ntfy-macos.app/Contents/MacOS
cp .build/release/ntfy-macos .build/release/ntfy-macos.app/Contents/MacOS/
cp Resources/Info.plist .build/release/ntfy-macos.app/Contents/
```

Or use the build script:

```bash
chmod +x build-app.sh
./build-app.sh
```

## Manual Testing

### 1. Test Help Command

```bash
.build/release/ntfy-macos.app/Contents/MacOS/ntfy-macos help
```

Expected output:
```
ntfy-macos - Native macOS CLI Notifier & Automation Agent
...
```

### 2. Initialize Configuration

```bash
.build/release/ntfy-macos.app/Contents/MacOS/ntfy-macos init
```

This creates `~/.config/ntfy-macos/config.yml`.

### 3. Edit Configuration

```bash
nano ~/.config/ntfy-macos/config.yml
```

Minimal config:
```yaml
server: https://ntfy.sh
topics:
  - name: your-test-topic
    icon_symbol: bell.fill
```

### 4. Test Serve (IMPORTANT - This is the key test!)

Open a terminal and run:

```bash
.build/release/ntfy-macos.app/Contents/MacOS/ntfy-macos serve
```

You should see:
```
Starting ntfy-macos service...
Configured topics: your-test-topic
Connecting to ntfy: https://ntfy.sh/your-test-topic/json
Connected successfully
```

**If it runs without crashing, the app bundle approach worked!**

### 5. Send Test Notification

In another terminal, while serve is running:

```bash
curl -d "Hello from ntfy-macos!" https://ntfy.sh/your-test-topic
```

You should see:
1. Console output: "Received message on topic..."
2. **macOS notification banner** with the message
3. Bell icon (if configured)

### 6. Test Permission Dialog

The first time you run serve or test-notify, macOS will ask for notification permissions. Click "Allow".

### 7. Test with Priority

```bash
# Critical notification (bypasses Focus mode)
curl -H "Priority: 5" -d "CRITICAL ALERT!" https://ntfy.sh/your-test-topic

# Time-sensitive notification
curl -H "Priority: 4" -d "Important update" https://ntfy.sh/your-test-topic
```

### 8. Test with Title

```bash
curl -H "Title: Deployment Complete" -d "Version 2.0 deployed successfully" https://ntfy.sh/your-test-topic
```

## Installation

To install system-wide:

```bash
# Copy app bundle to Applications
sudo cp -r .build/release/ntfy-macos.app /Applications/

# Create symlink for CLI access
sudo ln -sf /Applications/ntfy-macos.app/Contents/MacOS/ntfy-macos /usr/local/bin/ntfy-macos

# Now you can use it from anywhere
ntfy-macos serve
```

## Running as LaunchAgent

Create `~/Library/LaunchAgents/com.ntfy-macos.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ntfy-macos</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/ntfy-macos.app/Contents/MacOS/ntfy-macos</string>
        <string>serve</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ntfy-macos.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ntfy-macos-error.log</string>
</dict>
</plist>
```

Load the agent:

```bash
launchctl load ~/Library/LaunchAgents/com.ntfy-macos.plist
```

## Troubleshooting

### No Notifications Appearing

1. Check System Settings → Notifications → ntfy-macos
2. Ensure "Allow Notifications" is enabled
3. Try test-notify command:
   ```bash
   .build/release/ntfy-macos.app/Contents/MacOS/ntfy-macos test-notify --topic test
   ```

### Permission Denied

The executable must be run from within the app bundle structure, not standalone.

❌ Wrong:
```bash
.build/release/ntfy-macos serve  # This will crash!
```

✅ Correct:
```bash
.build/release/ntfy-macos.app/Contents/MacOS/ntfy-macos serve
```

### Still Crashing

If serve still crashes, check:
1. App bundle structure is correct (`Info.plist` present)
2. Running from app bundle path (not standalone executable)
3. macOS version is 13.0+
4. Try `codesign` if on newer macOS:
   ```bash
   codesign -s - -f --deep .build/release/ntfy-macos.app
   ```

## Next Steps

Once testing is successful:
1. Update Homebrew formula to create app bundle
2. Update README with app bundle instructions
3. Create release with signed app bundle
4. Test on fresh macOS installation

## Key Changes Made

1. Added `NSApplication` initialization in main.swift
2. Set activation policy to `.accessory` (no dock icon)
3. Created proper Info.plist with bundle identifier
4. Built app bundle structure instead of standalone executable

The combination of these changes allows `UNUserNotificationCenter.current()` to work without crashing.
