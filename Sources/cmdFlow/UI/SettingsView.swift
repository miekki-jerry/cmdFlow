import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    ProviderCard().environmentObject(app)
                    if app.actions.isEmpty {
                        emptyState.padding(.vertical, 24)
                    } else {
                        ForEach($app.actions) { $action in
                            ActionCard(action: $action)
                                .environmentObject(app)
                        }
                    }
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 540, height: 640)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "command")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("cmdFlow")
                    .font(.headline)
                Text("Skrót → schowek → model → schowek")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if app.settings.providerMode.usesApple {
                modelBadge
            }
        }
        .padding(16)
    }

    private var modelBadge: some View {
        Group {
            switch app.modelStatus {
            case .available:
                Label("Model Apple gotowy", systemImage: "checkmark.seal.fill")
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

// MARK: - Konfiguracja providera

private struct ProviderCard: View {
    @EnvironmentObject var app: AppState
    @State private var showModelPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .foregroundStyle(.tint)
                Text("Backend AI")
                    .font(.system(.body, weight: .semibold))
                Spacer()
            }

            Picker("", selection: $app.settings.providerMode) {
                ForEach(ProviderMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(modeHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if app.settings.providerMode.usesOpenRouter {
                Divider().padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("KLUCZ API OPENROUTER")
                        .font(.caption2).foregroundStyle(.secondary)
                    SecureField("sk-or-…", text: $app.openRouterKey)
                        .textFieldStyle(.roundedBorder)
                    Text("Przechowywany w Keychain. Klucz utworzysz na openrouter.ai/keys")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("MODEL")
                        .font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("np. openai/gpt-4o-mini", text: $app.settings.openRouterModel)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                        Button {
                            showModelPicker = true
                        } label: {
                            Label("Szukaj", systemImage: "magnifyingglass")
                        }
                        .controlSize(.regular)
                    }
                }
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
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(selected: $app.settings.openRouterModel)
        }
    }

    private var modeHint: String {
        switch app.settings.providerMode {
        case .appleOnly:
            return "Model on-device Apple. Prywatny i darmowy, ale nie wspiera każdego języka (m.in. polskiego wejściowego)."
        case .appleWithFallback:
            return "Najpierw Apple on-device; gdy odmówi (np. język), automatyczny fallback do OpenRouter."
        case .openRouterOnly:
            return "Każde żądanie idzie do OpenRouter na Twoim kluczu. Dowolny język, koszt wg cennika modelu."
        }
    }
}

// MARK: - Wyszukiwarka modeli OpenRouter

private struct ModelPickerSheet: View {
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var models: [OpenRouterService.Model] = []
    @State private var loading = true
    @State private var error: String?

    private var filtered: [OpenRouterService.Model] {
        guard !query.isEmpty else { return models }
        let q = query.lowercased()
        return models.filter {
            $0.id.lowercased().contains(q) || ($0.name?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Modele OpenRouter")
                    .font(.headline)
                Spacer()
                Button("Gotowe") { dismiss() }
            }
            .padding(12)
            Divider()

            if loading {
                ProgressView("Pobieranie modeli…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(.orange)
                    Text(error).font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Spróbuj ponownie") { Task { await load() } }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered) { model in
                    Button {
                        selected = model.id
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName).font(.body)
                                Text(model.id).font(.caption2).foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            if model.isFree {
                                Text("free").font(.caption2).foregroundStyle(.green)
                            }
                            if model.id == selected {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .searchable(text: $query, placement: .automatic, prompt: "Szukaj modelu (np. claude, gpt, gemini)")
            }
        }
        .frame(width: 520, height: 560)
        .task { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let list = try await OpenRouterService.listModels()
            models = list.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
            loading = false
        } catch {
            self.error = "Nie udało się pobrać listy modeli. Sprawdź połączenie."
            loading = false
        }
    }
}
