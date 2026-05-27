import Foundation
import WhisperKit

/// Wraps WhisperKit behind an actor. Returns both the text and the language
/// WhisperKit used/detected, so the pipeline can route to the right translator.
actor Transcriber {
    private var whisper: WhisperKit?
    private(set) var isReady = false

    func load(model: String = "base") async throws {
        let config = WhisperKitConfig(model: model)
        let wk = try await WhisperKit(config)
        try await wk.loadModels()   // load all components incl. tokenizer (streaming needs it eagerly)
        whisper = wk
        isReady = true
    }

    /// Transcribe 16 kHz mono samples. Pass `language` to force it ("en"/"ja"),
    /// or nil to let WhisperKit auto-detect.
    func transcribe(_ samples: [Float], language: String?) async -> (text: String, lang: String) {
        guard let whisper else { return ("", language ?? "en") }
        var opts = DecodingOptions()
        opts.task = .transcribe
        opts.language = language
        do {
            let results = try await whisper.transcribe(audioArray: samples, decodeOptions: opts)
            let text = results
                .map { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let lang = results.first?.language ?? language ?? "en"
            return (text, lang)
        } catch {
            return ("", language ?? "en")
        }
    }

    // MARK: - Streaming (Phase 2 spike)

    private var streamer: AudioStreamTranscriber?

    /// Start real-time streaming transcription. The callback fires on every state
    /// change with the confirmed (stable) text and unconfirmed (live partial) text.
    func startStream(language: String?,
                     onUpdate: @escaping @Sendable (_ confirmed: String, _ partial: String, _ energy: Float) -> Void) async throws {
        guard let whisper, let tokenizer = whisper.tokenizer else {
            throw NSError(domain: "Transcriber", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "模型未就绪"])
        }
        var opts = DecodingOptions()
        opts.task = .transcribe
        opts.language = language

        let st = AudioStreamTranscriber(
            audioEncoder: whisper.audioEncoder,
            featureExtractor: whisper.featureExtractor,
            segmentSeeker: whisper.segmentSeeker,
            textDecoder: whisper.textDecoder,
            tokenizer: tokenizer,
            audioProcessor: whisper.audioProcessor,
            decodingOptions: opts,
            requiredSegmentsForConfirmation: 1,   // default 2 — halves the confirm latency
            silenceThreshold: 0.05,               // default 0.3 is far above this mic's energy (~0.05-0.1)
            useVAD: true,
            stateChangeCallback: { _, newState in
                let confirmed = cleanWhisperText(newState.confirmedSegments.map { $0.text }.joined(separator: " "))
                let partial = cleanWhisperText(newState.unconfirmedSegments.map { $0.text }.joined(separator: " "))
                let energy = newState.bufferEnergy.last ?? 0
                onUpdate(confirmed, partial, energy)
            })
        streamer = st
        try await st.startStreamTranscription()
    }

    func stopStream() async {
        await streamer?.stopStreamTranscription()
        streamer = nil
    }
}
