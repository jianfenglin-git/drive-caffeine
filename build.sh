#!/usr/bin/env bash
# Build DriveCaffeine into a runnable, sandboxed .app.
#
#   swift build (release)  →  wrap the executable in a .app bundle  →  compile
#   the app icon  →  ad-hoc code-sign WITH the App Sandbox entitlements.
#
# This produces a real sandboxed app you can run locally. App Store submission
# additionally needs a Developer ID / notarization (see project.yml).
#
# Uses full Xcode when installed: its actool compiles the Icon Composer
# DriveCaffeine.icon into Assets.car + DriveCaffeine.icns (rounded-rect shape
# baked in), exactly as the Xcode/App Store build does. With Command Line Tools
# only, the app still builds, just without its app icon (menu-bar icon is fine).
set -euo pipefail
cd "$(dirname "$0")"

# If the active developer dir (often Command Line Tools) has no actool, use
# Xcode for this build without changing the system-wide xcode-select setting.
XCODE_DEV="/Applications/Xcode.app/Contents/Developer"
if ! xcrun --find actool >/dev/null 2>&1 && [ -z "${DEVELOPER_DIR:-}" ] && [ -d "$XCODE_DEV" ]; then
  export DEVELOPER_DIR="$XCODE_DEV"
  echo "→ using Xcode toolchain: $DEVELOPER_DIR"
fi

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
# App icon: compile the Icon Composer bundle → Assets.car (read via
# CFBundleIconName) + DriveCaffeine.icns (CFBundleIconFile fallback). Both names
# are "DriveCaffeine" in Info.plist.
ICON_SRC="Sources/DriveCaffeineApp/Resources/DriveCaffeine.icon"
if xcrun --find actool >/dev/null 2>&1; then
  echo "→ compile app icon ($ICON_SRC)"
  xcrun actool "$ICON_SRC" \
    --compile "$BUNDLE/Contents/Resources" \
    --platform macosx --target-device mac \
    --minimum-deployment-target 13.0 \
    --app-icon DriveCaffeine \
    --output-partial-info-plist "$(mktemp -d)/icon-partial.plist" \
    --errors --warnings >/dev/null
  for f in Assets.car DriveCaffeine.icns; do
    [ -f "$BUNDLE/Contents/Resources/$f" ] || { echo "error: actool did not produce $f" >&2; exit 1; }
  done
else
  echo "⚠️  actool not found (Command Line Tools only) — building WITHOUT the app icon." >&2
  echo "   Install Xcode to compile $ICON_SRC." >&2
fi

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
