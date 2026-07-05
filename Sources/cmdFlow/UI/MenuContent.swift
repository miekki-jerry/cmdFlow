import SwiftUI

struct MenuContent: View {
    @EnvironmentObject var app: AppState
    @Environment(\.openWindow) private var openWindow

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

            Divider()
            Button("Ustawienia…") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Zakończ cmdFlow") {
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
                    Text("Gotowe — naciśnij skrót")
                case .unavailable(let reason):
                    Text("⚠︎ \(reason)")
                }
            case .running(let name):
                Text("⏳ \(name)…")
            case .success(let name):
                Text("✓ \(name) — wynik w schowku")
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
        return "\(action.name)   (brak skrótu)"
    }
}
