#!/bin/bash
# Quick test script for ntfy-macos app bundle

set -e

APP=".build/debug/ntfy-macos.app/Contents/MacOS/ntfy-macos"

echo "🧪 Testing ntfy-macos App Bundle"
echo "================================="
echo ""

echo "✅ App bundle exists at:"
ls -la .build/debug/ntfy-macos.app/Contents/
echo ""

echo "📝 Test 1: Help command"
$APP help | head -5
echo ""

echo "📝 Test 2: Init config"
$APP init
echo ""

echo "📝 Test 3: Check config was created"
ls -la ~/.config/ntfy-macos/config.yml
echo ""

echo "🎯 MANUAL TEST REQUIRED:"
echo "========================"
echo ""
echo "1. Edit your config:"
echo "   nano ~/.config/ntfy-macos/config.yml"
echo ""
echo "2. Add your topic, for example:"
echo "   server: https://ntfy.sh"
echo "   topics:"
echo "     - name: test-$(whoami)"
echo "       icon_symbol: bell.fill"
echo ""
echo "3. Run the service:"
echo "   $APP serve"
echo ""
echo "4. In ANOTHER terminal, send a test notification:"
echo "   curl -d 'Hello from ntfy-macos!' https://ntfy.sh/test-$(whoami)"
echo ""
echo "5. Check if you see a macOS notification! 🎉"
echo ""
echo "If you see a notification, everything works! ✅"
