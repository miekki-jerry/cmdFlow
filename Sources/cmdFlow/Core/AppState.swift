import AppKit
import Combine

/// Transient state shown in the menu bar icon.
enum Activity: Equatable {
    case idle
    case running(String)   // action name
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
        didSet { persistSettings(); reregisterHotKeys() }
    }
    /// API keys — stored in Keychain; these are just UI mirrors.
    /// Loaded lazily (when Settings opens) so the Keychain prompt doesn't block launch.
    @Published var openRouterKey: String = "" {
        didSet { if !isLoadingKeys { Keychain.set(openRouterKey, account: Keychain.openRouterAccount) } }
    }
    @Published var openAIKey: String = "" {
        didSet { if !isLoadingKeys { Keychain.set(openAIKey, account: Keychain.openAIAccount) } }
    }
    private var isLoadingKeys = false
    private var keysLoaded = false
    @Published private(set) var modelStatus: ModelStatus = .unavailable("Checking…")
    @Published private(set) var activity: Activity = .idle
    @Published private(set) var launchAtLogin: Bool = false

    let history = SnapHistory()

    private let hotKeys = HotKeyManager()
    private let regionSelector = RegionSelector()
    private let snapChat = SnapChatController()
    private let promptPill = SnapPromptPill()
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
            modelStatus = .unavailable("Requires macOS 26 or later.")
        }
        launchAtLogin = LaunchAtLogin.isEnabled
        reregisterHotKeys()
    }

    // MARK: - API keys (lazy load)

    /// Loads keys from Keychain into the UI mirrors. Called when Settings opens.
    func loadKeys() {
        guard !keysLoaded else { return }
        keysLoaded = true
        isLoadingKeys = true
        openRouterKey = Keychain.get(account: Keychain.openRouterAccount)
        openAIKey = Keychain.get(account: Keychain.openAIAccount)
        isLoadingKeys = false
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        try? LaunchAtLogin.set(enabled)
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: - Actions CRUD

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

    // MARK: - Shortcut registration

    private func reregisterHotKeys() {
        hotKeys.unregisterAll()
        for action in actions where action.enabled {
            guard let keyCode = action.keyCode, action.modifiers != 0 else { continue }
            let id = action.id
            hotKeys.register(keyCode: keyCode, modifiers: action.modifiers) { [weak self] in
                self?.trigger(actionID: id)
            }
        }
        if settings.screenshotChatEnabled,
           let keyCode = settings.screenshotKeyCode, settings.screenshotModifiers != 0 {
            hotKeys.register(keyCode: keyCode, modifiers: settings.screenshotModifiers) { [weak self] in
                self?.startScreenshotChat()
            }
        }
    }

    // MARK: - Screenshot chat (vision)

    func startScreenshotChat() {
        regionSelector.begin { [weak self] rect, screen in
            guard let self, let rect, let screen else { return }
            Task { await self.captureAndPromptPill(rect: rect, screen: screen) }
        }
    }

    /// Reopens a saved session from the Chats tab.
    func reopenSession(_ session: SnapSession) {
        openPanel(session: session, image: ScreenCapture.image(fromBase64PNG: session.imageBase64))
    }

    private func captureAndPromptPill(rect: CGRect, screen: NSScreen) async {
        guard let displayID = screen.displayID else {
            setActivity(.failure("Couldn't find the display")); return
        }
        let frame = screen.frame
        let scale = screen.backingScaleFactor
        do {
            let image = try await ScreenCapture.capture(
                globalRect: rect, displayID: displayID, screenFrame: frame, scale: scale)
            guard let base64 = ScreenCapture.pngBase64(image) else {
                setActivity(.failure("Couldn't encode the screenshot")); return
            }
            playSound("Glass")
            promptPill.present(near: rect, onSubmit: { [weak self] question in
                self?.beginSession(imageBase64: base64, image: image, firstQuestion: question)
            }, onCancel: {})
        } catch {
            setActivity(.failure(error.localizedDescription))
            NSSound.beep()
        }
    }

    private func beginSession(imageBase64: String, image: NSImage, firstQuestion: String) {
        let session = SnapSession(createdAt: Date(), imageBase64: imageBase64,
                                  turns: [SnapTurn(user: true, text: firstQuestion)])
        history.upsert(session)
        openPanel(session: session, image: image)
    }

    private func openPanel(session: SnapSession, image: NSImage?) {
        let sessionID = session.id
        let createdAt = session.createdAt
        let base64 = session.imageBase64
        snapChat.present(
            image: image,
            initialTurns: session.turns,
            send: { [weak self] turns in
                guard let self else { return SnapReply.failure("cmdFlow is unavailable") }
                return await self.answer(for: turns, imageBase64: base64)
            },
            persist: { [weak self] turns in
                self?.history.upsert(SnapSession(id: sessionID, createdAt: createdAt,
                                                 imageBase64: base64, turns: turns))
            }
        )
    }

    private func answer(for turns: [SnapTurn], imageBase64: String) async -> SnapReply {
        let provider = settings.screenshotProvider
        let model = provider == .openRouter ? settings.openRouterVisionModel : settings.openAIVisionModel
        guard !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .failure("No vision model selected.")
        }
        let messages = buildMessages(turns: turns, imageBase64: imageBase64,
                                     systemPrompt: settings.screenshotSystemPrompt)
        // Serialize on the main actor so only Sendable `Data` crosses isolation.
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: ["model": model, "messages": messages])
        } catch {
            return .failure("Couldn't build the request.")
        }
        do {
            let content: String
            switch provider {
            case .openRouter:
                content = try await OpenRouterService.chat(
                    apiKey: Keychain.get(account: Keychain.openRouterAccount), bodyData: bodyData)
            case .openAI:
                content = try await OpenAIService.chat(
                    apiKey: Keychain.get(account: Keychain.openAIAccount), bodyData: bodyData)
            }
            return .answer(content)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    /// Builds the OpenAI-format messages array; the image is attached to the first user turn.
    private func buildMessages(turns: [SnapTurn], imageBase64: String, systemPrompt: String) -> [[String: Any]] {
        var messages: [[String: Any]] = [["role": "system", "content": systemPrompt]]
        var attachedImage = false
        for turn in turns {
            if turn.user {
                if !attachedImage {
                    attachedImage = true
                    messages.append(["role": "user", "content": [
                        ["type": "text", "text": turn.text],
                        ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(imageBase64)"]]
                    ]])
                } else {
                    messages.append(["role": "user", "content": turn.text])
                }
            } else {
                messages.append(["role": "assistant", "content": turn.text])
            }
        }
        return messages
    }

    // MARK: - Running

    private func trigger(actionID: UUID) {
        guard let action = actions.first(where: { $0.id == actionID }) else { return }
        Task { await run(action) }
    }

    /// Public entry point (shortcut, menu, "Run now" button).
    func run(_ action: PromptAction) async {
        guard let input = Clipboard.readString(), !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setActivity(.failure("Clipboard is empty"))
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

    /// Routes the request to the right backend based on the selected mode.
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
                // Apple refused (e.g. language) or is unavailable — try the cloud.
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
            throw RunError(message: "The Apple model requires macOS 26+.")
        }
        let status = FoundationModelService.status()
        modelStatus = status
        guard status == .available else {
            if case .unavailable(let reason) = status { throw RunError(message: reason) }
            throw RunError(message: "The Apple model is unavailable.")
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

    // MARK: - Persistence

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
            name: "Translate to English",
            keyCode: nil,
            modifiers: 0,
            prompt: "You are a translation engine. Translate the user's text to English. Output only the translation, with no greetings, notes, or commentary.",
            enabled: true
        )
    }
}
