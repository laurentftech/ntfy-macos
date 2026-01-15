#!/bin/bash
set -e

echo "Building ntfy-macos app bundle..."

# Build the executable
swift build -c release

# Create app bundle structure
APP_NAME="ntfy-macos"
APP_BUNDLE="$APP_NAME.app"
BUILD_DIR=".build/release"

rm -rf "$BUILD_DIR/$APP_BUNDLE"
mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "Resources/Info.plist" "$BUILD_DIR/$APP_BUNDLE/Contents/"

# Copy icon
cp "Resources/ntfy-macos.icns" "$BUILD_DIR/$APP_BUNDLE/Contents/Resources/"

# Ad-hoc sign the app bundle (required for notifications to work)
echo "Signing app bundle..."
codesign --force --deep --sign - "$BUILD_DIR/$APP_BUNDLE"

echo "✅ App bundle created at: $BUILD_DIR/$APP_BUNDLE"
echo ""
echo "To install:"
echo "  sudo cp -r $BUILD_DIR/$APP_BUNDLE /Applications/"
echo ""
echo "To run:"
echo "  $BUILD_DIR/$APP_BUNDLE/Contents/MacOS/$APP_NAME serve"
