# ntfy-macos

Receive push notifications on your Mac from any source — servers, IoT devices, home automation, CI pipelines, or custom scripts. No account required, works with the public [ntfy.sh](https://ntfy.sh) service or your own self-hosted server.

**ntfy-macos** is a native macOS client that subscribes to ntfy topics and delivers rich notifications with SF Symbols, images, and interactive buttons. Trigger shell scripts automatically when messages arrive.

## Features

- **Native macOS Notifications**: Rich notifications with SF Symbols and local images
- **Multi-Server Support**: Connect to multiple ntfy servers simultaneously
- **Emoji Tags**: Automatic conversion of ntfy tags to emojis in notification titles
- **Interactive Actions**: Add custom buttons to notifications that execute scripts or open URLs
- **Automatic Script Execution**: Run shell scripts automatically when messages arrive
- **Silent Notifications**: Receive messages without displaying notification banners
- **Secure Authentication**: Store tokens securely in macOS Keychain
- **Robust Reconnection**: Handles network interruptions and sleep/wake gracefully
- **Priority Mapping**: Maps ntfy priority levels to macOS interruption levels (critical, time-sensitive)
- **Menu Bar App**: Runs in the menu bar with quick access to config and reload
- **Live Config Reload**: Configuration changes are detected and applied automatically

## Installation

### Using Homebrew

```bash
# Add the tap
brew tap laurentftech/ntfy-macos

# Install
brew install ntfy-macos
```

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

### Updating

```bash
# Update via Homebrew
brew update && brew upgrade ntfy-macos

# Restart the service to apply the update
brew services restart ntfy-macos
```

## Quick Start

1. **Initialize Configuration**

```bash
ntfy-macos init
```

This creates a sample configuration at `~/.config/ntfy-macos/config.yml`.

2. **Edit Configuration**

Edit the configuration file to add your servers and topics:

```yaml
servers:
  - url: https://ntfy.sh
    topics:
      - name: alerts
        icon_symbol: bell.fill
        actions:
          - title: Acknowledge
            type: script
            path: /usr/local/bin/ack-alert.sh

  - url: https://your-private-server.com
    token: tk_yourtoken
    topics:
      - name: deployments
        icon_path: /Users/you/icons/deploy.png
```

3. **(Optional) Store Authentication Token in Keychain**

```bash
ntfy-macos auth add https://ntfy.sh tk_yourtoken
```

4. **Start the Service**

Simply double-click the app or run:

```bash
ntfy-macos serve
```

The app runs in the menu bar with options to edit config, reload, and quit.

## Configuration

The configuration file is located at `~/.config/ntfy-macos/config.yml`:

```yaml
servers:
  # Public ntfy.sh server
  - url: https://ntfy.sh
    # token: tk_optional  # Can also use Keychain
    topics:
      - name: alerts
        icon_symbol: bell.fill
        actions:
          - title: Acknowledge
            type: script
            path: /usr/local/bin/ack-alert.sh
          - title: Open Dashboard
            type: view
            url: "https://dashboard.example.com"

      - name: deployments
        icon_path: /Users/you/icons/deploy.png
        auto_run_script: /usr/local/bin/deploy-handler.sh

  # Private server
  - url: https://your-private-server.com
    token: tk_yourtoken
    topics:
      - name: monitoring
        icon_symbol: server.rack
        silent: true
        auto_run_script: /usr/local/bin/monitor-handler.sh
```

### Configuration Options

#### Server Fields

- `url` (required): Server URL (e.g., `https://ntfy.sh`)
- `token` (optional): Authentication token (can also be stored in Keychain)
- `topics` (required): List of topics to subscribe to

#### Topic Fields

- `name` (required): Topic name to subscribe to
- `icon_symbol` (optional): SF Symbol name (e.g., `bell.fill`, `server.rack`)
- `icon_path` (optional): Absolute path to local image file (.png, .jpg)
- `auto_run_script` (optional): Script to execute automatically when message arrives
- `silent` (optional): If `true`, skip notification banner (useful for background automation)
- `actions` (optional): List of interactive buttons

#### Action Fields

- `title` (required): Button label
- `type` (required): `script` or `view`
- `path` (required for script): Absolute path to script file
- `url` (required for view): URL to open when clicked

## CLI Commands

### serve

Start the notification service:

```bash
ntfy-macos serve [--config PATH]
```

Options:
- `--config PATH`: Use custom configuration file path

### auth

Manage authentication tokens in Keychain:

```bash
# Add a token
ntfy-macos auth add <server-url> <token>

# List all stored tokens
ntfy-macos auth list

# Remove a token
ntfy-macos auth remove <server-url>
```

Keychain tokens take priority over tokens in the YAML configuration.

### test-notify

Send a test notification (and request permissions):

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

### Security Considerations

Scripts are **only executed if explicitly configured** in your local `config.yml` file. ntfy-macos will never execute arbitrary code from incoming messages.

**Best practices:**
- Only configure scripts that you trust and have reviewed
- Use absolute paths to scripts (e.g., `/usr/local/bin/myscript.sh`)
- For public topics, avoid `auto_run_script` — use interactive action buttons instead, so you can review notifications before triggering scripts
- Keep your configuration file secure (`chmod 600 ~/.config/ntfy-macos/config.yml`)
- For sensitive automation, use a self-hosted ntfy server with authentication

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

## Emoji Tags

ntfy supports [emoji shortcodes](https://docs.ntfy.sh/emojis/) in the `Tags` field. When you send a message with tags like `warning` or `fire`, ntfy-macos automatically converts them to emojis and prepends them to the notification title.

Example using curl:
```bash
curl -H "Tags: warning,fire" -H "Title: Alert" -d "Server is down" https://ntfy.sh/mytopic
```

This displays as: **⚠️🔥 Alert**

Common tags: `warning` (⚠️), `fire` (🔥), `+1` (👍), `skull` (💀), `bell` (🔔), `rocket` (🚀), `check` (✅), etc.

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

### Multi-Server Setup

```yaml
servers:
  # Public ntfy.sh
  - url: https://ntfy.sh
    topics:
      - name: public-alerts
        icon_symbol: bell.fill

  # Self-hosted server
  - url: https://ntfy.mycompany.com
    token: tk_secret
    topics:
      - name: deployments
        icon_symbol: arrow.up.circle.fill
        actions:
          - title: View Status
            type: view
            url: "https://ci.mycompany.com"
          - title: Rollback
            type: script
            path: /usr/local/bin/rollback.sh
```

### Home Automation

```yaml
servers:
  - url: https://ntfy.home.local
    topics:
      - name: homeassistant
        icon_path: /Users/you/icons/ha.png
        actions:
          - title: Open Home Assistant
            type: view
            url: "homeassistant://"
```

### Silent Background Processing

```yaml
servers:
  - url: https://ntfy.sh
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

MIT License

## Credits

This project is a third-party client for [ntfy](https://ntfy.sh), created by [Philipp C. Heckel](https://github.com/binwiederhier). ntfy is a simple, open-source pub-sub notification service that makes it easy to send push notifications to your devices.

## Related Projects

- [ntfy](https://ntfy.sh) - Simple pub-sub notification service by Philipp C. Heckel
- [ntfy-android](https://github.com/binwiederhier/ntfy-android) - Official Android app
- [ntfy-ios](https://github.com/binwiederhier/ntfy-ios) - Official iOS app

## Support

For bugs and feature requests, please open an issue on GitHub.
