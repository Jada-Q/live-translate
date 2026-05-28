import AppKit
import SwiftUI

/// Manages the floating caption NSPanel and handles system sleep/wake so the
/// audio engine doesn't crash when the lid closes / the machine sleeps.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private weak var pipeline: Pipeline?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // NOTE: sleep/wake events fire on NSWorkspace's center, NOT NotificationCenter.default.
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(systemWillSleep),
                       name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(systemDidWake),
                       name: NSWorkspace.didWakeNotification, object: nil)
    }

    func attach(_ pipeline: Pipeline) {
        if self.pipeline == nil { self.pipeline = pipeline }
    }

    @objc private func systemWillSleep() {
        // Stop streaming before sleep; the audio engine can crash if left running across sleep.
        guard let pipeline, pipeline.isRecording else { return }
        Task { await pipeline.stop() }
    }

    @objc private func systemDidWake() {
        // Intentionally do not auto-resume — the user restarts with ▶ so we never
        // touch the audio engine before the system is fully awake.
    }

    func showCaption() {
        guard let pipeline else { return }
        if panel == nil {
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 220),
                styleMask: [.nonactivatingPanel, .borderless, .resizable],
                backing: .buffered, defer: false)
            p.level = .floating
            p.isFloatingPanel = true
            p.becomesKeyOnlyIfNeeded = true
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            p.isMovableByWindowBackground = true
            p.contentView = NSHostingView(rootView: CaptionBar(pipeline: pipeline,
                                                               onClose: { [weak self] in self?.hideCaption() }))
            if let screen = NSScreen.main {
                let f = screen.visibleFrame
                p.setFrameOrigin(NSPoint(x: f.midX - 340, y: f.minY + 90))
            }
            panel = p
        }
        panel?.orderFrontRegardless()
    }

    func hideCaption() { panel?.orderOut(nil) }

    func toggleCaption() {
        if let panel, panel.isVisible { panel.orderOut(nil) } else { showCaption() }
    }

    // MARK: - Type-to-translate window (separate from the live caption bar)

    private var typeWindow: NSWindow?

    func showTypeWindow() {
        if typeWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 420),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            w.title = "打字翻译 · 中 → 英 / 日"
            w.center()
            w.contentView = NSHostingView(rootView: TypeView())
            w.isReleasedWhenClosed = false
            w.collectionBehavior.insert(.fullScreenAuxiliary)
            typeWindow = w
        }
        typeWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
