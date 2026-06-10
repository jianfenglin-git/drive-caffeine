#!/usr/bin/env bash
# Build DriveCaffeine into a runnable, sandboxed .app — Command Line Tools only.
#
#   swift build (release)  →  wrap the executable in a .app bundle  →  ad-hoc
#   code-sign WITH the App Sandbox entitlements.
#
# This produces a real sandboxed app you can run locally. App Store submission
# additionally needs full Xcode + a Developer ID / notarization, but none of
# that is required to build and use the app on this machine.
set -euo pipefail
cd "$(dirname "$0")"

# Bundle name and executable name both "Drive Caffeine" — they MUST match
# CFBundleExecutable in Info.plist, or codesign reports "code object is not
# signed at all" (it signs the file present but the bundle expects the declared
# name). The Xcode project (PRODUCT_NAME) also produces "Drive Caffeine", so
# both build paths agree.
APP_NAME="Drive Caffeine"   # → "Drive Caffeine.app"
EXEC_NAME="Drive Caffeine"  # → Contents/MacOS/Drive Caffeine, matches CFBundleExecutable
CONFIG="release"
BUNDLE="build/$APP_NAME.app"

echo "→ swift build ($CONFIG)"
swift build -c "$CONFIG" --product DriveCaffeineApp

BIN=$(swift build -c "$CONFIG" --product DriveCaffeineApp --show-bin-path)/DriveCaffeineApp

# Remove any prior bundle under either old or new name to avoid stale copies.
rm -rf "build/DriveCaffeine.app" "$BUNDLE"
echo "→ assemble $BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/$EXEC_NAME"
cp Info.plist "$BUNDLE/Contents/Info.plist"

# Custom menu-bar icon (template PNGs — macOS tints for light/dark).
cp Sources/DriveCaffeineApp/Resources/MenuIcon*.png "$BUNDLE/Contents/Resources/"
# App/Dock icon (full-color .icns referenced by CFBundleIconFile in Info.plist).
cp Sources/DriveCaffeineApp/Resources/AppIcon.icns "$BUNDLE/Contents/Resources/"

echo "→ ad-hoc code-sign with sandbox entitlements"
codesign --force --sign - \
  --entitlements DriveCaffeine.entitlements \
  --options runtime \
  "$BUNDLE"

echo "→ verify"
codesign -dv --entitlements - "$BUNDLE" 2>&1 | grep -E "Signature|com.apple.security" || true

echo
echo "✅ Built: $BUNDLE"
echo "Run:   open \"$PWD/$BUNDLE\""
echo "       (or: open -a \"$APP_NAME\")"
