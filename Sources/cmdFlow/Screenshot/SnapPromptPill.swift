import SwiftUI

/// Small focused input pill shown next to the selection. On submit it hands the
/// question over and the full chat panel takes over.
@MainActor
final class SnapPromptPill {
    private var panel: FloatingPanel?

    /// `rect` is the selection in global AppKit coordinates (bottom-left origin).
    func present(near rect: CGRect, onSubmit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        let width: CGFloat = 420
        let height: CGFloat = 52

        let view = PillView(
            onSubmit: { [weak self] text in self?.close(); onSubmit(text) },
            onCancel: { [weak self] in self?.close(); onCancel() }
        )
        let hosting = NSHostingView(rootView: view)

        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = hosting

        // Place just below the selection, horizontally centered and clamped on screen.
        var originX = rect.midX - width / 2
        var originY = rect.minY - height - 12
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let f = screen.frame
            originX = min(max(f.minX + 8, originX), f.maxX - width - 8)
            if originY < f.minY + 8 { originY = rect.maxY + 12 } // no room below → put above
        }
        panel.setFrame(NSRect(x: originX, y: originY, width: width, height: height), display: true)
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct PillView: View {
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.gradient)
            TextField("Ask about the selection…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($focused)
                .onSubmit(submit)
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Color.secondary))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(
            Capsule().fill(.regularMaterial)
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        .onExitCommand(perform: onCancel) // Esc
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focused = true }
        }
    }

    private var canSend: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    private func submit() {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        onSubmit(q)
    }
}
