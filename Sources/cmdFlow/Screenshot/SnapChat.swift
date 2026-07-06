import SwiftUI

/// Result of a vision question (a plain message-based outcome, no Error type needed).
enum SnapReply {
    case answer(String)
    case failure(String)
}

/// Floating panel that shows the captured screenshot and a vision chat about it.
@MainActor
final class SnapChatController {
    private var panel: NSPanel?

    func present(image: NSImage, send: @escaping (String) async -> SnapReply) {
        let view = SnapChatView(image: image, send: send) { [weak self] in
            self?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(contentViewController: hosting)
        panel.styleMask = [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
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

    private struct Msg: Identifiable {
        let id = UUID()
        let user: Bool
        let text: String
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            screenshot
            if !messages.isEmpty { conversation }
            Divider()
            inputBar
        }
        .frame(width: 380)
        .frame(maxHeight: 560)
        .background(.regularMaterial)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { glow = true }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles.rectangle.stack")
                .foregroundStyle(Palette.gradient)
            Text("Ask a screenshot")
                .font(.system(.headline, design: .rounded))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private var screenshot: some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 220)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.accentB.opacity(glow ? 0.6 : 0), lineWidth: 1.5)
            )
            .shadow(color: Palette.accentB.opacity(glow ? 0.55 : 0), radius: glow ? 18 : 0)
            .scaleEffect(glow ? 1 : 0.92)
            .opacity(glow ? 1 : 0)
            .padding(12)
    }

    private var conversation: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(messages) { msg in
                    HStack {
                        if msg.user { Spacer(minLength: 32) }
                        Text(msg.text)
                            .font(.callout)
                            .textSelection(.enabled)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(msg.user ? AnyShapeStyle(Palette.softGradient) : AnyShapeStyle(Color.primary.opacity(0.06)))
                            )
                            .frame(maxWidth: .infinity, alignment: msg.user ? .trailing : .leading)
                        if !msg.user { Spacer(minLength: 32) }
                    }
                }
                if sending {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Thinking…").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 8)
        }
        .frame(maxHeight: 220)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask about the screenshot…", text: $input, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .onSubmit(submit)
            Button(action: submit) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(input.trimmingCharacters(in: .whitespaces).isEmpty || sending ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Palette.gradient))
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || sending)
        }
        .padding(12)
    }

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
