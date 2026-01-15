# Quick Start Guide

Get ntfy-macos up and running in 5 minutes.

## Prerequisites

- macOS 13.0 (Ventura) or later
- Basic terminal knowledge

## Installation

### Option 1: Build from Source (Current Setup)

```bash
# You're already in the project directory
swift build -c release

# Copy to your PATH
sudo cp .build/release/ntfy-macos /usr/local/bin/
```

### Option 2: Homebrew (Future)

```bash
brew install ntfy-macos
```

## Setup

### 1. Create Configuration

```bash
ntfy-macos init
```

This creates `~/.config/ntfy-macos/config.yml` with sample configuration.

### 2. Edit Configuration

Open the config file:

```bash
nano ~/.config/ntfy-macos/config.yml
```

Minimal configuration:

```yaml
server: https://ntfy.sh

topics:
  - name: mytopic
    icon_symbol: bell.fill
```

Save and exit (Ctrl+X, Y, Enter).

### 3. Test Notifications

Test that notifications work:

```bash
ntfy-macos test-notify --topic mytopic
```

You should see a notification appear!

If you don't see a notification:
- Go to System Settings → Notifications
- Find "ntfy-macos" and ensure it's enabled

### 4. Start the Service

```bash
ntfy-macos serve
```

You should see:
```
Starting ntfy-macos service...
Configured topics: mytopic
Connecting to ntfy: https://ntfy.sh/mytopic/json
Connected successfully
```

### 5. Send a Test Message

Open a new terminal and send a message:

```bash
curl -d "Hello from ntfy!" https://ntfy.sh/mytopic
```

You should see a notification with your message!

## Next Steps

### Add Multiple Topics

Edit your config:

```yaml
server: https://ntfy.sh

topics:
  - name: alerts
    icon_symbol: exclamationmark.triangle.fill

  - name: deployments
    icon_symbol: arrow.up.circle.fill

  - name: monitoring
    icon_symbol: server.rack
```

Restart the service (Ctrl+C, then `ntfy-macos serve`).

### Add Authentication (Optional)

If your ntfy server requires authentication:

```bash
ntfy-macos auth --server https://ntfy.sh --token tk_yourtoken
```

The token is stored securely in your macOS Keychain.

### Add Interactive Actions

Edit your config to add buttons:

```yaml
topics:
  - name: alerts
    icon_symbol: bell.fill
    actions:
      - title: Acknowledge
        type: script
        path: /usr/local/bin/ack-alert.sh
      - title: View Logs
        type: script
        path: /usr/local/bin/view-logs.sh
```

Create a sample script:

```bash
cat > /usr/local/bin/ack-alert.sh << 'EOF'
#!/bin/bash
echo "Alert acknowledged: $1"
osascript -e 'display notification "Alert acknowledged" with title "ntfy-macos"'
EOF

chmod +x /usr/local/bin/ack-alert.sh
```

### Add Auto-Run Scripts

For automatic actions when messages arrive:

```yaml
topics:
  - name: deployments
    icon_symbol: arrow.up.circle.fill
    auto_run_script: /usr/local/bin/deploy-handler.sh
```

Create the handler:

```bash
cat > /usr/local/bin/deploy-handler.sh << 'EOF'
#!/bin/bash
MESSAGE="$1"
echo "[$(date)] Deployment notification: $MESSAGE" >> ~/deploy.log
EOF

chmod +x /usr/local/bin/deploy-handler.sh
```

### Silent Background Processing

For automation without notification banners:

```yaml
topics:
  - name: background
    silent: true
    auto_run_script: /usr/local/bin/background-handler.sh
```

### Run as Background Service

#### Option A: Using Homebrew Services (Future)

```bash
brew services start ntfy-macos
```

#### Option B: Manual LaunchAgent

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
        <string>/usr/local/bin/ntfy-macos</string>
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

Load the service:

```bash
launchctl load ~/Library/LaunchAgents/com.ntfy-macos.plist
```

Check if it's running:

```bash
launchctl list | grep ntfy-macos
```

Stop the service:

```bash
launchctl unload ~/Library/LaunchAgents/com.ntfy-macos.plist
```

## Common Issues

### "Permission Denied" Error

Make sure scripts are executable:

```bash
chmod +x /path/to/your/script.sh
```

### Notifications Not Showing

1. Check System Settings → Notifications
2. Ensure ntfy-macos has permission
3. Try the test command: `ntfy-macos test-notify --topic test`

### Can't Connect to Server

1. Check your internet connection
2. Verify the server URL in config
3. Test with curl: `curl https://ntfy.sh`
4. Check if authentication is required

### Script Not Running

1. Test the script manually: `/bin/sh /path/to/script.sh "test"`
2. Check script permissions
3. Review logs at `/tmp/ntfy-macos.log`

## Examples

### Example 1: Simple Alerts

```yaml
server: https://ntfy.sh
topics:
  - name: alerts
    icon_symbol: bell.fill
```

Send:
```bash
curl -d "Server is down!" https://ntfy.sh/alerts
```

### Example 2: Priority Levels

Send critical alert (bypasses Focus mode):

```bash
curl -H "Priority: 5" -d "CRITICAL: Database failure!" https://ntfy.sh/alerts
```

### Example 3: With Title

```bash
curl -H "Title: Deployment Complete" -d "Version 2.0 deployed successfully" https://ntfy.sh/deployments
```

### Example 4: Scheduled Messages

Add to crontab:

```bash
# Send daily backup notification at 2 AM
0 2 * * * curl -d "Daily backup starting" https://ntfy.sh/monitoring
```

## Getting Help

- [README.md](README.md) - Full feature documentation
- [DEVELOPMENT.md](DEVELOPMENT.md) - Development guide
- [PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md) - Architecture details
- [GitHub Issues](https://github.com/laurentftech/ntfy-macos/issues) - Report bugs

## What's Next?

1. Explore [SF Symbols](https://developer.apple.com/sf-symbols/) for more icons
2. Create custom automation scripts
3. Set up multiple topics for different use cases
4. Integrate with your CI/CD pipeline
5. Share your use cases with the community!

Enjoy using ntfy-macos! 🎉
