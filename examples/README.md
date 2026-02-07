# ntfy-macos Examples

This folder contains example configurations and scripts for common automation scenarios.

## Configuration Examples

See [config-examples.yml](config-examples.yml) for various use cases:

- **Home Automation** - Home Assistant integration with deep links
- **CI/CD Pipelines** - GitHub Actions, GitLab CI notifications
- **Server Monitoring** - Alerts with SSH and Grafana shortcuts
- **NAS / Synology** - DSM quick access
- **Package Updates** - Auto-update yt-dlp, Homebrew packages
- **Security Alerts** - Log viewing and IP blocking
- **Background Processing** - Silent triggers for backup/sync
- **Smart Home** - Doorbell, garage, and other IoT devices
- **Development Tools** - Build notifications, PR reviews
- **macOS Shortcuts** - Trigger Shortcuts app automations from notifications
- **AppleScript Actions** - Run inline or file-based AppleScript
- **Fetch Missed Messages** - Catch up on messages received while app was offline

## Action Types

| Type | Description | Example |
|------|-------------|---------|
| `view` | Open a URL in the default browser | `url: "https://example.com"` |
| `script` | Run a shell script via `/bin/sh` | `path: /usr/local/bin/handler.sh` |
| `shortcut` | Run a macOS Shortcut | `name: "My Shortcut"` |
| `applescript` | Run AppleScript (inline or file) | `script: 'tell app "Finder" to activate'` |

## Example Scripts

All scripts in the `scripts/` folder:

| Script | Description | Topic |
|--------|-------------|-------|
| `update-yt-dlp.sh` | Auto-update yt-dlp | `yt-dlp-releases` |
| `brew-upgrade.sh` | Upgrade Homebrew packages | `homebrew-updates` |
| `run-backup.sh` | Trigger Time Machine or rsync backup | `backup-trigger` |
| `disk-cleanup.sh` | Clean up caches when disk is full | `disk-alerts` |
| `deploy.sh` | Deploy app after CI success | `github-actions` |
| `open-ssh.sh` | Open Terminal with SSH session | `server-alerts` |
| `garage-toggle.sh` | Toggle garage door via Home Assistant | `garage` |
| `unlock-door.sh` | Unlock front door via Home Assistant | `doorbell` |
| `sync-files.sh` | Sync files to cloud/remote | `sync-trigger` |

## Environment Variables

Scripts run via `auto_run_script` receive the following environment variables:

| Variable | Description |
|----------|-------------|
| `NTFY_ID` | Unique message ID |
| `NTFY_TOPIC` | Topic name |
| `NTFY_TIME` | Message timestamp (Unix epoch) |
| `NTFY_EVENT` | Event type (usually "message") |
| `NTFY_TITLE` | Notification title (if set) |
| `NTFY_MESSAGE` | Notification message |
| `NTFY_PRIORITY` | Priority level 1-5 (if set) |
| `NTFY_TAGS` | Comma-separated tags (if set) |
| `NTFY_CLICK` | Click URL (if set) |

The message body is also passed as the first argument (`$1`) for backward compatibility.

## Local Notification Server

Enable `local_server_port` in your config to let scripts send follow-up notifications:

```yaml
local_server_port: 9292
```

Then from any script:
```bash
curl -X POST http://127.0.0.1:9292/notify \
    -H "Content-Type: application/json" \
    -d '{"title": "Done", "message": "Task completed"}'
```

## Installation

1. Copy desired scripts to `/usr/local/bin/`:
   ```bash
   cp scripts/update-yt-dlp.sh /usr/local/bin/
   chmod +x /usr/local/bin/update-yt-dlp.sh
   ```

2. Edit scripts to match your configuration (paths, tokens, servers)

3. Add the corresponding topic configuration to `~/.config/ntfy-macos/config.yml`

## Sending Test Notifications

Test your setup with curl:

```bash
# Simple notification
curl -d "Server backup complete" https://ntfy.sh/your-topic

# With title and tags
curl -H "Title: Backup Status" -H "Tags: white_check_mark" \
     -d "Daily backup completed successfully" \
     https://ntfy.sh/your-topic

# With priority
curl -H "Priority: high" -H "Tags: warning" \
     -d "Disk space low: 5% remaining" \
     https://ntfy.sh/your-topic
```

## Security Notes

- Always review scripts before deploying
- Use absolute paths in config
- Store sensitive tokens in the scripts or use environment variables
- For public topics, prefer action buttons over `auto_run_script`
- Consider using a self-hosted ntfy server for sensitive automation
- AppleScript and Shortcut actions can be powerful — only use with trusted servers
