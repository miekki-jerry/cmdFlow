import AppKit

/// Borderless overlay for selecting a screen region (CleanShot-style dim + drag rectangle).
@MainActor
final class RegionSelector {
    private var window: OverlayWindow?
    private var onComplete: (@MainActor (CGRect?, NSScreen?) -> Void)?

    /// Presents the selector. Completion gets a rect in global AppKit coordinates and the screen,
    /// or (nil, nil) if the user cancelled.
    func begin(_ completion: @escaping @MainActor (CGRect?, NSScreen?) -> Void) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let screen else { completion(nil, nil); return }
        onComplete = completion

        let view = SelectionView(screenOrigin: screen.frame.origin)
        view.onFinish = { [weak self] rect in self?.finish(rect, screen) }
        view.onCancel = { [weak self] in self?.finish(nil, screen) }

        let win = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .screenSaver
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false
        win.contentView = view
        win.setFrame(screen.frame, display: true)
        window = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(view)
    }

    private func finish(_ rect: CGRect?, _ screen: NSScreen) {
        window?.orderOut(nil)
        window = nil
        let cb = onComplete
        onComplete = nil
        cb?(rect, rect == nil ? nil : screen)
    }
}

/// Borderless window that can still become key (for Esc / key handling).
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionView: NSView {
    var onFinish: ((CGRect) -> Void)?   // rect in GLOBAL coordinates
    var onCancel: (() -> Void)?

    private let screenOrigin: CGPoint
    private var start: CGPoint?
    private var rect: CGRect?

    init(screenOrigin: CGPoint) {
        self.screenOrigin = screenOrigin
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        guard let r = rect else { return }

        // Punch a transparent hole for the selection.
        NSColor.clear.setFill()
        r.fill(using: .copy)

        // Accent border.
        let border = NSBezierPath(rect: r)
        border.lineWidth = 1.5
        NSColor(red: 0.55, green: 0.30, blue: 0.95, alpha: 1).setStroke()
        border.stroke()

        // Dimensions label.
        let text = "\(Int(r.width)) × \(Int(r.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let pad: CGFloat = 5
        let labelRect = CGRect(x: r.minX, y: max(0, r.minY - size.height - 2 * pad - 4),
                               width: size.width + 2 * pad, height: size.height + 2 * pad)
        let bg = NSBezierPath(roundedRect: labelRect, xRadius: 5, yRadius: 5)
        NSColor(red: 0.55, green: 0.30, blue: 0.95, alpha: 0.9).setFill()
        bg.fill()
        (text as NSString).draw(at: CGPoint(x: labelRect.minX + pad, y: labelRect.minY + pad), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        rect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let s = start else { return }
        let p = convert(event.locationInWindow, from: nil)
        rect = CGRect(x: min(s.x, p.x), y: min(s.y, p.y), width: abs(p.x - s.x), height: abs(p.y - s.y))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let r = rect, r.width > 6, r.height > 6 else { onCancel?(); return }
        let global = CGRect(x: r.origin.x + screenOrigin.x, y: r.origin.y + screenOrigin.y,
                            width: r.width, height: r.height)
        onFinish?(global)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() } // Esc
    }
}
