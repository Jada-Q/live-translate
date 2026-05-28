import SwiftUI
import Translation
import AppKit

/// Type-to-translate window: user types Chinese on the left, translated EN/JA
/// appears on the right, with 350ms debounce so we don't fire a translation per
/// keystroke. Lives in its own NSWindow, separate from the live caption bar.
@MainActor
final class TypeModel: ObservableObject {
    @Published var input = ""
    @Published var output = ""
    @Published var mode = "zh-en"   // zh-en | zh-ja

    let requests: AsyncStream<String>
    private var cont: AsyncStream<String>.Continuation?
    private var debounceTask: Task<Void, Never>?

    init() {
        var c: AsyncStream<String>.Continuation!
        requests = AsyncStream(bufferingPolicy: .bufferingNewest(1)) { c = $0 }
        cont = c
    }

    func onInputChange(_ s: String) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self else { return }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { self.output = ""; return }
            self.cont?.yield(t)
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
    @State private var config: TranslationSession.Configuration?

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
        .onAppear { updateConfig() }
        .onChange(of: model.mode) { _, _ in
            updateConfig()
            // re-translate the current input under the new direction
            if !model.input.isEmpty { model.onInputChange(model.input) }
        }
        .onChange(of: model.input) { _, new in model.onInputChange(new) }
        .translationTask(config) { session in
            for await text in model.requests {
                do {
                    let r = try await session.translate(text)
                    model.apply(r.targetText)
                } catch {
                    model.apply("[翻译失败]")
                }
            }
        }
    }

    private func updateConfig() {
        let target = model.mode == "zh-ja" ? "ja" : "en"
        let new = TranslationSession.Configuration(
            source: Locale.Language(identifier: "zh-Hans"),
            target: Locale.Language(identifier: target))
        // toggle through nil so translationTask tears the old session down and
        // spins up a fresh one for the new direction — otherwise it keeps using
        // the previous direction's session and the translation language doesn't change.
        config = nil
        Task { @MainActor in config = new }
    }
}
