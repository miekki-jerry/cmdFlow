import SwiftUI

/// Result of a vision question (a plain message-based outcome, no Error type needed).
enum SnapReply {
    case answer(String)
    case failure(String)
}

/// Borderless floating panel that can still become key (for text input).
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Floating panel that shows the captured screenshot and a vision chat about it,
/// styled after Apple's visual-intelligence look.
@MainActor
final class SnapChatController {
    private var panel: FloatingPanel?

    func present(image: NSImage, send: @escaping (String) async -> SnapReply) {
        let view = SnapChatView(image: image, send: send) { [weak self] in
            self?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let panel = FloatingPanel(contentViewController: hosting)
        panel.styleMask = [.borderless, .nonactivatingPanel]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.center()
        self.panel = panel

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

private struct SnapChatView: View {
    let image: NSImage
    let send: (String) async -> SnapReply
    let onClose: () -> Void

    @State private var input = ""
    @State private var messages: [Msg] = []
    @State private var sending = false
    @State private var glow = false
    @State private var expanded = false

    private struct Msg: Identifiable {
        let id = UUID()
        let user: Bool
        let text: String
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    thumbnail
                    ForEach(messages) { msg in
                        if msg.user {
                            HStack { Spacer(minLength: 44); questionBubble(msg.text) }
                        } else {
                            answerText(msg.text)
                        }
                    }
                    if sending { thinking }
                }
                .padding(.horizontal, 18)
                .padding(.top, 52)
                .padding(.bottom, 14)
            }
            inputPill
        }
        .frame(width: expanded ? 560 : 440)
        .frame(minHeight: 260, maxHeight: expanded ? 700 : 560)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08))
        )
        .overlay(alignment: .topLeading) {
            circleButton("xmark", action: onClose).padding(14)
        }
        .overlay(alignment: .topTrailing) {
            circleButton(expanded ? "arrow.down.forward.and.arrow.up.backward" : "arrow.up.backward.and.arrow.down.forward") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expanded.toggle() }
            }
            .padding(14)
        }
        .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { glow = true }
        }
    }

    // MARK: - Pieces

    private var thumbnail: some View {
        HStack {
            Spacer(minLength: 0)
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 190, maxHeight: 190)
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

    private func questionBubble(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.primary)
            .textSelection(.enabled)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
    }

    private func answerText(_ text: String) -> some View {
        Text(text)
            .font(.system(.body))
            .foregroundStyle(.primary)
            .lineSpacing(3)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var thinking: some View {
        HStack(spacing: 7) {
            ProgressView().controlSize(.small)
            Text("Thinking…").font(.callout).foregroundStyle(.secondary)
        }
    }

    private var inputPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13))
                .foregroundStyle(Palette.accentB)
            TextField("Ask about the screenshot…", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
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
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            Capsule().fill(Color.white.opacity(0.10))
        )
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

    // MARK: - Send

    private func submit() {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !sending else { return }
        messages.append(Msg(user: true, text: question))
        input = ""
        sending = true
        let context = buildContext()
        Task {
            let result = await send(context)
            sending = false
            switch result {
            case .answer(let answer): messages.append(Msg(user: false, text: answer))
            case .failure(let error): messages.append(Msg(user: false, text: "⚠︎ \(error)"))
            }
        }
    }

    private func buildContext() -> String {
        var transcript = ""
        for m in messages {
            transcript += (m.user ? "User: " : "Assistant: ") + m.text + "\n"
        }
        transcript += "Answer the last user question about the attached screenshot."
        return transcript
    }
}
