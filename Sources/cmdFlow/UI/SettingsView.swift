import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    GeneralCard()
                    ProviderCard()
                    actionsSection
                }
                .padding(18)
            }
            .background(backgroundGradient)
            footer
        }
        .frame(width: 560, height: 680)
    }

    // MARK: - Tło

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Palette.accentA.opacity(0.05), Palette.accentB.opacity(0.02), .clear],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Palette.gradient)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "command")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Palette.accentB.opacity(0.4), radius: 5, y: 2)

            VStack(alignment: .leading, spacing: 1) {
                Text("cmdFlow")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("Skrót → schowek → model → schowek")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if app.settings.providerMode.usesApple {
                statusPill
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private var statusPill: some View {
        let available: Bool = { if case .available = app.modelStatus { return true } else { return false } }()
        let reason: String = { if case .unavailable(let r) = app.modelStatus { return r } else { return "Model Apple gotowy" } }()
        return HStack(spacing: 5) {
            Circle()
                .fill(available ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(available ? "Model Apple gotowy" : reason)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill((available ? Color.green : Color.orange).opacity(0.14)))
        .help(reason)
        .frame(maxWidth: 230, alignment: .trailing)
    }

    // MARK: - Sekcja akcji

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Akcje")
                Spacer()
                Text("\(app.actions.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            if app.actions.isEmpty {
                emptyState
            } else {
                ForEach($app.actions) { $action in
                    ActionCard(action: $action).environmentObject(app)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(Palette.gradient)
            Text("Brak akcji")
                .font(.headline)
            Text("Dodaj pierwszą akcję i przypisz jej globalny skrót.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .card()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: app.addAction) {
                Label("Dodaj akcję", systemImage: "plus")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.accentB)
            Spacer()
            Button("Zakończ") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

// MARK: - Ogólne (uruchamianie przy logowaniu)

private struct GeneralCard: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "power")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accentB)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("Uruchamiaj przy logowaniu")
                    .font(.system(.body, weight: .medium))
                Text("Startuj cmdFlow automatycznie po zalogowaniu do systemu.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { app.launchAtLogin },
                set: { app.setLaunchAtLogin($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .card()
    }
}

// MARK: - Konfiguracja providera

private struct ProviderCard: View {
    @EnvironmentObject var app: AppState
    @State private var showModelPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .foregroundStyle(Palette.accentB)
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
                keyField
                modelField
            }
        }
        .card()
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(selected: $app.settings.openRouterModel)
        }
    }

    private var keyField: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel("Klucz API OpenRouter")
            SecureField("sk-or-…", text: $app.openRouterKey)
                .textFieldStyle(.roundedBorder)
            Text("Przechowywany w Keychain. Utworzysz go na openrouter.ai/keys")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var modelField: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel("Model")
            HStack(spacing: 8) {
                TextField("np. openai/gpt-4o-mini", text: $app.settings.openRouterModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button {
                    showModelPicker = true
                } label: {
                    Label("Szukaj", systemImage: "magnifyingglass")
                }
            }
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

// MARK: - Karta akcji

private struct ActionCard: View {
    @Binding var action: PromptAction
    @EnvironmentObject var app: AppState
    @State private var testing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Toggle("", isOn: $action.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                TextField("Nazwa akcji", text: $action.name)
                    .textFieldStyle(.plain)
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button(role: .destructive) {
                    withAnimation { app.remove(action) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Usuń akcję")
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionLabel("Skrót globalny")
                ShortcutRecorder(keyCode: $action.keyCode, modifiers: $action.modifiers)
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionLabel("Prompt")
                TextEditor(text: $action.prompt)
                    .font(.system(.callout, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .frame(height: 68)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1))
                    )
            }

            HStack(alignment: .center) {
                Text("Tekst ze schowka → treść, prompt → instrukcja.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { testing = true; await app.run(action); testing = false }
                } label: {
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Uruchom teraz", systemImage: "play.fill")
                            .font(.caption.weight(.medium))
                    }
                }
                .buttonStyle(.bordered)
                .tint(Palette.accentB)
                .controlSize(.small)
                .disabled(testing)
            }
        }
        .card()
        .opacity(action.enabled ? 1 : 0.55)
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
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button("Gotowe") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            Divider()

            if loading {
                ProgressView("Pobieranie modeli…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle).foregroundStyle(.orange)
                    Text(error).font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Spróbuj ponownie") { Task { await load() } }
                        .buttonStyle(.borderedProminent).tint(Palette.accentB)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered) { model in
                    Button {
                        selected = model.id
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName).font(.system(.body, design: .rounded))
                                Text(model.id).font(.caption2).foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            Spacer()
                            if model.isFree {
                                Text("free")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.green.opacity(0.15)))
                            }
                            if model.id == selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Palette.accentB)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .searchable(text: $query, placement: .automatic, prompt: "Szukaj modelu (np. claude, gpt, gemini)")
            }
        }
        .frame(width: 540, height: 580)
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
