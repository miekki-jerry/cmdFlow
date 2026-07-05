import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if app.actions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($app.actions) { $action in
                            ActionCard(action: $action)
                                .environmentObject(app)
                        }
                    }
                    .padding(16)
                }
            }
            Divider()
            footer
        }
        .frame(width: 520, height: 560)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "command")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("cmdFlow")
                    .font(.headline)
                Text("Skrót → schowek → model Apple → schowek")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            modelBadge
        }
        .padding(16)
    }

    private var modelBadge: some View {
        Group {
            switch app.modelStatus {
            case .available:
                Label("Model gotowy", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .unavailable(let reason):
                Label(reason, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(reason)
            }
        }
        .font(.caption)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .frame(maxWidth: 220, alignment: .trailing)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Brak akcji")
                .font(.headline)
            Text("Dodaj pierwszą akcję i przypisz jej globalny skrót.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("Model on-device: EN/DE/FR/ES/IT/PT/JA/KO/ZH. Polski tekst wejściowy bywa odrzucany przez Apple Intelligence.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            HStack {
                Button {
                    app.addAction()
                } label: {
                    Label("Dodaj akcję", systemImage: "plus")
                }
                Spacer()
                Button("Zakończ cmdFlow") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}

private struct ActionCard: View {
    @Binding var action: PromptAction
    @EnvironmentObject var app: AppState
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Toggle("", isOn: $action.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                TextField("Nazwa akcji", text: $action.name)
                    .textFieldStyle(.plain)
                    .font(.system(.body, weight: .semibold))
                Spacer()
                Button(role: .destructive) {
                    app.remove(action)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Usuń akcję")
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SKRÓT")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ShortcutRecorder(keyCode: $action.keyCode, modifiers: $action.modifiers)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("PROMPT")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextEditor(text: $action.prompt)
                    .font(.system(.body, design: .rounded))
                    .frame(height: 70)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.secondary.opacity(0.2))
                    )
            }

            HStack {
                Text("Tekst ze schowka trafia do modelu jako treść, prompt jako instrukcja.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task {
                        testing = true
                        await app.run(action)
                        testing = false
                    }
                } label: {
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Uruchom teraz", systemImage: "play.fill")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(testing)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.15))
        )
        .opacity(action.enabled ? 1 : 0.55)
    }
}
