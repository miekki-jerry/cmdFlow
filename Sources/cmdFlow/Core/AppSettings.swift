import Foundation

/// Which mode processes the text.
enum ProviderMode: String, Codable, CaseIterable, Identifiable {
    case appleOnly            // Apple on-device model only
    case appleWithFallback    // Apple, with a cloud fallback if it refuses
    case cloud                // cloud provider only

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appleOnly: return "Apple (on-device)"
        case .appleWithFallback: return "Apple + fallback"
        case .cloud: return "Cloud"
        }
    }

    var usesApple: Bool { self != .cloud }
    var usesCloud: Bool { self != .appleOnly }
}

/// Cloud provider (OpenAI-API compatible).
enum CloudProvider: String, Codable, CaseIterable, Identifiable {
    case openRouter
    case openAI

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openRouter: return "OpenRouter"
        case .openAI: return "OpenAI"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openRouter: return "sk-or-…"
        case .openAI: return "sk-…"
        }
    }

    var keysURL: String {
        switch self {
        case .openRouter: return "openrouter.ai/keys"
        case .openAI: return "platform.openai.com/api-keys"
        }
    }
}

/// App settings (no secrets — API keys live in the Keychain).
struct AppSettings: Codable, Equatable {
    var providerMode: ProviderMode = .appleOnly
    var cloudProvider: CloudProvider = .openRouter
    var openRouterModel: String = "openai/gpt-5.4-mini"
    var openAIModel: String = "gpt-5.4-mini"

    // Screenshot chat (vision). Cloud-only — Apple's model is text-only. Has its own provider.
    var screenshotChatEnabled: Bool = false
    var screenshotKeyCode: UInt32? = nil
    var screenshotModifiers: UInt32 = 0
    var screenshotProvider: CloudProvider = .openRouter
    var openRouterVisionModel: String = "openai/gpt-5.4"
    var openAIVisionModel: String = "gpt-5.4"
    var screenshotSystemPrompt: String = AppSettings.defaultScreenshotSystemPrompt

    static let defaultScreenshotSystemPrompt =
        "You are a helpful assistant. Answer the user's questions about the attached screenshot. Be concise and specific, and use the same language as the question."

    init() {}

    enum CodingKeys: String, CodingKey {
        case providerMode, cloudProvider, openRouterModel, openAIModel
        case screenshotChatEnabled, screenshotKeyCode, screenshotModifiers
        case screenshotProvider, openRouterVisionModel, openAIVisionModel
        case screenshotSystemPrompt
    }
}

extension AppSettings {
    /// Decoder tolerant of missing fields and migrating the legacy `openRouterOnly` value.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawMode = (try? c.decodeIfPresent(String.self, forKey: .providerMode)) ?? nil

        switch rawMode {
        case "cloud", "openRouterOnly", "openAIOnly":
            providerMode = .cloud
        case "appleWithFallback":
            providerMode = .appleWithFallback
        default:
            providerMode = .appleOnly
        }

        // Migration: the legacy "OpenRouter only" mode sets the cloud provider.
        if rawMode == "openRouterOnly" {
            cloudProvider = .openRouter
        } else if rawMode == "openAIOnly" {
            cloudProvider = .openAI
        } else {
            let rawCloud = (try? c.decodeIfPresent(String.self, forKey: .cloudProvider)) ?? nil
            cloudProvider = CloudProvider(rawValue: rawCloud ?? "openRouter") ?? .openRouter
        }

        openRouterModel = ((try? c.decodeIfPresent(String.self, forKey: .openRouterModel)) ?? nil) ?? "openai/gpt-5.4-mini"
        openAIModel = ((try? c.decodeIfPresent(String.self, forKey: .openAIModel)) ?? nil) ?? "gpt-5.4-mini"

        screenshotChatEnabled = ((try? c.decodeIfPresent(Bool.self, forKey: .screenshotChatEnabled)) ?? nil) ?? false
        screenshotKeyCode = (try? c.decodeIfPresent(UInt32.self, forKey: .screenshotKeyCode)) ?? nil
        screenshotModifiers = ((try? c.decodeIfPresent(UInt32.self, forKey: .screenshotModifiers)) ?? nil) ?? 0
        let rawShotProvider = (try? c.decodeIfPresent(String.self, forKey: .screenshotProvider)) ?? nil
        screenshotProvider = CloudProvider(rawValue: rawShotProvider ?? "openRouter") ?? .openRouter
        openRouterVisionModel = ((try? c.decodeIfPresent(String.self, forKey: .openRouterVisionModel)) ?? nil) ?? "openai/gpt-5.4"
        openAIVisionModel = ((try? c.decodeIfPresent(String.self, forKey: .openAIVisionModel)) ?? nil) ?? "gpt-5.4"
        let sysPrompt = ((try? c.decodeIfPresent(String.self, forKey: .screenshotSystemPrompt)) ?? nil) ?? ""
        screenshotSystemPrompt = sysPrompt.isEmpty ? AppSettings.defaultScreenshotSystemPrompt : sysPrompt
    }
}
