import SwiftUI
import Translation

/// Framework A — paired bilingual blocks. Instead of a fast-scrolling source
/// stream racing a lagging translation stream, each confirmed chunk becomes a
/// block (source + its translation) that appears together, like bilingual
/// subtitles. A faint "识别中" line shows the live partial as low-key feedback.
@MainActor
final class Pipeline: ObservableObject {
    struct Block: Identifiable {
        let id = UUID()
        let source: String
        var translation: String
    }

    @Published var blocks: [Block] = []
    @Published var partialText = ""       // live partial, shown faintly
    @Published var isRecording = false
    @Published var modelReady = false
    @Published var status = "正在加载语音模型…"
    @Published var mode = "auto"          // "auto" | "ja" | "en"
    @Published var audioLevel: Float = 0

    private let transcriber = Transcriber()
    private var lastConfirmed = ""
    private var pendingChunk = ""

    struct TranslationRequest: Sendable { let id: UUID; let text: String }
    let enRequests: AsyncStream<TranslationRequest>
    let jaRequests: AsyncStream<TranslationRequest>
    private var enCont: AsyncStream<TranslationRequest>.Continuation?
    private var jaCont: AsyncStream<TranslationRequest>.Continuation?

    init() {
        var ec: AsyncStream<TranslationRequest>.Continuation!
        enRequests = AsyncStream(bufferingPolicy: .unbounded) { ec = $0 }
        enCont = ec
        var jc: AsyncStream<TranslationRequest>.Continuation!
        jaRequests = AsyncStream(bufferingPolicy: .unbounded) { jc = $0 }
        jaCont = jc
        Task { await loadModel() }
    }

    private func loadModel() async {
        do {
            try await transcriber.load(model: "base")
            modelReady = true
            status = "就绪 — 点开始录音"
            dbg("whisper model loaded ✓")
        } catch {
            status = "模型加载失败：\(error.localizedDescription)"
            dbg("model load failed: \(error)")
        }
    }

    func toggle() {
        if isRecording { Task { await stop() } } else { Task { await start() } }
    }

    func start() async {
        guard modelReady else { dbg("start ignored: model not ready"); return }
        blocks = []; partialText = ""; lastConfirmed = ""; pendingChunk = ""
        do {
            try await transcriber.startStream(language: mode == "auto" ? nil : mode) { [weak self] confirmed, partial, energy in
                Task { @MainActor in self?.onStreamUpdate(confirmed: confirmed, partial: partial, energy: energy) }
            }
            isRecording = true
            status = "录音中（\(modeLabel)）"
            dbg("stream started, mode=\(mode)")
        } catch {
            status = "录音启动失败：\(error.localizedDescription)"
            dbg("startStream failed: \(error)")
        }
    }

    func stop() async {
        flushPending(force: true)
        await transcriber.stopStream()
        isRecording = false
        audioLevel = 0
        partialText = ""
        status = "已停止"
        dbg("stream stopped")
    }

    func clear() {
        blocks = []; partialText = ""; lastConfirmed = ""; pendingChunk = ""
    }

    var modeLabel: String {
        switch mode {
        case "ja": return "日→中"
        case "en": return "英→中"
        default: return "自动识别"
        }
    }

    private func onStreamUpdate(confirmed: String, partial: String, energy: Float) {
        audioLevel = energy
        partialText = Pipeline.isNonSpeech(partial) ? "" : partial

        if confirmed.hasPrefix(lastConfirmed), confirmed.count > lastConfirmed.count {
            pendingChunk += String(confirmed.dropFirst(lastConfirmed.count))
            lastConfirmed = confirmed
            flushPending()
        } else if !confirmed.hasPrefix(lastConfirmed) {
            lastConfirmed = confirmed
        }
        if partial.isEmpty { flushPending(force: true) }
    }

    /// Turn an accumulated sentence-sized chunk into a paired block + queue its translation.
    private func flushPending(force: Bool = false) {
        let trimmed = pendingChunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let endsSentence = trimmed.last.map { ".。!！?？,，;；".contains($0) } ?? false
        guard force || endsSentence || trimmed.count >= 28 else { return }
        pendingChunk = ""
        guard !Pipeline.isNonSpeech(trimmed) else { return }

        let block = Block(source: trimmed, translation: "…")
        blocks.append(block)
        if blocks.count > 60 { blocks.removeFirst(blocks.count - 60) }

        let lang = mode == "auto" ? Pipeline.detectLang(trimmed) : mode
        let req = TranslationRequest(id: block.id, text: trimmed)
        if lang == "ja" { jaCont?.yield(req) } else { enCont?.yield(req) }
        dbg("block -> \(lang): '\(trimmed.suffix(40))'")
    }

    func applyTranslation(id: UUID, text: String) {
        if let i = blocks.firstIndex(where: { $0.id == id }) {
            blocks[i].translation = text
        }
    }

    static func detectLang(_ s: String) -> String {
        for u in s.unicodeScalars where (0x3040...0x30FF).contains(u.value) { return "ja" }
        return "en"
    }

    static func isNonSpeech(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first, let last = t.last else { return true }
        let opens: Set<Character> = ["(", "（", "[", "【", "<"]
        let closes: Set<Character> = [")", "）", "]", "】", ">"]
        return opens.contains(first) && closes.contains(last)
    }
}
