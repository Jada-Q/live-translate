#!/bin/bash
# Assemble the SPM executable into a minimal .app bundle + ad-hoc codesign.
# Reused from Phase 0 probe through Phase 5 packaging.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
APP="$ROOT/build/LiveTranslate.app"
BIN="$ROOT/.build/$CONFIG/live-translate"

[ -f "$BIN" ] || { echo "binary not found: $BIN (run 'swift build' first)"; exit 1; }

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/live-translate"
[ -f "$ROOT/icon/AppIcon.icns" ] && cp "$ROOT/icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>live-translate</string>
    <key>CFBundleIdentifier</key>
    <string>com.jada.livetranslate</string>
    <key>CFBundleName</key>
    <string>LiveTranslate</string>
    <key>CFBundleDisplayName</key>
    <string>现场翻译</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>用于现场录音并实时翻译为中文。音频仅在本机处理，不上传。</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" 2>&1
echo "built: $APP"
