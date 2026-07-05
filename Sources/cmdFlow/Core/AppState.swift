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
    @Published var actions: [PromptAction] {
        didSet { persist(); reregisterHotKeys() }
    }
    @Published private(set) var modelStatus: ModelStatus = .unavailable("Sprawdzanie…")
    @Published private(set) var activity: Activity = .idle

    private let hotKeys = HotKeyManager()
    private let defaultsKey = "cmdflow.actions.v1"
    private var resetTask: Task<Void, Never>?

    init() {
        self.actions = AppState.load(key: defaultsKey)
        if #available(macOS 26.0, *) {
            modelStatus = FoundationModelService.status()
        } else {
            modelStatus = .unavailable("Wymagany macOS 26 lub nowszy.")
        }
        reregisterHotKeys()
    }

    // MARK: - Akcje CRUD

    func addAction() {
        actions.append(.newTemplate())
    }

    func remove(_ action: PromptAction) {
        actions.removeAll { $0.id == action.id }
    }

    func binding(for action: PromptAction) -> PromptAction? {
        actions.first { $0.id == action.id }
    }

    // MARK: - Rejestracja skrótów

    func refreshModelStatus() {
        if #available(macOS 26.0, *) {
            modelStatus = FoundationModelService.status()
        }
    }

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

    /// Publiczne wywołanie (np. z menu „Uruchom teraz").
    func run(_ action: PromptAction) async {
        guard #available(macOS 26.0, *) else {
            setActivity(.failure("Wymagany macOS 26+"))
            return
        }

        // Odśwież status modelu na wypadek, gdy dopiero się przygotował.
        modelStatus = FoundationModelService.status()
        guard modelStatus == .available else {
            if case .unavailable(let reason) = modelStatus {
                setActivity(.failure(reason))
            }
            return
        }

        guard let input = Clipboard.readString(), !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setActivity(.failure("Schowek jest pusty"))
            NSSound.beep()
            return
        }

        setActivity(.running(action.name), autoReset: false)
        do {
            let output = try await FoundationModelService.transform(instructions: action.prompt, input: input)
            Clipboard.writeString(output)
            setActivity(.success(action.name))
            playSound("Glass")
        } catch {
            setActivity(.failure(error.localizedDescription))
            playSound("Basso")
        }
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

    private static func load(key: String) -> [PromptAction] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([PromptAction].self, from: data)
        else {
            return [defaultAction]
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
