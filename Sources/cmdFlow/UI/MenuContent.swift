import SwiftUI

struct MenuContent: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Group {
            statusRow

            if !app.actions.isEmpty {
                Divider()
                ForEach(app.actions) { action in
                    Button {
                        Task { await app.run(action) }
                    } label: {
                        Text(menuTitle(for: action))
                    }
                    .disabled(!action.enabled)
                }
            }

            if app.settings.screenshotChatEnabled {
                Divider()
                Button("Ask a screenshot") {
                    app.startScreenshotChat()
                }
            }

            Divider()
            Button("Settings…") {
                NotificationCenter.default.post(name: .openCmdFlowSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Quit cmdFlow") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private var statusRow: some View {
        Group {
            switch app.activity {
            case .idle:
                switch app.modelStatus {
                case .available:
                    Text("Ready — press a shortcut")
                case .unavailable(let reason):
                    Text("⚠︎ \(reason)")
                }
            case .running(let name):
                Text("⏳ \(name)…")
            case .success(let name):
                Text("✓ \(name) — result in clipboard")
            case .failure(let message):
                Text("✗ \(message)")
            }
        }
        .disabled(true)
    }

    private func menuTitle(for action: PromptAction) -> String {
        if let shortcut = KeyCodes.describe(keyCode: action.keyCode, modifiers: action.modifiers) {
            return "\(action.name)   \(shortcut)"
        }
        return "\(action.name)   (no shortcut)"
    }
}
