# ntfy-macos Project Overview

## Summary

ntfy-macos is a native macOS CLI application that connects to [ntfy](https://ntfy.sh) servers to receive real-time notifications and execute automated actions. Built with Swift 6 using modern concurrency features, it provides a robust, production-ready notification and automation system for macOS.

## Key Statistics

- **Total Lines of Code**: ~1,065 lines of Swift
- **Swift Version**: 6.0 (with strict concurrency checking)
- **Minimum macOS**: 13.0 (Ventura)
- **Dependencies**: 1 external (Yams for YAML parsing)
- **Files**: 6 Swift source files

## Core Components

### 1. NtfyClient (224 lines)

**Purpose**: Manages persistent streaming connection to ntfy servers

**Features**:
- Streaming JSON line-by-line parser
- Automatic reconnection with exponential backoff
- Bearer token authentication
- URLSession-based implementation
- Robust error handling and state management

**Key Implementation Details**:
- Implements `URLSessionDataDelegate` for streaming
- Uses `@unchecked Sendable` for thread safety
- Handles network interruptions gracefully
- Supports multiple topic subscriptions

### 2. NotificationManager (248 lines)

**Purpose**: Creates and manages macOS native notifications

**Features**:
- Rich notifications with SF Symbols
- Local image attachments
- Interactive action buttons
- Priority-based interruption levels
- Silent notification mode

**Key Implementation Details**:
- `@MainActor` isolated for UI safety
- Implements `UNUserNotificationCenterDelegate`
- Dynamic category registration
- SF Symbol to PNG conversion
- Handles notification responses

**Priority Mapping**:
```
ntfy priority 5 → Critical (bypasses Focus)
ntfy priority 4 → Time Sensitive
ntfy priority 1-3 → Active
```

### 3. ScriptRunner (126 lines)

**Purpose**: Executes shell scripts in response to notifications

**Features**:
- Asynchronous execution
- Enhanced PATH for Homebrew tools
- Message body passed as argument
- Output capture and logging
- Validation checks

**Key Implementation Details**:
- Uses Foundation's `Process` API
- Runs on background queue
- Injects enhanced PATH environment
- Synchronous and asynchronous variants

**Enhanced PATH**:
```
/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
```

### 4. Config (137 lines)

**Purpose**: Parses and manages YAML configuration

**Features**:
- Yams-based YAML parsing
- Type-safe configuration model
- Sample config generation
- Token priority (Keychain > YAML)
- Per-topic customization

**Configuration Schema**:
```yaml
server: String (required)
token: String (optional)
topics: Array (required)
  - name: String (required)
    icon_symbol: String (optional)
    icon_path: String (optional)
    auto_run_script: String (optional)
    silent: Boolean (optional)
    actions: Array (optional)
      - title: String
        type: String
        path: String
```

### 5. KeychainHelper (80 lines)

**Purpose**: Secure token storage in macOS Keychain

**Features**:
- Server-specific token storage
- CRUD operations (save, get, delete)
- Type-safe error handling
- Keychain API abstraction

**Key Implementation Details**:
- Uses Security framework
- Service identifier: `com.ntfy-macos.auth`
- Account identifier: server URL
- Error enum for failure cases

### 6. main.swift (250 lines)

**Purpose**: CLI interface and application lifecycle

**Features**:
- Command routing (serve, auth, test-notify, init, help)
- Argument parsing
- Delegate implementation
- RunLoop management

**Commands**:
- `serve`: Start the notification service
- `auth`: Store token in Keychain
- `test-notify`: Send test notification
- `init`: Create sample config
- `help`: Show usage information

## Swift 6 Concurrency Model

### Actor Isolation Strategy

| Component | Isolation | Reason |
|-----------|-----------|--------|
| ConfigManager | @MainActor | File I/O, shared state |
| NotificationManager | @MainActor | UI operations |
| NtfyClient | @unchecked Sendable | URLSession delegate |
| ScriptRunner | Sendable | No mutable state |
| NtfyMacOS | @MainActor | Coordinates UI components |

### Thread Safety Guarantees

- All UI operations on MainActor
- Network operations on background threads
- Script execution on utility queue
- Keychain operations are synchronous but thread-safe

## Configuration System

### Default Locations

- Config file: `~/.config/ntfy-macos/config.yml`
- Logs (when using Homebrew): `/opt/homebrew/var/log/ntfy-macos/`

### Topic Configuration

Each topic supports:

1. **Visual Customization**
   - SF Symbol icons (1000+ built-in options)
   - Local image files (.png, .jpg)

2. **Automation**
   - Auto-run scripts on message receipt
   - Silent mode (no notification banner)

3. **Interaction**
   - Up to 4 action buttons
   - Each button executes a script

### Example Use Cases

**Server Monitoring**:
```yaml
- name: server-alerts
  icon_symbol: exclamationmark.triangle.fill
  auto_run_script: /usr/local/bin/alert-handler.sh
  actions:
    - title: SSH to Server
      type: script
      path: /usr/local/bin/ssh-connect.sh
```

**Deployment Notifications**:
```yaml
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

**Silent Background Processing**:
```yaml
- name: background-jobs
  silent: true
  auto_run_script: /usr/local/bin/process-job.sh
```

## Network Architecture

### Connection Flow

```
Application Start
       ↓
Load Configuration
       ↓
Request Notification Permission
       ↓
Create NtfyClient
       ↓
Connect to ntfy Server (Streaming)
       ↓
Receive Messages (Line-by-Line JSON)
       ↓
Process & Dispatch
   ↙        ↘
Scripts   Notifications
```

### Reconnection Strategy

- Initial delay: 2 seconds
- Exponential backoff: delay × 2^attempts
- Maximum delay: 60 seconds
- Maximum attempts: 10
- Triggers: Network errors, server disconnection, sleep/wake

### Message Processing

1. URLSession receives data chunks
2. Data appended to buffer
3. Buffer scanned for newlines
4. Each line decoded as JSON
5. Message validated (event == "message")
6. Delegate notified on main thread
7. Notification shown (if not silent)
8. Script executed (if configured)

## Deployment Options

### 1. Manual Installation

```bash
swift build -c release
cp .build/release/ntfy-macos /usr/local/bin/
```

### 2. Homebrew (Recommended)

```bash
brew install ntfy-macos
brew services start ntfy-macos
```

The Homebrew formula:
- Installs binary to `/opt/homebrew/bin/`
- Creates LaunchAgent plist
- Sets up log directories
- Configures auto-start

### 3. LaunchAgent (Background Service)

The service:
- Runs at login
- Restarts on failure
- Logs to `/opt/homebrew/var/log/ntfy-macos/`
- Uses proper environment PATH

## Security Model

### Token Storage

1. **Keychain** (Highest Priority)
   - Encrypted by macOS
   - Per-server storage
   - Requires user authentication

2. **YAML File** (Fallback)
   - Plain text (should be protected)
   - Useful for testing
   - Recommend Keychain for production

### Script Execution

- Uses explicit PATH (no shell expansion)
- Direct Process API (no command injection)
- Scripts must be explicitly marked executable
- Output captured and logged

### Permissions Required

- Notification permissions (requested at runtime)
- Network access (outbound only)
- File system (config read, script execution)
- Keychain access (token storage)

## Error Handling

### Network Errors

- Automatic reconnection
- Exponential backoff
- Logged to stderr
- User notification optional

### Script Errors

- Non-zero exit codes logged
- Don't block other operations
- Async execution prevents timeouts
- Output captured for debugging

### Configuration Errors

- Validated at load time
- Sample config created if missing
- Clear error messages
- Non-blocking (allows reconfiguration)

## Performance Characteristics

### Memory Usage

- Base: ~10-15 MB
- Per topic: ~1-2 MB
- Streaming buffer: Dynamic, cleared after processing
- Notification queue: System-managed

### CPU Usage

- Idle: <1% CPU
- Receiving messages: <5% CPU (spikes)
- Script execution: Depends on script

### Network Usage

- Persistent connection: ~1 KB/hour (keepalive)
- Per message: ~0.1-1 KB (depends on payload)
- Reconnection overhead: Minimal

## Testing Strategy

### Unit Testing

Not currently implemented, but recommended areas:

- Config parsing
- Message decoding
- Reconnection logic
- Script validation

### Integration Testing

```bash
# Test configuration
ntfy-macos init

# Test authentication
ntfy-macos auth --server https://ntfy.sh --token test_token

# Test notifications
ntfy-macos test-notify --topic test

# Test full flow
ntfy-macos serve &
curl -d "Test message" https://ntfy.sh/your-topic
```

### Manual Testing

1. Network interruption (disable/enable Wi-Fi)
2. Sleep/wake cycle
3. Multiple simultaneous messages
4. Script execution with various payloads
5. Permission denial/grant flows

## Future Enhancement Ideas

### Short-term

- [ ] Add logging level configuration
- [ ] Support for ntfy message attachments
- [ ] Message filtering/rules
- [ ] Notification grouping by topic
- [ ] Config file validation command

### Medium-term

- [ ] Multiple server support
- [ ] Message history/archive
- [ ] Desktop widget/menu bar app
- [ ] Notification templates
- [ ] Custom sound support

### Long-term

- [ ] GUI configuration editor
- [ ] Message statistics/analytics
- [ ] Plugin system for actions
- [ ] Cross-platform support (Linux)
- [ ] Encrypted message support

## Troubleshooting Guide

### Notifications Not Appearing

1. Check System Settings → Notifications
2. Verify ntfy-macos has permission
3. Test with `test-notify` command
4. Check logs for errors

### Connection Issues

1. Verify server URL
2. Check network connectivity
3. Test with curl: `curl https://ntfy.sh/your-topic/json`
4. Review authentication token
5. Check firewall settings

### Script Not Running

1. Verify script is executable: `chmod +x script.sh`
2. Test manually: `/bin/sh script.sh "test"`
3. Check script PATH requirements
4. Review script output in logs

### Service Not Starting

1. Check configuration file exists
2. Validate YAML syntax
3. Review stderr logs
4. Test with `ntfy-macos serve` directly

## Resources

- [ntfy Documentation](https://ntfy.sh)
- [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [UserNotifications Framework](https://developer.apple.com/documentation/usernotifications)
- [Yams GitHub](https://github.com/jpsim/Yams)

## License

Apache License 2.0

## Acknowledgments

- Built for the ntfy ecosystem
- Uses Yams YAML library
- Inspired by ntfy-android and ntfy-ios official apps
