import Foundation

/// Lightweight diagnostic logger -> /tmp/lt-debug.log so we can inspect the
/// audio/transcribe pipeline state from outside the app during bring-up.
/// (Temporary scaffolding; remove before Phase 5 ship.)
/// Set true to write /tmp/lt-debug.log during development. Off for release.
private let enableDebugLog = false

func dbg(_ s: String) {
    guard enableDebugLog else { return }
    let line = "\(Date().formatted(date: .omitted, time: .standard)) \(s)\n"
    let path = "/tmp/lt-debug.log"
    if let h = FileHandle(forWritingAtPath: path) {
        h.seekToEndOfFile()
        if let d = line.data(using: .utf8) { h.write(d) }
        try? h.close()
    } else {
        try? line.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

/// Strip Whisper control tokens (<|...|>) and non-speech markers ([BLANK_AUDIO], [Music] …)
/// that appear in raw streaming segment text.
func cleanWhisperText(_ s: String) -> String {
    var t = s.replacingOccurrences(of: "<\\|[^|]*\\|>", with: "", options: .regularExpression)
    t = t.replacingOccurrences(of: "\\[[A-Za-z_ ]+\\]", with: "", options: .regularExpression)
    t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return t.trimmingCharacters(in: .whitespacesAndNewlines)
}
