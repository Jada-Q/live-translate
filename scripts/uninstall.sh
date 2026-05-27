#!/bin/bash
# Remove the app + launchd agent. Keeps the downloaded Whisper model and
# translation language packs (so a reinstall doesn't re-download them).
LABEL="com.jada.livetranslate-keepalive"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
for P in $(pgrep -f "LiveTranslate.app"); do kill "$P" 2>/dev/null || true; done
rm -rf /Applications/LiveTranslate.app

echo "已卸载 LiveTranslate。"
echo "（保留了语音模型 ~/Documents/huggingface 和系统翻译语言包，重装不必重新下载）"
