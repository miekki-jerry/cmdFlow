import AppKit
import Combine

/// Przejściowy stan pokazywany w ikonie menu bar.
enum Activity: Equatable {
    case idle
    case running(String)   // nazwa akcji
    case success(String)
    case failure(String)
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var actions: [PromptAction] {
        didSet { persist(); reregisterHotKeys() }
    }
    @Published var settings: AppSettings {
        didSet { persistSettings() }
    }
    /// Klucze API — przechowywane w Keychain, tu tylko lustra dla UI.
    /// Ładowane leniwie (przy otwarciu Ustawień), żeby prompt Keychain nie blokował startu.
    @Published var openRouterKey: String = "" {
        didSet { if !isLoadingKeys { Keychain.set(openRouterKey, account: Keychain.openRouterAccount) } }
    }
    @Published var openAIKey: String = "" {
        didSet { if !isLoadingKeys { Keychain.set(openAIKey, account: Keychain.openAIAccount) } }
    }
    private var isLoadingKeys = false
    private var keysLoaded = false
    @Published private(set) var modelStatus: ModelStatus = .unavailable("Sprawdzanie…")
    @Published private(set) var activity: Activity = .idle
    @Published private(set) var launchAtLogin: Bool = false

    private let hotKeys = HotKeyManager()
    private let defaultsKey = "cmdflow.actions.v1"
    private let settingsKey = "cmdflow.settings.v1"
    private var resetTask: Task<Void, Never>?

    private struct RunError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    init() {
        self.actions = AppState.load(key: defaultsKey)
        self.settings = AppState.loadSettings(key: settingsKey)
        if #available(macOS 26.0, *) {
            modelStatus = FoundationModelService.status()
        } else {
            modelStatus = .unavailable("Wymagany macOS 26 lub nowszy.")
        }
        launchAtLogin = LaunchAtLogin.isEnabled
        reregisterHotKeys()
    }

    // MARK: - Klucze API (leniwe ładowanie)

    /// Wczytuje klucze z Keychain do luster UI. Wołane przy otwarciu Ustawień.
    func loadKeys() {
        guard !keysLoaded else { return }
        keysLoaded = true
        isLoadingKeys = true
        openRouterKey = Keychain.get(account: Keychain.openRouterAccount)
        openAIKey = Keychain.get(account: Keychain.openAIAccount)
        isLoadingKeys = false
    }

    // MARK: - Uruchamianie przy logowaniu

    func setLaunchAtLogin(_ enabled: Bool) {
        try? LaunchAtLogin.set(enabled)
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: - Akcje CRUD

    func addAction() {
        actions.append(.newTemplate())
    }

    func remove(_ action: PromptAction) {
        actions.removeAll { $0.id == action.id }
    }

    // MARK: - Status

    func refreshModelStatus() {
        if #available(macOS 26.0, *) {
            modelStatus = FoundationModelService.status()
        }
    }

    // MARK: - Rejestracja skrótów

    private func reregisterHotKeys() {
        hotKeys.unregisterAll()
        for action in actions where action.enabled {
            guard let keyCode = action.keyCode, action.modifiers != 0 else { continue }
            let id = action.id
            hotKeys.register(keyCode: keyCode, modifiers: action.modifiers) { [weak self] in
                self?.trigger(actionID: id)
            }
        }
    }

    // MARK: - Uruchamianie

    private func trigger(actionID: UUID) {
        guard let action = actions.first(where: { $0.id == actionID }) else { return }
        Task { await run(action) }
    }

    /// Publiczne wywołanie (skrót, menu, przycisk „Uruchom teraz").
    func run(_ action: PromptAction) async {
        guard let input = Clipboard.readString(), !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setActivity(.failure("Schowek jest pusty"))
            NSSound.beep()
            return
        }

        setActivity(.running(action.name), autoReset: false)
        do {
            let output = try await generate(instructions: action.prompt, input: input)
            Clipboard.writeString(output)
            setActivity(.success(action.name))
            playSound("Glass")
        } catch {
            setActivity(.failure(error.localizedDescription))
            playSound("Basso")
        }
    }

    /// Kieruje żądanie do właściwego backendu wg wybranego trybu.
    private func generate(instructions: String, input: String) async throws -> String {
        switch settings.providerMode {
        case .cloud:
            return try await cloudGenerate(instructions: instructions, input: input)
        case .appleOnly:
            return try await appleGenerate(instructions: instructions, input: input)
        case .appleWithFallback:
            do {
                return try await appleGenerate(instructions: instructions, input: input)
            } catch {
                // Apple odmówił (np. język) lub jest niedostępny — próbujemy chmury.
                return try await cloudGenerate(instructions: instructions, input: input)
            }
        }
    }

    private func cloudGenerate(instructions: String, input: String) async throws -> String {
        switch settings.cloudProvider {
        case .openRouter:
            let key = keysLoaded ? openRouterKey : Keychain.get(account: Keychain.openRouterAccount)
            return try await OpenRouterService.transform(
                apiKey: key, model: settings.openRouterModel,
                instructions: instructions, input: input
            )
        case .openAI:
            let key = keysLoaded ? openAIKey : Keychain.get(account: Keychain.openAIAccount)
            return try await OpenAIService.transform(
                apiKey: key, model: settings.openAIModel,
                instructions: instructions, input: input
            )
        }
    }

    private func appleGenerate(instructions: String, input: String) async throws -> String {
        guard #available(macOS 26.0, *) else {
            throw RunError(message: "Model Apple wymaga macOS 26+.")
        }
        let status = FoundationModelService.status()
        modelStatus = status
        guard status == .available else {
            if case .unavailable(let reason) = status { throw RunError(message: reason) }
            throw RunError(message: "Model Apple jest niedostępny.")
        }
        return try await FoundationModelService.transform(instructions: instructions, input: input)
    }

    private func setActivity(_ value: Activity, autoReset: Bool = true) {
        activity = value
        resetTask?.cancel()
        guard autoReset else { return }
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.activity = .idle
        }
    }

    private func playSound(_ name: String) {
        NSSound(named: name)?.play()
    }

    // MARK: - Persystencja

    private func persist() {
        guard let data = try? JSONEncoder().encode(actions) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    private static func load(key: String) -> [PromptAction] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([PromptAction].self, from: data)
        else {
            return [defaultAction]
        }
        return decoded
    }

    private static func loadSettings(key: String) -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return decoded
    }

    private static var defaultAction: PromptAction {
        PromptAction(
            name: "Tłumacz na angielski",
            keyCode: nil,
            modifiers: 0,
            prompt: "You are a translation engine. Translate the user's text to English. Output only the translation, with no greetings, notes, or commentary.",
            enabled: true
        )
    }
}
