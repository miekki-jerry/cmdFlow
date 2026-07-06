import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            TabView {
                ActionsTab()
                    .environmentObject(app)
                    .tabItem { Label("Actions", systemImage: "command") }
                ScreenshotTab()
                    .environmentObject(app)
                    .tabItem { Label("Screenshot", systemImage: "text.viewfinder") }
                ChatsTab(history: app.history)
                    .environmentObject(app)
                    .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right") }
                GeneralTab()
                    .environmentObject(app)
                    .tabItem { Label("General", systemImage: "gearshape") }
            }
            .padding(.top, 8)
            footer
        }
        .frame(width: 560, height: 720)
        .onAppear { app.loadKeys() }
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
                Text("Shortcut → clipboard → model → clipboard")
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
        let reason: String = { if case .unavailable(let r) = app.modelStatus { return r } else { return "Apple model ready" } }()
        return HStack(spacing: 5) {
            Circle()
                .fill(available ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(available ? "Apple model ready" : reason)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill((available ? Color.green : Color.orange).opacity(0.14)))
        .help(reason)
        .frame(maxWidth: 230, alignment: .trailing)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("© LUC LABS · v\(appVersion)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}

// MARK: - Actions tab

private struct ActionsTab: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ProviderCard()
                actionsSection
                Button(action: app.addAction) {
                    Label("Add action", systemImage: "plus")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accentB)
                .controlSize(.large)
            }
            .padding(18)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Actions")
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
            Text("No actions")
                .font(.headline)
            Text("Add your first action and assign it a global shortcut.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .card()
    }
}

// MARK: - Screenshot tab

private struct ScreenshotTab: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 14) { ScreenshotCard() }
                .padding(18)
        }
    }
}

// MARK: - Chats tab (screenshot history)

private struct ChatsTab: View {
    @ObservedObject var history: SnapHistory
    @EnvironmentObject var app: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if history.sessions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.largeTitle).foregroundStyle(Palette.gradient)
                        Text("No screenshot chats yet")
                            .font(.headline)
                        Text("Ask about a screenshot and it will show up here.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .card()
                } else {
                    HStack {
                        SectionLabel("Screenshot chats")
                        Spacer()
                        Button("Clear all") { history.clear() }
                            .font(.caption2).buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    ForEach(history.sessions) { session in
                        SessionRow(session: session)
                            .environmentObject(app)
                            .environmentObject(history)
                    }
                }
            }
            .padding(18)
        }
    }
}

private struct SessionRow: View {
    let session: SnapSession
    @EnvironmentObject var app: AppState
    @EnvironmentObject var history: SnapHistory

    var body: some View {
        Button {
            app.reopenSession(session)
        } label: {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.title)
                        .font(.system(.callout, weight: .medium))
                        .lineLimit(2)
                    Text("\(session.turns.filter { !$0.user }.count) replies · \(session.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation { history.delete(session) }
                } label: {
                    Image(systemName: "trash").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.secondary.opacity(0.15)))
    }

    @ViewBuilder private var thumbnail: some View {
        if let image = ScreenCapture.image(fromBase64PNG: session.imageBase64) {
            Image(nsImage: image)
                .resizable().scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.2))
                .frame(width: 44, height: 44)
        }
    }
}

// MARK: - General tab (keys + launch at login)

private struct GeneralTab: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                KeysCard()
                LaunchAtLoginCard()
            }
            .padding(18)
        }
    }
}

private struct KeysCard: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill").foregroundStyle(Palette.accentB)
                Text("API keys").font(.system(.body, weight: .semibold))
                Spacer()
            }
            Text("Stored in the macOS Keychain. Used by the cloud providers (text actions and screenshot chat).")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            keyField(.openRouter, binding: $app.openRouterKey)
            keyField(.openAI, binding: $app.openAIKey)
        }
        .card()
    }

    private func keyField(_ provider: CloudProvider, binding: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel("\(provider.label) API key")
            SecureField(provider.keyPlaceholder, text: binding)
                .textFieldStyle(.roundedBorder)
            Text("Create one at \(provider.keysURL)")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct LaunchAtLoginCard: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "power")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accentB)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("Launch at login")
                    .font(.system(.body, weight: .medium))
                Text("Start cmdFlow automatically when you log in.")
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

// MARK: - Text provider configuration

private struct ProviderCard: View {
    @EnvironmentObject var app: AppState
    @State private var showModelPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cpu")
                    .foregroundStyle(Palette.accentB)
                Text("AI backend")
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

            if app.settings.providerMode.usesCloud {
                Divider().padding(.vertical, 2)
                cloudProviderPicker
                modelField
                Text("Set the API key in the General tab.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .card()
        .sheet(isPresented: $showModelPicker) {
            ModelPickerSheet(
                selected: app.settings.cloudProvider == .openRouter ? $app.settings.openRouterModel : $app.settings.openAIModel,
                title: app.settings.cloudProvider == .openRouter ? "OpenRouter models" : "OpenAI models",
                load: { await loadModels(provider: app.settings.cloudProvider, openAIKey: app.openAIKey) }
            )
        }
    }

    private var cloudProviderPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel("Cloud provider")
            Picker("", selection: $app.settings.cloudProvider) {
                ForEach(CloudProvider.allCases) { provider in
                    Text(provider.label).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder private var modelField: some View {
        let isOpenRouter = app.settings.cloudProvider == .openRouter
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel("Model")
            HStack(spacing: 8) {
                TextField(isOpenRouter ? "e.g. openai/gpt-5.4-mini" : "e.g. gpt-5.4-mini",
                          text: isOpenRouter ? $app.settings.openRouterModel : $app.settings.openAIModel)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button { showModelPicker = true } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
        }
    }

    private var modeHint: String {
        switch app.settings.providerMode {
        case .appleOnly:
            return "Apple's on-device model. Private and free, but it doesn't support every language (e.g. Polish input)."
        case .appleWithFallback:
            return "Apple on-device first; if it refuses (e.g. language), automatic fallback to the selected cloud provider."
        case .cloud:
            return "Every request goes to the selected provider on your key. Any language, cost per the model's pricing."
        }
    }
}

// MARK: - Screenshot chat card

private struct ScreenshotCard: View {
    @EnvironmentObject var app: AppState
    @State private var showVisionPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.viewfinder")
                    .foregroundStyle(Palette.accentB)
                Text("Screenshot chat")
                    .font(.system(.body, weight: .semibold))
                Spacer()
                Toggle("", isOn: $app.settings.screenshotChatEnabled)
                    .labelsHidden().toggleStyle(.switch)
            }
            Text("Press a shortcut, drag to select a screen region, then ask a vision model about it. Cloud-only — Apple's on-device model can't read images.")
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if app.settings.screenshotChatEnabled {
                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel("Shortcut")
                    ShortcutRecorder(keyCode: $app.settings.screenshotKeyCode, modifiers: $app.settings.screenshotModifiers)
                }

                VStack(alignment: .leading, spacing: 5) {
                    SectionLabel("Provider")
                    Picker("", selection: $app.settings.screenshotProvider) {
                        ForEach(CloudProvider.allCases) { provider in
                            Text(provider.label).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                visionModelField
                systemPromptField
                Text("Set the API key in the General tab.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .card()
        .sheet(isPresented: $showVisionPicker) {
            ModelPickerSheet(
                selected: app.settings.screenshotProvider == .openRouter ? $app.settings.openRouterVisionModel : $app.settings.openAIVisionModel,
                title: app.settings.screenshotProvider == .openRouter ? "OpenRouter models" : "OpenAI models",
                load: { await loadModels(provider: app.settings.screenshotProvider, openAIKey: app.openAIKey) }
            )
        }
    }

    private var systemPromptField: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                SectionLabel("System prompt")
                Spacer()
                Button("Reset") {
                    app.settings.screenshotSystemPrompt = AppSettings.defaultScreenshotSystemPrompt
                }
                .font(.caption2).buttonStyle(.plain).foregroundStyle(Palette.accentB)
            }
            TextEditor(text: $app.settings.screenshotSystemPrompt)
                .font(.system(.callout, design: .rounded))
                .scrollContentBackground(.hidden)
                .frame(height: 60)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Color.primary.opacity(0.1)))
        }
    }

    @ViewBuilder private var visionModelField: some View {
        let isOpenRouter = app.settings.screenshotProvider == .openRouter
        VStack(alignment: .leading, spacing: 5) {
            SectionLabel("Vision model")
            HStack(spacing: 8) {
                TextField(isOpenRouter ? "e.g. openai/gpt-5.4" : "e.g. gpt-5.4",
                          text: isOpenRouter ? $app.settings.openRouterVisionModel : $app.settings.openAIVisionModel)
                    .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                Button { showVisionPicker = true } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }
        }
    }
}

// MARK: - Action card

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
                TextField("Action name", text: $action.name)
                    .textFieldStyle(.plain)
                    .font(.system(.headline, design: .rounded))
                Spacer()
                Button(role: .destructive) {
                    withAnimation { app.remove(action) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete action")
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionLabel("Global shortcut")
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
                Text("Clipboard text → content, prompt → instructions.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { testing = true; await app.run(action); testing = false }
                } label: {
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Run now", systemImage: "play.fill")
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

// MARK: - Model search (OpenRouter + OpenAI)

struct ModelItem: Identifiable, Equatable {
    let id: String
    let name: String
    let free: Bool
}

enum ModelLoad {
    case ok([ModelItem])
    case failed(String)
}

/// Loads the model list for a provider (OpenRouter is keyless; OpenAI needs the key).
@MainActor
func loadModels(provider: CloudProvider, openAIKey: String) async -> ModelLoad {
    switch provider {
    case .openRouter:
        do {
            let list = try await OpenRouterService.listModels()
            let items = list
                .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
                .map { ModelItem(id: $0.id, name: $0.displayName, free: $0.isFree) }
            return .ok(items)
        } catch {
            return .failed("Couldn't load the model list. Check your connection.")
        }
    case .openAI:
        do {
            let ids = try await OpenAIService.listChatModels(apiKey: openAIKey)
            return .ok(ids.map { ModelItem(id: $0, name: $0, free: false) })
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}

private struct ModelPickerSheet: View {
    @Binding var selected: String
    let title: String
    let load: () async -> ModelLoad
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var models: [ModelItem] = []
    @State private var loading = true
    @State private var error: String?

    private var filtered: [ModelItem] {
        guard !query.isEmpty else { return models }
        let q = query.lowercased()
        return models.filter { $0.id.lowercased().contains(q) || $0.name.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(.headline, design: .rounded))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(14)
            Divider()

            if loading {
                ProgressView("Loading models…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark").font(.largeTitle).foregroundStyle(.orange)
                    Text(error).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Try again") { Task { await run() } }
                        .buttonStyle(.borderedProminent).tint(Palette.accentB)
                }
                .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered) { model in
                    Button {
                        selected = model.id
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Text(model.id).font(.system(.body, design: .rounded))
                                .textSelection(.enabled)
                            Spacer()
                            if model.free {
                                Text("free").font(.caption2.weight(.semibold)).foregroundStyle(.green)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(Color.green.opacity(0.15)))
                            }
                            if model.id == selected {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accentB)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .searchable(text: $query, placement: .automatic, prompt: "Search models")
            }
        }
        .frame(width: 540, height: 580)
        .task { await run() }
    }

    private func run() async {
        loading = true; error = nil
        switch await load() {
        case .ok(let items): models = items; loading = false
        case .failed(let message): error = message; loading = false
        }
    }
}
