import AppKit

// Renders two static product screenshots for the README:
//   assets/control-panel.png — menu-bar control panel
//   assets/type-translate.png — type-to-translate window
// Hand-drawn to match the actual SwiftUI views, avoids real-window screenshot
// noise (dock, overlapping windows, mouse cursor, light/dark variance).
// Usage: swift screenshots-render.swift <assets-dir>

// MARK: - Drawing helpers

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawText(_ s: String, at p: NSPoint, font: NSFont, color: NSColor) {
    (s as NSString).draw(at: p, withAttributes: [.font: font, .foregroundColor: color])
}

func drawText(_ s: String, in rect: NSRect, font: NSFont, color: NSColor) {
    let para = NSMutableParagraphStyle(); para.lineBreakMode = .byTruncatingTail
    (s as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: para])
}

func textSize(_ s: String, font: NSFont) -> NSSize {
    (s as NSString).size(withAttributes: [.font: font])
}

func save(_ img: NSImage, to path: String) {
    guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try! png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

// brand color (teal/cyan from the app icon's sound waves)
let tealStroke = NSColor(srgbRed: 0.18, green: 0.65, blue: 0.82, alpha: 1)
let tealFill   = NSColor(srgbRed: 0.20, green: 0.66, blue: 0.84, alpha: 1)

// MARK: - menu bar icon (same as the in-app helper)

func drawMenuBarIcon(at origin: NSPoint, scale: CGFloat) {
    let s: CGFloat = 22 * scale
    let mid = s / 2 + origin.y
    NSColor(white: 0.32, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: origin.x + 2*scale, y: mid - 3*scale, width: 4*scale, height: 6*scale)).fill()
    let flare = NSBezierPath()
    flare.move(to: NSPoint(x: origin.x + 6*scale,  y: mid - 3*scale))
    flare.line(to: NSPoint(x: origin.x + 11*scale, y: mid - 7*scale))
    flare.line(to: NSPoint(x: origin.x + 11*scale, y: mid + 7*scale))
    flare.line(to: NSPoint(x: origin.x + 6*scale,  y: mid + 3*scale))
    flare.close()
    flare.fill()
    tealStroke.setStroke()
    for r in [4.5, 7.0, 9.5] as [CGFloat] {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: NSPoint(x: origin.x + 11*scale, y: mid),
                      radius: r*scale, startAngle: -40, endAngle: 40)
        arc.lineWidth = 1.5 * scale
        arc.lineCapStyle = .round
        arc.stroke()
    }
}

// MARK: - Control panel screenshot

func renderControlPanel(to outPath: String) {
    let W: CGFloat = 320, H: CGFloat = 340
    let img = NSImage(size: NSSize(width: W, height: H))
    img.lockFocus()

    // window background
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
    roundedRect(NSRect(x: 0, y: 0, width: W, height: H), radius: 14).fill()

    let pad: CGFloat = 20
    var y = H - pad - 22                  // top-down layout

    // title with menu-bar icon to the left
    drawMenuBarIcon(at: NSPoint(x: pad, y: y - 1), scale: 1.0)
    drawText("现场翻译", at: NSPoint(x: pad + 30, y: y),
             font: .systemFont(ofSize: 16, weight: .semibold),
             color: NSColor(white: 0.1, alpha: 1))
    y -= 32

    // direction picker (menu style)
    let pickerRect = NSRect(x: pad, y: y - 26, width: W - 2*pad, height: 28)
    NSColor.white.setFill(); roundedRect(pickerRect, radius: 6).fill()
    NSColor(white: 0.85, alpha: 1).setStroke()
    let pickerStroke = roundedRect(pickerRect, radius: 6); pickerStroke.lineWidth = 1; pickerStroke.stroke()
    drawText("自动 外语 → 中", at: NSPoint(x: pad + 10, y: y - 21),
             font: .systemFont(ofSize: 13), color: NSColor(white: 0.15, alpha: 1))
    drawText("⌄", at: NSPoint(x: pickerRect.maxX - 18, y: y - 23),
             font: .systemFont(ofSize: 13), color: NSColor(white: 0.4, alpha: 1))
    y -= 40

    // status row
    NSColor(white: 0.55, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: pad, y: y - 4, width: 8, height: 8)).fill()
    drawText("就绪 — 点开始录音", at: NSPoint(x: pad + 14, y: y - 7),
             font: .systemFont(ofSize: 12), color: NSColor(white: 0.45, alpha: 1))
    y -= 22

    // big start button
    let btnRect = NSRect(x: pad, y: y - 36, width: W - 2*pad, height: 36)
    NSColor.systemBlue.setFill(); roundedRect(btnRect, radius: 8).fill()
    let bs = textSize("开始翻译", font: .systemFont(ofSize: 14, weight: .medium))
    drawText("开始翻译", at: NSPoint(x: btnRect.midX - bs.width/2, y: btnRect.midY - bs.height/2),
             font: .systemFont(ofSize: 14, weight: .medium), color: .white)
    y -= 48

    // type-translate button
    let typeBtn = NSRect(x: pad, y: y - 28, width: W - 2*pad, height: 28)
    NSColor.white.setFill(); roundedRect(typeBtn, radius: 6).fill()
    NSColor(white: 0.85, alpha: 1).setStroke()
    let ts = roundedRect(typeBtn, radius: 6); ts.lineWidth = 1; ts.stroke()
    let ttSize = textSize("打字翻译…", font: .systemFont(ofSize: 13))
    drawText("打字翻译…", at: NSPoint(x: typeBtn.midX - ttSize.width/2, y: typeBtn.midY - ttSize.height/2),
             font: .systemFont(ofSize: 13), color: NSColor.systemBlue)
    y -= 38

    // mini actions row
    let small = NSFont.systemFont(ofSize: 11)
    drawText("显示/隐藏字幕条", at: NSPoint(x: pad, y: y - 12), font: small, color: NSColor.systemBlue)
    let clearSize = textSize("清空", font: small)
    drawText("清空", at: NSPoint(x: W - pad - clearSize.width, y: y - 12), font: small, color: NSColor.systemBlue)
    y -= 24

    // divider
    NSColor(white: 0.85, alpha: 1).setFill()
    NSRect(x: pad, y: y, width: W - 2*pad, height: 1).fill()
    y -= 16

    // quit
    drawText("退出", at: NSPoint(x: pad, y: y - 12), font: small, color: NSColor(white: 0.5, alpha: 1))

    img.unlockFocus()
    save(img, to: outPath)
}

// MARK: - Type-to-translate window screenshot

func renderTypeTranslate(to outPath: String) {
    let W: CGFloat = 800, H: CGFloat = 440
    let img = NSImage(size: NSSize(width: W, height: H))
    img.lockFocus()

    // window background
    NSColor(calibratedWhite: 0.93, alpha: 1).setFill()
    roundedRect(NSRect(x: 0, y: 0, width: W, height: H), radius: 10).fill()

    // title bar
    let tbH: CGFloat = 36
    NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
    let tbPath = NSBezierPath()
    tbPath.move(to: NSPoint(x: 0, y: H - tbH))
    tbPath.line(to: NSPoint(x: 0, y: H - 10))
    tbPath.appendArc(withCenter: NSPoint(x: 10, y: H - 10), radius: 10, startAngle: 180, endAngle: 90, clockwise: true)
    tbPath.line(to: NSPoint(x: W - 10, y: H))
    tbPath.appendArc(withCenter: NSPoint(x: W - 10, y: H - 10), radius: 10, startAngle: 90, endAngle: 0, clockwise: true)
    tbPath.line(to: NSPoint(x: W, y: H - tbH))
    tbPath.close()
    tbPath.fill()
    // traffic lights
    for (i, c) in [NSColor(srgbRed:1,green:0.37,blue:0.36,alpha:1),
                   NSColor(srgbRed:1,green:0.74,blue:0.18,alpha:1),
                   NSColor(srgbRed:0.27,green:0.81,blue:0.27,alpha:1)].enumerated() {
        c.setFill()
        NSBezierPath(ovalIn: NSRect(x: 14 + CGFloat(i) * 20, y: H - tbH/2 - 6, width: 12, height: 12)).fill()
    }
    // window title
    let title = "打字翻译 · 中 → 英 / 日"
    let ts = textSize(title, font: .systemFont(ofSize: 13, weight: .semibold))
    drawText(title, at: NSPoint(x: W/2 - ts.width/2, y: H - tbH/2 - ts.height/2),
             font: .systemFont(ofSize: 13, weight: .semibold), color: NSColor(white: 0.2, alpha: 1))

    // content area
    let pad: CGFloat = 18
    let topY = H - tbH - pad

    // segmented picker (zh-en | zh-ja), zh-ja highlighted
    let pickerH: CGFloat = 28
    let pickerW: CGFloat = 320
    let pickerRect = NSRect(x: pad, y: topY - pickerH, width: pickerW, height: pickerH)
    NSColor(calibratedWhite: 0.84, alpha: 1).setFill()
    roundedRect(pickerRect, radius: 7).fill()
    let segW = pickerW / 2
    // highlight zh-ja (right segment)
    NSColor.white.setFill()
    let highlight = roundedRect(NSRect(x: pickerRect.minX + segW + 2, y: pickerRect.minY + 2,
                                       width: segW - 4, height: pickerH - 4), radius: 6)
    highlight.fill()
    // labels
    let segFont = NSFont.systemFont(ofSize: 12, weight: .medium)
    let leftLabel = "中文 → English", rightLabel = "中文 → 日本語"
    let ll = textSize(leftLabel, font: segFont), rl = textSize(rightLabel, font: segFont)
    drawText(leftLabel,  at: NSPoint(x: pickerRect.minX + segW/2 - ll.width/2, y: pickerRect.midY - ll.height/2),
             font: segFont, color: NSColor(white: 0.4, alpha: 1))
    drawText(rightLabel, at: NSPoint(x: pickerRect.minX + segW + segW/2 - rl.width/2, y: pickerRect.midY - rl.height/2),
             font: segFont, color: NSColor(white: 0.15, alpha: 1))

    // right-aligned action buttons
    func drawSmallButton(_ label: String, rightEdge: CGFloat) -> CGFloat {
        let s = textSize(label, font: .systemFont(ofSize: 12))
        let bw = s.width + 20, bh: CGFloat = 26
        let rect = NSRect(x: rightEdge - bw, y: topY - bh, width: bw, height: bh)
        NSColor.white.setFill(); roundedRect(rect, radius: 6).fill()
        NSColor(white: 0.82, alpha: 1).setStroke()
        let st = roundedRect(rect, radius: 6); st.lineWidth = 1; st.stroke()
        drawText(label, at: NSPoint(x: rect.midX - s.width/2, y: rect.midY - s.height/2),
                 font: .systemFont(ofSize: 12), color: NSColor(white: 0.2, alpha: 1))
        return rect.minX - 8
    }
    var rightEdge = W - pad
    rightEdge = drawSmallButton("复制译文", rightEdge: rightEdge)
    _        = drawSmallButton("清空",     rightEdge: rightEdge)

    // body: two panes
    let bodyTop = topY - pickerH - 16
    let bodyH = bodyTop - pad
    let midX = W / 2 + 6
    let leftRect  = NSRect(x: pad, y: pad + 20, width: midX - pad - 16, height: bodyH - 20)
    let rightRect = NSRect(x: midX + 8, y: pad + 20, width: W - pad - midX - 8, height: bodyH - 20)

    // labels above panes
    drawText("中文",  at: NSPoint(x: leftRect.minX, y: leftRect.maxY + 2),
             font: .systemFont(ofSize: 11), color: NSColor(white: 0.5, alpha: 1))
    drawText("日本語", at: NSPoint(x: rightRect.minX, y: rightRect.maxY + 2),
             font: .systemFont(ofSize: 11), color: NSColor(white: 0.5, alpha: 1))

    // left pane: chinese input
    NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
    roundedRect(leftRect, radius: 8).fill()
    let zh = "你好，今天过得怎么样？\n下午一起喝杯咖啡吗？"
    let zhFont = NSFont.systemFont(ofSize: 17)
    let para = NSMutableParagraphStyle(); para.lineSpacing = 6
    (zh as NSString).draw(in: leftRect.insetBy(dx: 12, dy: 10),
                          withAttributes: [.font: zhFont,
                                           .foregroundColor: NSColor(white: 0.12, alpha: 1),
                                           .paragraphStyle: para])

    // divider between panes
    NSColor(white: 0.82, alpha: 1).setFill()
    NSRect(x: midX, y: rightRect.minY, width: 1, height: rightRect.height).fill()

    // right pane: japanese translation
    NSColor(calibratedWhite: 0.88, alpha: 1).setFill()
    roundedRect(rightRect, radius: 8).fill()
    let ja = "こんにちは、今日は元気ですか？\n午後、一緒にコーヒーを飲みませんか？"
    (ja as NSString).draw(in: rightRect.insetBy(dx: 12, dy: 10),
                          withAttributes: [.font: zhFont,
                                           .foregroundColor: NSColor(white: 0.12, alpha: 1),
                                           .paragraphStyle: para])

    img.unlockFocus()
    save(img, to: outPath)
}

// MARK: - main

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets"
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
renderControlPanel(to:  "\(outDir)/control-panel.png")
renderTypeTranslate(to: "\(outDir)/type-translate.png")
