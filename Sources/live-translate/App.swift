import SwiftUI
import AppKit

@main
struct LiveTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var pipeline = Pipeline()

    var body: some Scene {
        MenuBarExtra {
            ControlPanel(pipeline: pipeline, appDelegate: appDelegate)
                .onAppear { appDelegate.attach(pipeline) }
        } label: {
            Image(nsImage: menuBarIcon())
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

            Picker("方向", selection: $pipeline.mode) {
                Text("自动 外语 → 中").tag("auto")
                Text("日 → 中").tag("ja")
                Text("英 → 中").tag("en")
                Text("中 → 英").tag("zh-en")
                Text("中 → 日").tag("zh-ja")
            }
            .pickerStyle(.menu)
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

            Button {
                appDelegate.showTypeWindow()
            } label: {
                Text("打字翻译…").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .help("打字输入中文，翻成英文 / 日文")

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

/// Hand-drawn menu-bar icon matching the app icon's speaker + sound-wave look,
/// minus the orange squircle. Crisp at small sizes (the squircled PNG gets
/// muddy when scaled to menu-bar height).
private func menuBarIcon() -> NSImage {
    let size: CGFloat = 22
    let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let mid = size / 2

        // speaker (dark gray, same as in the app icon)
        NSColor(white: 0.32, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 2, y: mid - 3, width: 4, height: 6)).fill()
        let flare = NSBezierPath()
        flare.move(to: NSPoint(x: 6,  y: mid - 3))
        flare.line(to: NSPoint(x: 11, y: mid - 7))
        flare.line(to: NSPoint(x: 11, y: mid + 7))
        flare.line(to: NSPoint(x: 6,  y: mid + 3))
        flare.close()
        flare.fill()

        // three sound-wave arcs (teal/cyan, same as app icon)
        NSColor(srgbRed: 0.18, green: 0.65, blue: 0.82, alpha: 1).setStroke()
        for r in [4.5, 7.0, 9.5] as [CGFloat] {
            let arc = NSBezierPath()
            arc.appendArc(withCenter: NSPoint(x: 11, y: mid),
                          radius: r, startAngle: -40, endAngle: 40)
            arc.lineWidth = 1.5
            arc.lineCapStyle = .round
            arc.stroke()
        }
        return true
    }
    img.isTemplate = false   // keep the speaker dark + waves teal
    return img
}
