#!/bin/bash
# Render the waveform PNG, build a full iconset, and produce icon/AppIcon.icns.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PNG=/tmp/lt-icon-1024.png
ICONSET=/tmp/LiveTranslate.iconset
mkdir -p "$ROOT/icon" "$ICONSET"

swift "$ROOT/scripts/icon-render.swift" "$PNG"

# standard macOS iconset sizes (1x + 2x)
sips -z 16   16   "$PNG" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32   32   "$PNG" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32   32   "$PNG" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64   64   "$PNG" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128  128  "$PNG" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256  256  "$PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256  256  "$PNG" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512  512  "$PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512  512  "$PNG" --out "$ICONSET/icon_512x512.png"    >/dev/null
cp "$PNG" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ROOT/icon/AppIcon.icns"
echo "built: $ROOT/icon/AppIcon.icns"
