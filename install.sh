#!/bin/bash
set -e

echo "🚀 ntfy-macos Installation Script"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is only for macOS"
    exit 1
fi

# Check if Xcode Command Line Tools are installed
if ! xcode-select -p &>/dev/null; then
    print_error "Xcode Command Line Tools are not installed."
    print_status "Run: xcode-select --install"
    exit 1
fi

# Stop any running instance
print_status "Stopping any running ntfy-macos instance..."
killall ntfy-macos 2>/dev/null && print_success "Stopped existing instance" || print_status "No running instance found"

# Build the app
print_status "Building ntfy-macos app..."
if ! ./build-app.sh >/dev/null 2>&1; then
    print_error "Build failed"
    exit 1
fi
print_success "App built successfully"

# Install the app
print_status "Installing app to /Applications..."
if ! sudo cp -R .build/release/ntfy-macos.app /Applications/; then
    print_error "Failed to install app"
    exit 1
fi
print_success "App installed to /Applications"

# Reset notification permissions
print_status "Resetting notification permissions..."
tccutil reset UserNotifications com.laurentftech.ntfy-macos 2>/dev/null || true

# Launch the app in background
print_status "Launching ntfy-macos..."
/Applications/ntfy-macos.app/Contents/MacOS/ntfy-macos &
APP_PID=$!

# Wait a moment for the app to start
sleep 2

# Check if app is running
if kill -0 $APP_PID 2>/dev/null; then
    print_success "ntfy-macos is now running!"
    print_status "Look for the bell icon (🔔) in your menu bar"
    print_status ""
    print_status "To configure notifications:"
    print_status "1. Go to System Settings → Notifications"
    print_status "2. Find 'ntfy-macos' and enable notifications"
    print_status ""
    print_status "To edit configuration:"
    print_status "Click the menu bar icon → Edit Config..."
else
    print_warning "App may not have started properly. Check the configuration."
    print_status "You might need to create a config file first:"
    print_status "  /Applications/ntfy-macos.app/Contents/MacOS/ntfy-macos init"
fi

print_success "Installation complete! 🎉"