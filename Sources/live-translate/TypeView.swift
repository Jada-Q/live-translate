import SwiftUI
import Translation
import AppKit

/// Type-to-translate window. Uses the dual-session pattern that already works
/// in CaptionBar: two translationTasks with fixed configurations (one EN, one
/// JA) live in parallel, and input is routed to the right stream by current
/// mode. Switching direction doesn't try to rebuild a session — it just routes
/// to the other always-alive session.
@MainActor
final class TypeModel: ObservableObject {
    @Published var input = ""
    @Published var output = ""
    @Published var mode = "zh-en"     // zh-en | zh-ja

    let enRequests: AsyncStream<String>
    let jaRequests: AsyncStream<String>
    private var enCont: AsyncStream<String>.Continuation?
    private var jaCont: AsyncStream<String>.Continuation?
    private var debounceTask: Task<Void, Never>?

    init() {
        var ec: AsyncStream<String>.Continuation!
        enRequests = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { ec = $0 }
        enCont = ec
        var jc: AsyncStream<String>.Continuation!
        jaRequests = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { jc = $0 }
        jaCont = jc
    }

    func onInputChange(_ s: String) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { self.output = ""; return }
            switch self.mode {
            case "zh-ja": self.jaCont?.yield(t)
            default:      self.enCont?.yield(t)
            }
        }
    }

    func apply(_ t: String) { output = t }
    func clear() { input = ""; output = "" }
    func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }
}

struct TypeView: View {
    @StateObject private var model = TypeModel()
    @State private var enConfig: TranslationSession.Configuration?
    @State private var jaConfig: TranslationSession.Configuration?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("方向", selection: $model.mode) {
                    Text("中文 → English").tag("zh-en")
                    Text("中文 → 日本語").tag("zh-ja")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
                Spacer()
                Button("清空") { model.clear() }
                    .disabled(model.input.isEmpty && model.output.isEmpty)
                Button("复制译文") { model.copyOutput() }
                    .disabled(model.output.isEmpty)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("中文").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $model.input)
                        .font(.system(size: 17))
                        .padding(8)
                        .scrollContentBackground(.hidden)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.mode == "zh-ja" ? "日本語" : "English")
                        .font(.caption).foregroundStyle(.secondary)
                    ScrollView {
                        Text(model.output.isEmpty ? "在左边输入中文，会自动翻译…" : model.output)
                            .font(.system(size: 17))
                            .foregroundStyle(model.output.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(8)
                    }
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 360)
        .onAppear {
            enConfig = .init(source: .init(identifier: "zh-Hans"), target: .init(identifier: "en"))
            jaConfig = .init(source: .init(identifier: "zh-Hans"), target: .init(identifier: "ja"))
        }
        .onChange(of: model.input) { _, new in model.onInputChange(new) }
        .onChange(of: model.mode) { _, _ in
            // re-route the current text into the new direction's stream
            model.output = ""
            if !model.input.isEmpty { model.onInputChange(model.input) }
        }
        .translationTask(enConfig) { session in
            for await text in model.enRequests {
                do {
                    let r = try await session.translate(text)
                    if model.mode == "zh-en" { model.apply(r.targetText) }
                } catch { /* skip */ }
            }
        }
        .translationTask(jaConfig) { session in
            for await text in model.jaRequests {
                do {
                    let r = try await session.translate(text)
                    if model.mode == "zh-ja" { model.apply(r.targetText) }
                } catch { /* skip */ }
            }
        }
    }
}
