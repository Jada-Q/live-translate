#!/bin/bash
# One-shot installer: release build → .app bundle → /Applications → launchd keepalive.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$ROOT/build/LiveTranslate.app"
APP_DST="/Applications/LiveTranslate.app"
LABEL="com.jada.livetranslate-keepalive"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

echo "==> 1/4 release build (optimized, slower to compile, faster to run)…"
cd "$ROOT"
swift build -c release

echo "==> 2/4 packaging .app bundle…"
bash "$ROOT/scripts/make-app.sh" release

echo "==> 3/4 installing to /Applications…"
# stop any running copy first
for P in $(pgrep -f "LiveTranslate.app"); do kill "$P" 2>/dev/null || true; done
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"
echo "    installed -> $APP_DST"

echo "==> 4/4 installing launchd keepalive (auto-start at login + restart on crash)…"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_DST/Contents/MacOS/live-translate</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ThrottleInterval</key>
    <integer>30</integer>
</dict>
</plist>
PLISTEOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"

echo ""
echo "✅ 安装完成。菜单栏会出现波形图标。"
echo "   • 开机自动启动；崩溃 30 秒内自动重启（正常退出不会被重启）"
echo "   • ⚠️ 不要再去「系统设置 > 登录项」手动添加本 app —— 会和 launchd 撞出两个图标"
echo "   • 卸载：bash scripts/uninstall.sh"
