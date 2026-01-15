# Development Guide

## Prerequisites

- macOS 13+ (Ventura or later)
- Xcode 14+ with Swift 6 toolchain
- Swift Package Manager (included with Xcode)

## Building from Source

### Debug Build

```bash
swift build
```

The binary will be located at `.build/debug/ntfy-macos`.

### Release Build

```bash
swift build -c release
```

The binary will be located at `.build/release/ntfy-macos`.

### Running the Debug Binary

```bash
# Show help
.build/debug/ntfy-macos help

# Initialize configuration
.build/debug/ntfy-macos init

# Start the service
.build/debug/ntfy-macos serve
```

## Project Structure

```
ntfy-macos/
├── Package.swift              # SPM package definition
├── Sources/
│   ├── main.swift            # Entry point and CLI handling
│   ├── Config.swift          # YAML configuration parser
│   ├── KeychainHelper.swift  # Keychain integration
│   ├── NtfyClient.swift      # ntfy streaming client
│   ├── NotificationManager.swift # macOS notifications
│   └── ScriptRunner.swift    # Shell script execution
├── examples/
│   ├── config-example.yml    # Sample configuration
│   └── sample-handler.sh     # Sample script
├── homebrew/
│   └── ntfy-macos.rb         # Homebrew formula
└── README.md
```

## Architecture Overview

### NtfyClient.swift

Handles the persistent connection to ntfy servers:
- Uses URLSession for streaming JSON
- Implements line-by-line JSON parsing
- Handles reconnection with exponential backoff
- Supports Bearer token authentication

### NotificationManager.swift

Manages macOS notification system:
- Creates rich notifications with SF Symbols
- Supports interactive action buttons
- Maps ntfy priority to macOS interruption levels
- Handles notification responses

### ScriptRunner.swift

Executes shell scripts:
- Enhanced PATH for Homebrew tools
- Asynchronous execution
- Passes message body as script argument
- Captures script output for logging

### Config.swift

YAML configuration management:
- Uses Yams library for parsing
- Supports multiple topics with different settings
- Token management (file or Keychain)
- Sample config generation

### KeychainHelper.swift

Secure token storage:
- Uses macOS Keychain API
- Server-specific token storage
- Prioritized over YAML tokens

## Swift 6 Concurrency

The project uses Swift 6 with strict concurrency checking:

- `@MainActor` for UI-related components (NotificationManager, ConfigManager)
- `@unchecked Sendable` for NtfyClient (URLSession delegate)
- `@preconcurrency` for protocol conformance to system frameworks
- `nonisolated` delegate methods with Task wrappers

## Testing Locally

### 1. Create Configuration

```bash
.build/debug/ntfy-macos init
```

This creates `~/.config/ntfy-macos/config.yml`.

### 2. Edit Configuration

Edit the config file to add your topics:

```yaml
server: https://ntfy.sh

topics:
  - name: test
    icon_symbol: bell.fill
```

### 3. Test Notifications

```bash
.build/debug/ntfy-macos test-notify --topic test
```

### 4. Start the Service

```bash
.build/debug/ntfy-macos serve
```

### 5. Send a Test Message

In another terminal:

```bash
curl -d "Hello from ntfy-macos!" https://ntfy.sh/test
```

## Debugging

### Enable Verbose Output

The application prints diagnostic information to stdout/stderr:

```bash
.build/debug/ntfy-macos serve
```

You'll see:
- Connection status
- Received messages
- Script execution logs
- Error messages

### Check Notification Permissions

System Settings → Notifications → Look for "ntfy-macos"

Ensure "Allow Notifications" is enabled.

### Test Script Execution

Test scripts manually:

```bash
/bin/sh /path/to/your/script.sh "test message"
```

## Common Issues

### Build Errors

If you encounter build errors:

```bash
# Clean build artifacts
swift package clean

# Reset package cache
rm -rf .build
rm Package.resolved

# Rebuild
swift build
```

### Swift Version Issues

Check your Swift version:

```bash
swift --version
```

Should be Swift 6.0 or later.

### Notification Permission Issues

If notifications don't appear:

1. Check System Settings → Notifications
2. Look for ntfy-macos in the list
3. Ensure notifications are enabled
4. Try running the test-notify command

### Connection Issues

If the client can't connect:

- Check server URL in config
- Verify network connectivity
- Check authentication token
- Review logs for error messages

## Code Style

- Use Swift naming conventions (camelCase for properties/methods)
- Add documentation comments for public APIs
- Keep functions focused and single-purpose
- Use meaningful variable names
- Prefer immutability (let over var)

## Dependencies

The project uses minimal dependencies:

- **Yams** (5.0+): YAML parsing
- **Foundation**: Core functionality
- **UserNotifications**: macOS notifications
- **Security**: Keychain API
- **AppKit**: SF Symbols and system integration

## Adding Features

### Adding a New Command

1. Add case to switch statement in `CLI.main()`
2. Create handler function (e.g., `handleNewCommand`)
3. Update `printUsage()` with command documentation
4. Test the command

### Adding Configuration Options

1. Add properties to `TopicConfig` struct in [Config.swift](Sources/Config.swift)
2. Update `CodingKeys` enum if using snake_case
3. Update sample configuration in `createSampleConfig()`
4. Update [config-example.yml](examples/config-example.yml)
5. Use the new option in relevant code

## Performance Considerations

- Streaming JSON parser processes messages as they arrive
- Scripts run asynchronously to avoid blocking
- Reconnection uses exponential backoff
- Keychain queries are cached where possible

## Security Considerations

- Tokens stored in macOS Keychain
- Script execution uses explicit PATH
- No shell command injection (using Process directly)
- Configuration file should have restricted permissions

## Contributing

When contributing:

1. Ensure code builds with `swift build`
2. Test on macOS 13+
3. Follow Swift 6 concurrency guidelines
4. Add documentation for new features
5. Update README.md if adding user-facing features

## Release Process

1. Update version in homebrew formula
2. Build release binary: `swift build -c release`
3. Create GitHub release with binary
4. Update formula SHA256
5. Test formula installation
6. Tag release in git

## License

Apache License 2.0 - See [LICENSE](LICENSE) for details
