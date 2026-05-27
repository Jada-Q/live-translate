import SwiftUI
import AppKit

@main
struct LiveTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var pipeline = Pipeline()

    var body: some Scene {
        MenuBarExtra("现场翻译", systemImage: pipeline.isRecording ? "waveform.circle.fill" : "waveform") {
            ControlPanel(pipeline: pipeline, appDelegate: appDelegate)
                .onAppear { appDelegate.attach(pipeline) }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu-bar dropdown: mode (auto/ja/en), start/stop, show/hide caption bar, clear, quit.
struct ControlPanel: View {
    @ObservedObject var pipeline: Pipeline
    let appDelegate: AppDelegate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("现场翻译").font(.headline)

            Picker("", selection: $pipeline.mode) {
                Text("自动").tag("auto")
                Text("日→中").tag("ja")
                Text("英→中").tag("en")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack(spacing: 6) {
                Circle()
                    .fill(pipeline.isRecording ? Color.red : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(pipeline.status)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            Button {
                if pipeline.isRecording {
                    pipeline.toggle()
                } else {
                    appDelegate.showCaption()
                    pipeline.toggle()
                }
            } label: {
                Text(pipeline.isRecording ? "停止翻译" : "开始翻译")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(!pipeline.modelReady)

            HStack {
                Button("显示/隐藏字幕条") { appDelegate.toggleCaption() }
                Spacer()
                Button("清空") { pipeline.clear() }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            Divider()

            Button("退出") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 260)
    }
}
