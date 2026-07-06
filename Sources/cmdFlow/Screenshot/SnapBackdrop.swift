import SwiftUI

@MainActor
final class BackdropModel: ObservableObject {
    @Published var showHighlight = true
}

/// Full-screen dim behind the prompt pill / chat, with the captured region kept
/// lit in its original place (Apple visual-intelligence style). Click to dismiss.
/// Once the chat opens, the lit region is hidden (the chat shows its own thumbnail).
@MainActor
final class SnapBackdrop {
    private var panel: NSPanel?
    private let model = BackdropModel()

    func present(image: NSImage, selectionRect: CGRect, screen: NSScreen, onDismiss: @escaping () -> Void) {
        let frame = screen.frame
        // Global (bottom-left) selection → window-local top-left coordinates.
        let localX = selectionRect.minX - frame.minX
        let localYTop = frame.maxY - selectionRect.maxY
        let imageRect = CGRect(x: localX, y: localYTop, width: selectionRect.width, height: selectionRect.height)

        model.showHighlight = true
        let view = BackdropView(image: image, imageRect: imageRect, onDismiss: onDismiss, model: model)
        let hosting = NSHostingView(rootView: view)

        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = false
        panel.contentView = hosting
        panel.setFrame(frame, display: true)
        panel.alphaValue = 0
        panel.orderFront(nil) // never key — the pill/chat above keep focus
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }
        self.panel = panel
    }

    /// Hides the lit region (keeps the dim) once the chat panel takes over.
    func hideHighlight() {
        withAnimation(.easeOut(duration: 0.25)) { model.showHighlight = false }
    }

    func dismiss() {
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 0
        }, completionHandler: { MainActor.assumeIsolated { panel.orderOut(nil) } })
    }
}

private struct BackdropView: View {
    let image: NSImage
    let imageRect: CGRect
    let onDismiss: () -> Void
    @ObservedObject var model: BackdropModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onDismiss() }

            if model.showHighlight {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20)
                    .offset(x: imageRect.minX, y: imageRect.minY)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
