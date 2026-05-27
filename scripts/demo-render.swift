import AppKit

// Renders a sequence of frames simulating the live caption bar:
// confirmed bilingual blocks appear one by one, a faint "识别中" partial line
// builds up, and the waveform animates. ffmpeg stitches these into demo.gif.
// Usage: swift demo-render.swift <out-dir>

let W: CGFloat = 720
let H: CGFloat = 340
let pad: CGFloat = 24

struct Block { let src: String; let dst: String }
let convo: [(src: String, dst: String, partials: [String])] = [
    ("How are you today?",        "你今天过得怎么样？",   ["How are", "How are you today?"]),
    ("I'm building a new app.",   "我在做一个新 app。",   ["I'm building", "I'm building a new app."]),
    ("It translates speech live.","它能实时翻译语音。",   ["It translates", "It translates speech live."]),
]

// Build a timeline of frames: each frame = (confirmed blocks, current partial)
struct State { var blocks: [Block]; var partial: String }
var timeline: [State] = []
func hold(_ s: State, _ n: Int) { for _ in 0..<n { timeline.append(s) } }

var confirmed: [Block] = []
hold(State(blocks: [], partial: ""), 4)                 // "正在听…"
for line in convo {
    for p in line.partials { hold(State(blocks: confirmed, partial: p), 3) }   // 识别中…
    confirmed.append(Block(src: line.src, dst: line.dst))
    hold(State(blocks: confirmed, partial: ""), 5)      // block lands
}
hold(State(blocks: confirmed, partial: ""), 8)          // end hold

func draw(_ state: State, frame: Int) -> NSImage {
    let img = NSImage(size: NSSize(width: W, height: H))
    img.lockFocus()

    // bar background (light translucent material look)
    let bg = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: W, height: H), xRadius: 18, yRadius: 18)
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill(); bg.fill()

    let recording = !state.partial.isEmpty || !state.blocks.isEmpty
    // top control row (drawn from top in flipped sense: y is from bottom)
    let topY = H - pad - 18
    // record dot
    let dot = NSBezierPath(ovalIn: NSRect(x: pad, y: topY, width: 14, height: 14))
    (recording ? NSColor.systemRed : NSColor(white: 0.7, alpha: 1)).setFill(); dot.fill()
    // waveform bars
    let factors: [CGFloat] = [0.4, 0.65, 0.9, 1.0, 0.75, 1.0, 0.9, 0.65, 0.4]
    NSColor.systemGreen.setFill()
    for i in 0..<factors.count {
        let amp = recording ? (0.4 + 0.6 * abs(sin(Double(frame) * 0.6 + Double(i) * 0.7))) : 0.15
        let h = CGFloat(amp) * 22 * factors[i]
        let x = pad + 26 + CGFloat(i) * 7
        let r = NSRect(x: x, y: topY + 7 - h/2, width: 3.5, height: max(3, h))
        NSBezierPath(roundedRect: r, xRadius: 1.75, yRadius: 1.75).fill()
    }
    // right label
    let labelAttr: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: NSColor(white: 0.55, alpha: 1)]
    let label = "自动识别 ｜ 原文 · 译文" as NSString
    let lsize = label.size(withAttributes: labelAttr)
    label.draw(at: NSPoint(x: W - pad - lsize.width, y: topY), withAttributes: labelAttr)

    // blocks (newest at bottom of list area, show last 3)
    let shown = Array(state.blocks.suffix(3))
    let srcFont = NSFont.systemFont(ofSize: 17)
    let dstFont = NSFont.systemFont(ofSize: 21, weight: .medium)
    let rowH: CGFloat = 52
    let listTop = topY - 24
    let midX = W / 2 + 6
    if shown.isEmpty {
        let ph = (recording ? "正在听…说一句，原文和译文会一起出现" : "点 ▶ 开始") as NSString
        ph.draw(at: NSPoint(x: pad, y: listTop - 34),
                withAttributes: [.font: NSFont.systemFont(ofSize: 18),
                                 .foregroundColor: NSColor(white: 0.55, alpha: 1)])
    } else {
        for (i, b) in shown.enumerated() {
            let y = listTop - CGFloat(i + 1) * rowH
            let dim = (i == shown.count - 1) ? 1.0 : 0.45
            let src = b.src as NSString
            src.draw(in: NSRect(x: pad, y: y, width: midX - pad - 16, height: rowH - 8),
                     withAttributes: [.font: srcFont,
                                      .foregroundColor: NSColor(white: 0.45, alpha: CGFloat(dim))])
            // divider
            NSColor(white: 0.8, alpha: CGFloat(dim)).setFill()
            NSRect(x: midX - 8, y: y + 6, width: 1, height: rowH - 16).fill()
            let dst = b.dst as NSString
            dst.draw(in: NSRect(x: midX + 8, y: y, width: W - pad - midX - 8, height: rowH - 4),
                     withAttributes: [.font: dstFont,
                                      .foregroundColor: NSColor(white: 0.12, alpha: CGFloat(dim))])
        }
    }

    // faint "识别中" partial line at the bottom
    if !state.partial.isEmpty {
        let t = "识别中：\(state.partial)" as NSString
        t.draw(at: NSPoint(x: pad, y: pad - 6),
               withAttributes: [.font: NSFont.systemFont(ofSize: 13),
                                .foregroundColor: NSColor(white: 0.62, alpha: 1)])
    }

    img.unlockFocus()
    return img
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/lt-demo-frames"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (idx, st) in timeline.enumerated() {
    let img = draw(st, frame: idx)
    guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    let name = String(format: "frame_%03d.png", idx)
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("rendered \(timeline.count) frames to \(outDir)")
