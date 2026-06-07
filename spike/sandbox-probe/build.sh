#!/usr/bin/env bash
# Build the Step-0.5 sandbox spike into a runnable, sandboxed .app — using only
# Command Line Tools (swiftc + codesign). No full Xcode needed.
#
# Ad-hoc code signing (-s -) + the App Sandbox entitlement gives us a REAL
# sandboxed app for local testing. (App Store submission would need full Xcode
# + notarization, but the spike only needs to run locally.)
set -euo pipefail
cd "$(dirname "$0")"

APP="DriveCaffeineSpike"
BUNDLE="build/$APP.app"
SDK=$(xcrun --sdk macosx --show-sdk-path)

echo "→ clean"
rm -rf build
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

echo "→ compile (arm64, macOS 13, parse-as-library for @main)"
xcrun swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macos13.0 \
  -parse-as-library \
  -O \
  -o "$BUNDLE/Contents/MacOS/$APP" \
  SandboxProbeApp.swift

echo "→ install Info.plist"
cp Info.plist "$BUNDLE/Contents/Info.plist"

echo "→ ad-hoc code-sign WITH sandbox entitlements"
codesign --force --sign - \
  --entitlements SandboxProbe.entitlements \
  --options runtime \
  "$BUNDLE"

echo "→ verify signature + entitlements"
codesign -dv --entitlements - "$BUNDLE" 2>&1 | grep -E "Signature|com.apple.security" || true

echo
echo "✅ Built: $BUNDLE"
echo "Run it:   open \"$PWD/$BUNDLE\""
echo "(A menu-bar icon appears — no Dock icon. Click it to pick a drive.)"
