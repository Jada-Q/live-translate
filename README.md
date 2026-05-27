# LiveTranslate · 现场翻译

菜单栏小工具：现场把**英文 / 日文语音**实时转成文字并翻译成**中文**，显示在一个置顶的浮动字幕条上。**全程本地运行，不上传任何音频或文字。**

适合：和人现场对话、开会、听无字幕的讲座 / 直播时，边听边看中文。

## 功能

- 🎙 **现场实时**：流式语音识别，原文边说边出现
- 🌏 **自动识别语言**：英 / 日自动判断，也可手动锁定
- 🪟 **浮动字幕条**：置顶、跨所有窗口、可拖动，原文 + 译文配对成块出现（像双语字幕）
- 🔒 **完全本地**：语音识别（WhisperKit / Apple Neural Engine）+ 翻译（Apple 系统翻译）都在本机，离线可用
- 📊 录音状态指示 + 实时音量波形

## 安装

```bash
bash scripts/install.sh
```

会自动：release 编译 → 打包 → 装进 `/Applications` → 配置开机自启 + 崩溃自愈。

装好后菜单栏右上角出现波形图标，点它 → 选语言 → 「开始翻译」→ 浮动字幕条出现。

**首次使用**：
- 会请求**麦克风权限** → 允许
- 首次某语言对翻译时，系统会提示**下载翻译语言包**（一次性，之后离线）
- 首次启动会下载一个小的 Whisper 语音模型（~150MB，一次性）

卸载：`bash scripts/uninstall.sh`

## 关于"滞后"

现场实时翻译**必然有 2-4 秒滞后**，这是专业同传译员的水平（研究里叫 ear-voice span）——因为准确翻译必须等一句话语义相对完整，看不到"未来"的话。这是物理规律，不是 bug。字幕条用"原文译文配对成块出现"的设计，让这个滞后在视觉上尽量自然。

> YouTube 等视频翻译插件之所以又快又准，是因为它们处理的是**录播**（字幕现成、能看到整段、可离线慢慢翻），和现场直播是两个不同的问题。

## 技术栈

| 环节 | 用什么 |
|---|---|
| 语音识别 | [WhisperKit](https://github.com/argmaxinc/WhisperKit)（本地 Whisper，跑在 Apple Neural Engine） |
| 翻译 | Apple `Translation` framework（macOS 15+ 系统级本地翻译） |
| 音频 | `AVAudioEngine` / WhisperKit `AudioStreamTranscriber`（自带 VAD） |
| 界面 | SwiftUI `MenuBarExtra` + 浮动 `NSPanel` |
| 常驻 | launchd KeepAlive（开机自启 + 崩溃自愈） |

要求：**macOS 15 (Sequoia) 或更新**（Apple Translation 框架需要）、Apple Silicon。

## 本地开发

```bash
swift build                 # 编译
bash scripts/make-app.sh    # 打包成 build/LiveTranslate.app
open build/LiveTranslate.app
```

调试日志：把 `Sources/live-translate/Debug.swift` 里的 `enableDebugLog` 改为 `true`，日志写到 `/tmp/lt-debug.log`。
