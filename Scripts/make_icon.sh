#!/usr/bin/env bash
# Build a macOS AppIcon.icns from a square source PNG the way Apple expects,
# using ONLY sips and iconutil — no Xcode, no asset catalog.
#
# Source:  Sources/DriveCaffeineApp/Resources/source-icon.png  (square, >=1024)
# Output:  Sources/DriveCaffeineApp/Resources/AppIcon.icns
#
# The source is a full-bleed square illustration; this pipeline keeps it
# full-bleed (plain resize, no rounding) so the artwork stays as large and
# crisp as possible at every size.
set -euo pipefail
cd "$(dirname "$0")/.."

RES="Sources/DriveCaffeineApp/Resources"
SRC="$RES/source-icon.png"
OUT="$RES/AppIcon.icns"
ISET="$(mktemp -d)/AppIcon.iconset"

# 1) Verify the source is square and >= 1024x1024.
[ -f "$SRC" ] || { echo "error: source not found: $SRC" >&2; exit 1; }
W=$(sips -g pixelWidth  "$SRC" | awk '/pixelWidth/  {print $2}')
H=$(sips -g pixelHeight "$SRC" | awk '/pixelHeight/ {print $2}')
[ "$W" = "$H" ] || { echo "error: source is not square (${W}x${H})." >&2; exit 1; }
if [ "$W" -lt 1024 ]; then
  echo "warning: source is ${W}x${H} (<1024). Upscaling will look bad; use a larger source." >&2
fi
echo "source: ${W}x${H} (square) -> $OUT"

# 2) Generate the 10 required PNGs at Apple's exact filenames/sizes.
mkdir -p "$ISET"
gen() { sips -z "$2" "$2" "$SRC" --out "$ISET/$1" >/dev/null; }   # -z <h> <w>
gen icon_16x16.png        16
gen icon_16x16@2x.png     32
gen icon_32x32.png        32
gen icon_32x32@2x.png     64
gen icon_128x128.png     128
gen icon_128x128@2x.png  256
gen icon_256x256.png     256
gen icon_256x256@2x.png  512
gen icon_512x512.png     512
gen icon_512x512@2x.png 1024

# 3) Compile the iconset into a .icns.
iconutil -c icns "$ISET" -o "$OUT"

# 4) Clean up the temporary iconset folder.
rm -rf "$(dirname "$ISET")"

echo "built: $OUT"
