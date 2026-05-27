import AppKit

// Renders a 1024×1024 app icon: rounded-rect blue→teal gradient + white waveform bars.
// Usage: swift icon-render.swift <out.png>

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()

let inset: CGFloat = S * 0.06
let bgRect = NSRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let bg = NSBezierPath(roundedRect: bgRect, xRadius: S * 0.2, yRadius: S * 0.2)
bg.addClip()

let grad = NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.52, blue: 0.96, alpha: 1),
                      ending:   NSColor(srgbRed: 0.10, green: 0.78, blue: 0.74, alpha: 1))!
grad.draw(in: bg, angle: -90)

// waveform / equalizer bars
let heights: [CGFloat] = [0.26, 0.46, 0.66, 0.40, 0.26]
let barCount = heights.count
let barW: CGFloat = S * 0.075
let gap: CGFloat = S * 0.052
let totalW = CGFloat(barCount) * barW + CGFloat(barCount - 1) * gap
let startX = (S - totalW) / 2

NSColor.white.setFill()
for (i, hf) in heights.enumerated() {
    let h = S * hf
    let x = startX + CGFloat(i) * (barW + gap)
    let y = (S - h) / 2
    let bar = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barW, height: h),
                           xRadius: barW / 2, yRadius: barW / 2)
    bar.fill()
}

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render\n".data(using: .utf8)!)
    exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/icon1024.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
