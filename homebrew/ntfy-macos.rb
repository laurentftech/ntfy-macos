# Homebrew Formula for ntfy-macos
#
# Installation via custom tap:
#   brew tap laurentftech/ntfy-macos https://github.com/laurentftech/ntfy-macos
#   brew install ntfy-macos
#
# Or install directly:
#   brew install laurentftech/ntfy-macos/ntfy-macos

class NtfyMacos < Formula
  desc "Native macOS CLI notifier and automation agent for ntfy"
  homepage "https://github.com/laurentftech/ntfy-macos"
  url "https://github.com/laurentftech/ntfy-macos/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "YOUR_SHA256_HERE"
  license "Apache-2.0"
  head "https://github.com/laurentftech/ntfy-macos.git", branch: "main"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/ntfy-macos"
  end

  def plist_name
    "com.ntfy-macos.agent"
  end

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/ntfy-macos</string>
          <string>serve</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <dict>
          <key>SuccessfulExit</key>
          <false/>
        </dict>
        <key>StandardOutPath</key>
        <string>#{var}/log/ntfy-macos/stdout.log</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/ntfy-macos/stderr.log</string>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
        <key>EnvironmentVariables</key>
        <dict>
          <key>PATH</key>
          <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        </dict>
      </dict>
      </plist>
    EOS
  end

  def post_install
    (var/"log/ntfy-macos").mkpath
  end

  service do
    run [opt_bin/"ntfy-macos", "serve"]
    keep_alive true
    log_path var/"log/ntfy-macos/stdout.log"
    error_log_path var/"log/ntfy-macos/stderr.log"
  end

  test do
    system "#{bin}/ntfy-macos", "help"
  end
end
