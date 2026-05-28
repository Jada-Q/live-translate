import SwiftUI
import Translation

/// Framework A — paired bilingual blocks. Each confirmed chunk becomes a block
/// (source + translation) appearing together, like subtitles.
///
/// Direction modes:
///   auto  : EN/JA → ZH (detect source per chunk)
///   ja/en : JA→ZH / EN→ZH
///   zh-en : ZH → EN
///   zh-ja : ZH → JA
/// One translationTask per language pair (a session is only valid in its own
/// closure); chunks are routed to the matching queue.
@MainActor
final class Pipeline: ObservableObject {
    struct Block: Identifiable {
        let id = UUID()
        let source: String
        var translation: String
    }

    @Published var blocks: [Block] = []
    @Published var partialText = ""
    @Published var isRecording = false
    @Published var modelReady = false
    @Published var status = "正在加载语音模型…"
    @Published var mode = "auto"          // auto | ja | en | zh-en | zh-ja
    @Published var audioLevel: Float = 0

    private let transcriber = Transcriber()
    private var lastConfirmed = ""
    private var pendingChunk = ""

    struct TranslationRequest: Sendable { let id: UUID; let text: String }
    let enRequests: AsyncStream<TranslationRequest>     // EN → ZH
    let jaRequests: AsyncStream<TranslationRequest>     // JA → ZH
    let zhEnRequests: AsyncStream<TranslationRequest>   // ZH → EN
    let zhJaRequests: AsyncStream<TranslationRequest>   // ZH → JA
    private var enCont: AsyncStream<TranslationRequest>.Continuation?
    private var jaCont: AsyncStream<TranslationRequest>.Continuation?
    private var zhEnCont: AsyncStream<TranslationRequest>.Continuation?
    private var zhJaCont: AsyncStream<TranslationRequest>.Continuation?

    init() {
        func makeStream() -> (AsyncStream<TranslationRequest>, AsyncStream<TranslationRequest>.Continuation) {
            var c: AsyncStream<TranslationRequest>.Continuation!
            let s = AsyncStream<TranslationRequest>(bufferingPolicy: .unbounded) { c = $0 }
            return (s, c)
        }
        (enRequests, enCont) = makeStream()
        (jaRequests, jaCont) = makeStream()
        (zhEnRequests, zhEnCont) = makeStream()
        (zhJaRequests, zhJaCont) = makeStream()
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

    /// What language WhisperKit should transcribe in for the current direction.
    private func transcribeLanguage() -> String? {
        switch mode {
        case "auto": return nil          // detect EN/JA
        case "zh-en", "zh-ja": return "zh"
        default: return mode             // "ja" or "en"
        }
    }

    func start() async {
        guard modelReady else { dbg("start ignored: model not ready"); return }
        blocks = []; partialText = ""; lastConfirmed = ""; pendingChunk = ""
        do {
            try await transcriber.startStream(language: transcribeLanguage()) { [weak self] confirmed, partial, energy in
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
        case "zh-en": return "中→英"
        case "zh-ja": return "中→日"
        default: return "自动 外→中"
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

    private func flushPending(force: Bool = false) {
        let raw = pendingChunk.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmed = Pipeline.dedupRepeats(raw)
        guard !trimmed.isEmpty else { return }
        let endsSentence = trimmed.last.map { ".。!！?？,，;；".contains($0) } ?? false
        guard force || endsSentence || trimmed.count >= 28 else { return }
        pendingChunk = ""
        guard !Pipeline.isNonSpeech(trimmed) else { return }
        // streaming confirmed text oscillates and re-emits the same chunk — skip recent duplicates
        if blocks.suffix(4).contains(where: { $0.source == trimmed }) { return }

        let block = Block(source: trimmed, translation: "…")
        blocks.append(block)
        if blocks.count > 60 { blocks.removeFirst(blocks.count - 60) }

        let req = TranslationRequest(id: block.id, text: trimmed)
        switch mode {
        case "zh-en": zhEnCont?.yield(req)
        case "zh-ja": zhJaCont?.yield(req)
        case "ja": jaCont?.yield(req)
        case "en": enCont?.yield(req)
        default: // auto
            if Pipeline.detectLang(trimmed) == "ja" { jaCont?.yield(req) } else { enCont?.yield(req) }
        }
        dbg("block -> \(mode): '\(trimmed.suffix(40))'")
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

    /// Collapse Whisper's streaming repetition hallucination: split on punctuation/
    /// spaces and drop consecutive duplicate segments ("A,A,A,B" → "A,B").
    static func dedupRepeats(_ s: String) -> String {
        let seps = CharacterSet(charactersIn: ",，.。!！?？、;；　 ")
        let parts = s.components(separatedBy: seps)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var out: [String] = []
        for p in parts where out.last != p { out.append(p) }
        return out.joined(separator: " ")
    }

    static func isNonSpeech(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = t.first, let last = t.last else { return true }
        let opens: Set<Character> = ["(", "（", "[", "【", "<"]
        let closes: Set<Character> = [")", "）", "]", "】", ">"]
        return opens.contains(first) && closes.contains(last)
    }
}
