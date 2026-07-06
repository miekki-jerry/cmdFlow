import SwiftUI

/// Borderless floating panel that can still become key (for text input).
/// `onCancel` fires on Escape (cancelOperation).
final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}

/// Fades a panel in on present and out on dismiss, for a smoother feel.
@MainActor
enum PanelFade {
    static func present(_ panel: NSPanel) {
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    static func dismiss(_ panel: NSPanel) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { MainActor.assumeIsolated { panel.orderOut(nil) } })
    }
}

/// Floating chat panel about a captured screenshot.
@MainActor
final class SnapChatController {
    private var panel: FloatingPanel?

    func present(
        image: NSImage?,
        initialTurns: [SnapTurn],
        stream: @escaping ([SnapTurn]) -> AsyncThrowingStream<String, Error>,
        persist: @escaping ([SnapTurn]) -> Void,
        onClose: @escaping () -> Void
    ) {
        let view = SnapChatView(image: image, initialTurns: initialTurns,
                                stream: stream, persist: persist, onClose: onClose)
        let hosting = NSHostingController(rootView: view)
        let panel = FloatingPanel(contentViewController: hosting)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.center()
        panel.onCancel = onClose
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        PanelFade.present(panel)
    }

    func close() {
        guard let panel else { return }
        self.panel = nil
        PanelFade.dismiss(panel)
    }
}

private struct SnapChatView: View {
    let image: NSImage?
    let stream: ([SnapTurn]) -> AsyncThrowingStream<String, Error>
    let persist: ([SnapTurn]) -> Void
    let onClose: () -> Void

    @State private var turns: [SnapTurn]
    @State private var input = ""
    @State private var sending = false
    @State private var glow = false
    @State private var atBottom = true
    @State private var expanded = false
    @FocusState private var inputFocused: Bool

    private let bottomID = "snap-bottom"

    init(image: NSImage?, initialTurns: [SnapTurn],
         stream: @escaping ([SnapTurn]) -> AsyncThrowingStream<String, Error>,
         persist: @escaping ([SnapTurn]) -> Void,
         onClose: @escaping () -> Void) {
        self.image = image
        self.stream = stream
        self.persist = persist
        self.onClose = onClose
        _turns = State(initialValue: initialTurns)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        thumbnail
                        ForEach(turns) { turn in
                            Group {
                                if turn.user {
                                    HStack { Spacer(minLength: 48); questionBubble(turn.text) }
                                } else {
                                    answerText(turn.text)
                                }
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if sending && (turns.last?.text.isEmpty ?? false) {
                            thinking.transition(.opacity)
                        }
                        Color.clear.frame(height: 1).id(bottomID)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 52)
                    .padding(.bottom, 14)
                }
                .onScrollGeometryChange(for: Bool.self) { geo in
                    geo.contentOffset.y >= geo.contentSize.height - geo.containerSize.height - 30
                } action: { _, nowAtBottom in
                    atBottom = nowAtBottom
                }
                .onChange(of: turns) { if atBottom { scrollToBottom(proxy) } }
                .overlay(alignment: .bottomTrailing) {
                    if !atBottom {
                        Button { scrollToBottom(proxy) } label: {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(.regularMaterial))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.12)))
                                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(14)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: atBottom)
            }
            inputBar
        }
        .frame(width: expanded ? 720 : 480)
        .frame(minHeight: expanded ? 760 : 380, maxHeight: expanded ? 940 : 760)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: expanded)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .overlay(alignment: .topLeading) { circleButton("xmark", action: onClose).padding(14) }
        .overlay(alignment: .topTrailing) {
            circleButton(expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                expanded.toggle()
            }
            .padding(14)
        }
        .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { glow = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { inputFocused = true }
            if turns.last?.user == true { Task { await runPending() } }
        }
    }

    // MARK: - Pieces

    @ViewBuilder private var thumbnail: some View {
        if let image {
            HStack {
                Spacer(minLength: 0)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Palette.accentB.opacity(glow ? 0.55 : 0), lineWidth: 1.5)
                    )
                    .shadow(color: Palette.accentB.opacity(glow ? 0.5 : 0), radius: glow ? 20 : 0)
                    .scaleEffect(glow ? 1 : 0.9)
                    .opacity(glow ? 1 : 0)
            }
        }
    }

    private func questionBubble(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.white)
            .textSelection(.enabled)
            .padding(.horizontal, 13).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.gradient))
    }

    private func answerText(_ text: String) -> some View {
        Text(text)
            .font(.system(.body))
            .foregroundStyle(.primary)
            .lineSpacing(3)
            .textSelection(.enabled)
            .contentTransition(.opacity)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var thinking: some View {
        HStack(spacing: 7) {
            ProgressView().controlSize(.small)
            Text("Thinking…").font(.callout).foregroundStyle(.secondary)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask a follow-up…", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($inputFocused)
                .onSubmit(submit)
            if sending {
                ProgressView().controlSize(.small)
            } else {
                Button(action: submit) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Color.secondary))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(Capsule().fill(Color.white.opacity(0.10)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12)))
        .padding(14)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty && !sending
    }

    // MARK: - Logic

    private func submit() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !sending else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            turns.append(SnapTurn(user: true, text: question))
        }
        input = ""
        persist(turns)
        Task { await runPending() }
    }

    private func runPending() async {
        guard turns.last?.user == true, !sending else { return }
        sending = true
        let requestTurns = turns
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            turns.append(SnapTurn(user: false, text: ""))
        }
        let streamID = turns[turns.count - 1].id

        do {
            for try await delta in stream(requestTurns) {
                if let i = turns.firstIndex(where: { $0.id == streamID }) {
                    withAnimation(.easeOut(duration: 0.12)) { turns[i].text += delta }
                }
            }
        } catch {
            if let i = turns.firstIndex(where: { $0.id == streamID }), turns[i].text.isEmpty {
                turns[i].text = "⚠︎ \(error.localizedDescription)"
            }
        }
        if let i = turns.firstIndex(where: { $0.id == streamID }), turns[i].text.isEmpty {
            turns[i].text = "⚠︎ No response."
        }
        sending = false
        persist(turns)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(bottomID, anchor: .bottom)
        }
    }
}
