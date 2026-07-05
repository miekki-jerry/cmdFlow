import Foundation

/// Który tryb przetwarza tekst.
enum ProviderMode: String, Codable, CaseIterable, Identifiable {
    case appleOnly            // tylko model on-device Apple
    case appleWithFallback    // Apple, a przy odmowie fallback do chmury
    case cloud                // wyłącznie provider chmurowy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appleOnly: return "Apple (on-device)"
        case .appleWithFallback: return "Apple + fallback"
        case .cloud: return "Chmura"
        }
    }

    var usesApple: Bool { self != .cloud }
    var usesCloud: Bool { self != .appleOnly }
}

/// Provider chmurowy (kompatybilny z OpenAI API).
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

/// Ustawienia aplikacji (bez sekretów — klucze API trzymamy w Keychain).
struct AppSettings: Codable, Equatable {
    var providerMode: ProviderMode = .appleOnly
    var cloudProvider: CloudProvider = .openRouter
    var openRouterModel: String = "openai/gpt-4o-mini"
    var openAIModel: String = "gpt-4o-mini"

    init() {}

    enum CodingKeys: String, CodingKey {
        case providerMode, cloudProvider, openRouterModel, openAIModel
    }
}

extension AppSettings {
    /// Dekoder odporny na braki pól i migrujący starą wartość `openRouterOnly`.
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

        // Migracja: stary tryb „tylko OpenRouter" ustawia providera chmurowego.
        if rawMode == "openRouterOnly" {
            cloudProvider = .openRouter
        } else if rawMode == "openAIOnly" {
            cloudProvider = .openAI
        } else {
            let rawCloud = (try? c.decodeIfPresent(String.self, forKey: .cloudProvider)) ?? nil
            cloudProvider = CloudProvider(rawValue: rawCloud ?? "openRouter") ?? .openRouter
        }

        openRouterModel = ((try? c.decodeIfPresent(String.self, forKey: .openRouterModel)) ?? nil) ?? "openai/gpt-4o-mini"
        openAIModel = ((try? c.decodeIfPresent(String.self, forKey: .openAIModel)) ?? nil) ?? "gpt-4o-mini"
    }
}
