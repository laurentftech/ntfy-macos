# ntfy-macos

A native macOS CLI notifier and automation agent for [ntfy](https://ntfy.sh). Subscribe to ntfy topics and receive rich native notifications with SF Symbols, images, and interactive actions. Automatically execute shell scripts when notifications arrive.

## Features

- **Native macOS Notifications**: Rich notifications with SF Symbols and local images
- **Interactive Actions**: Add custom buttons to notifications that execute scripts
- **Automatic Script Execution**: Run shell scripts automatically when messages arrive
- **Silent Notifications**: Receive messages without displaying notification banners
- **Secure Authentication**: Store tokens securely in macOS Keychain
- **Robust Reconnection**: Handles network interruptions and sleep/wake gracefully
- **Priority Mapping**: Maps ntfy priority levels to macOS interruption levels (critical, time-sensitive)
- **Background Service**: Runs as a LaunchAgent for persistent operation

## Installation

### Using Homebrew (Coming Soon)

Once published to Homebrew, installation will be:

```bash
brew install ntfy-macos
brew services start ntfy-macos
```

For now, please build from source (see below).

### Build from Source

```bash
# Clone the repository
git clone https://github.com/laurentftech/ntfy-macos.git
cd ntfy-macos

# Build
swift build -c release

# Install
sudo cp .build/release/ntfy-macos /usr/local/bin/
```

## Quick Start

1. **Initialize Configuration**

```bash
ntfy-macos init
```

This creates a sample configuration at `~/.config/ntfy-macos/config.yml`.

2. **Edit Configuration**

Edit the configuration file to add your server and topics:

```yaml
server: https://ntfy.sh

topics:
  - name: alerts
    icon_symbol: bell.fill
    actions:
      - title: Acknowledge
        type: script
        path: /usr/local/bin/ack-alert.sh
```

3. **(Optional) Store Authentication Token**

```bash
ntfy-macos auth --server https://ntfy.sh --token tk_yourtoken
```

4. **Start the Service**

```bash
ntfy-macos serve
```

Or use Homebrew services for automatic startup:

```bash
brew services start ntfy-macos
```

## Configuration

The configuration file is located at `~/.config/ntfy-macos/config.yml`:

```yaml
# Server URL (required)
server: https://ntfy.sh

# Authentication token (optional - can be stored in Keychain instead)
token: tk_yourtoken

# Topics to subscribe to
topics:
  - name: alerts
    # SF Symbol icon (optional)
    icon_symbol: bell.fill
    # Actions appear as buttons in the notification
    actions:
      - title: Acknowledge
        type: script
        path: /usr/local/bin/ack-alert.sh
      - title: View Logs
        type: script
        path: /usr/local/bin/view-logs.sh

  - name: deployments
    # Local image file (optional)
    icon_path: /Users/you/icons/deploy.png
    # Script runs automatically when notification arrives
    auto_run_script: /usr/local/bin/deploy-handler.sh
    # Show notification banner
    silent: false

  - name: monitoring
    icon_symbol: server.rack
    # Silent mode - no notification banner, just runs the script
    silent: true
    auto_run_script: /usr/local/bin/monitor-handler.sh
```

### Configuration Options

#### Topic Fields

- `name` (required): Topic name to subscribe to
- `icon_symbol` (optional): SF Symbol name (e.g., `bell.fill`, `server.rack`)
- `icon_path` (optional): Absolute path to local image file (.png, .jpg)
- `auto_run_script` (optional): Script to execute automatically when message arrives
- `silent` (optional): If `true`, skip notification banner (useful for background automation)
- `actions` (optional): List of interactive buttons

#### Action Fields

- `title` (required): Button label
- `type` (required): Currently only `script` is supported
- `path` (required): Absolute path to script file

## CLI Commands

### serve

Start the notification service:

```bash
ntfy-macos serve [--config PATH]
```

Options:
- `--config PATH`: Use custom configuration file path

### auth

Store authentication token in Keychain:

```bash
ntfy-macos auth --server <URL> --token <TOKEN>
```

The Keychain token takes priority over the token in the YAML configuration.

### test-notify

Send a test notification:

```bash
ntfy-macos test-notify --topic <NAME>
```

### init

Create a sample configuration file:

```bash
ntfy-macos init [--path PATH]
```

### help

Display help information:

```bash
ntfy-macos help
```

## Script Execution

Scripts receive the message body as the first argument (`$1`):

```bash
#!/bin/bash
MESSAGE="$1"
echo "Received: $MESSAGE"
# Your automation logic here
```

### Environment

Scripts are executed with an enhanced PATH:
```
/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

This ensures Homebrew-installed tools are available.

### Make Scripts Executable

```bash
chmod +x /path/to/your/script.sh
```

## Priority Mapping

ntfy priority levels map to macOS interruption levels:

- Priority 5 → Critical (bypasses Focus modes)
- Priority 4 → Time Sensitive (prominently displayed)
- Priority 1-3 → Active (normal notifications)

## SF Symbols

You can use any SF Symbol name for icons. Common examples:

- `bell.fill` - Bell icon
- `server.rack` - Server icon
- `exclamationmark.triangle.fill` - Warning icon
- `checkmark.circle.fill` - Success icon
- `envelope.fill` - Mail icon
- `gear` - Settings icon

Browse all symbols using the SF Symbols app (free from Apple).

## Background Service

### Using Homebrew Services

```bash
# Start service
brew services start ntfy-macos

# Stop service
brew services stop ntfy-macos

# Restart service
brew services restart ntfy-macos

# View status
brew services info ntfy-macos
```

### Manual LaunchAgent Setup

The service plist is automatically generated by Homebrew. Logs are written to:

- stdout: `/opt/homebrew/var/log/ntfy-macos/stdout.log`
- stderr: `/opt/homebrew/var/log/ntfy-macos/stderr.log`

## Troubleshooting

### Notifications Not Appearing

1. Check notification permissions:
   - System Settings → Notifications → ntfy-macos
   - Ensure notifications are enabled

2. Test notifications:
   ```bash
   ntfy-macos test-notify --topic test
   ```

### Connection Issues

- Verify server URL in configuration
- Check authentication token
- Review logs for error messages

### Script Not Executing

1. Verify script is executable:
   ```bash
   chmod +x /path/to/script.sh
   ```

2. Test script manually:
   ```bash
   /bin/sh /path/to/script.sh "test message"
   ```

3. Check script output in service logs

## Examples

### Deployment Notifications

```yaml
topics:
  - name: deployments
    icon_symbol: arrow.up.circle.fill
    actions:
      - title: View Status
        type: script
        path: /usr/local/bin/check-deploy.sh
      - title: Rollback
        type: script
        path: /usr/local/bin/rollback.sh
```

### Server Monitoring

```yaml
topics:
  - name: server-alerts
    icon_symbol: exclamationmark.triangle.fill
    auto_run_script: /usr/local/bin/alert-handler.sh
    actions:
      - title: SSH to Server
        type: script
        path: /usr/local/bin/ssh-connect.sh
```

### Silent Background Processing

```yaml
topics:
  - name: background-jobs
    silent: true
    auto_run_script: /usr/local/bin/process-job.sh
```

## Architecture

- **Swift 6**: Modern Swift with strict concurrency
- **URLSession**: Native streaming JSON support
- **UserNotifications**: Rich macOS notifications
- **Security Framework**: Keychain integration
- **Yams**: YAML parsing
- **Foundation & AppKit**: Core macOS frameworks

## Contributing

Contributions are welcome! Please open issues or pull requests on GitHub.

## License

Apache License 2.0

## Related Projects

- [ntfy](https://ntfy.sh) - Simple pub-sub notification service
- [ntfy-android](https://github.com/binwiederhier/ntfy-android) - Official Android app
- [ntfy-ios](https://github.com/binwiederhier/ntfy-ios) - Official iOS app

## Support

For bugs and feature requests, please open an issue on GitHub.
