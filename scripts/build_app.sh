#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

APP_NAME="LocTrip"
BUILD_DIR="$PROJECT_ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building $APP_NAME for macOS (Release)..."
swift build -c release

# Find the release binary
BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"

echo "📦 Assembling $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary and Info.plist
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
cp "$PROJECT_ROOT/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# Code sign with entitlements
echo "🔐 Signing app bundle with entitlements..."
codesign --force --deep --sign - --entitlements "$PROJECT_ROOT/Resources/LocTrip.entitlements" "$APP_BUNDLE"

echo "✅ App bundle created successfully at:"
echo "   $APP_BUNDLE"
echo ""
echo "🚀 To launch the app, run:"
echo "   open \"$APP_BUNDLE\""
