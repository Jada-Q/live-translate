import SwiftUI
import Translation

/// Framework A caption bar: paired bilingual blocks appear together (source |
/// translation), like subtitles. A faint "识别中" line shows the live partial.
/// Two translationTasks (EN→ZH, JA→ZH) drain the routed queues by block id.
struct CaptionBar: View {
    @ObservedObject var pipeline: Pipeline
    var onClose: () -> Void
    @State private var enConfig: TranslationSession.Configuration?
    @State private var jaConfig: TranslationSession.Configuration?
    @State private var zhEnConfig: TranslationSession.Configuration?
    @State private var zhJaConfig: TranslationSession.Configuration?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            controlRow
            blockList
            partialHint
        }
        .padding(16)
        .frame(width: 680, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onAppear {
            enConfig = .init(source: .init(identifier: "en"), target: .init(identifier: "zh-Hans"))
            jaConfig = .init(source: .init(identifier: "ja"), target: .init(identifier: "zh-Hans"))
            zhEnConfig = .init(source: .init(identifier: "zh-Hans"), target: .init(identifier: "en"))
            zhJaConfig = .init(source: .init(identifier: "zh-Hans"), target: .init(identifier: "ja"))
        }
        .translationTask(enConfig) { session in
            for await req in pipeline.enRequests {
                do {
                    let r = try await session.translate(req.text)
                    pipeline.applyTranslation(id: req.id, text: r.targetText)
                } catch { dbg("en FAILED: \(error)") }
            }
        }
        .translationTask(jaConfig) { session in
            for await req in pipeline.jaRequests {
                do {
                    let r = try await session.translate(req.text)
                    pipeline.applyTranslation(id: req.id, text: r.targetText)
                } catch { dbg("ja FAILED: \(error)") }
            }
        }
        .translationTask(zhEnConfig) { session in
            for await req in pipeline.zhEnRequests {
                do {
                    let r = try await session.translate(req.text)
                    pipeline.applyTranslation(id: req.id, text: r.targetText)
                } catch { dbg("zh-en FAILED: \(error)") }
            }
        }
        .translationTask(zhJaConfig) { session in
            for await req in pipeline.zhJaRequests {
                do {
                    let r = try await session.translate(req.text)
                    pipeline.applyTranslation(id: req.id, text: r.targetText)
                } catch { dbg("zh-ja FAILED: \(error)") }
            }
        }
    }

    @ViewBuilder
    private var blockList: some View {
        if pipeline.blocks.isEmpty {
            Text(placeholder)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(pipeline.blocks.suffix(3).enumerated()), id: \.element.id) { idx, block in
                    HStack(alignment: .top, spacing: 14) {
                        Text(block.source)
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Divider()
                        Text(block.translation)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    // older blocks dimmed so the newest reads as current
                    .opacity(idx == pipeline.blocks.suffix(3).count - 1 ? 1.0 : 0.5)
                }
            }
        }
    }

    @ViewBuilder
    private var partialHint: some View {
        if pipeline.isRecording && !pipeline.partialText.isEmpty {
            Text("识别中：\(pipeline.partialText)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var controlRow: some View {
        HStack(spacing: 10) {
            Button {
                pipeline.toggle()
            } label: {
                Image(systemName: pipeline.isRecording ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(pipeline.isRecording ? Color.red : Color.green)
            }
            .buttonStyle(.plain)
            .help(pipeline.isRecording ? "停止" : "开始")

            WaveformView(level: pipeline.audioLevel, active: pipeline.isRecording)

            Spacer()

            Text("\(pipeline.modeLabel) ｜ 原文 · 译文")
                .font(.caption2).foregroundStyle(.secondary)

            Button {
                Task { await pipeline.stop(); onClose() }
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭")
        }
    }

    private var placeholder: String {
        if !pipeline.modelReady { return "正在加载语音模型…" }
        return pipeline.isRecording ? "正在听…说一句，原文和译文会一起出现" : "点左边绿色 ▶ 开始"
    }
}

/// Waveform meter driven by the live RMS/energy level.
struct WaveformView: View {
    var level: Float
    var active: Bool
    private let factors: [CGFloat] = [0.4, 0.65, 0.9, 1.0, 0.75, 1.0, 0.9, 0.65, 0.4]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(factors.indices, id: \.self) { i in
                Capsule().frame(width: 3, height: height(i))
            }
        }
        .frame(height: 24)
        .foregroundStyle(active ? Color.green : Color.secondary.opacity(0.4))
        .animation(.easeOut(duration: 0.1), value: level)
    }

    private func height(_ i: Int) -> CGFloat {
        guard active else { return 3 }
        let norm = (CGFloat(min(max(level * 25, 0), 1))).squareRoot()
        return max(3, norm * 24 * factors[i])
    }
}
