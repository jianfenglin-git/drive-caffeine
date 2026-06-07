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

APP="DriveCaffeine"
CONFIG="release"
BUNDLE="build/$APP.app"

echo "→ swift build ($CONFIG)"
swift build -c "$CONFIG" --product DriveCaffeineApp

BIN=$(swift build -c "$CONFIG" --product DriveCaffeineApp --show-bin-path)/DriveCaffeineApp

echo "→ assemble $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN" "$BUNDLE/Contents/MacOS/$APP"
cp Info.plist "$BUNDLE/Contents/Info.plist"

# Custom menu-bar icon (template PNGs — macOS tints for light/dark).
cp Sources/DriveCaffeineApp/Resources/MenuIcon*.png "$BUNDLE/Contents/Resources/"

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
