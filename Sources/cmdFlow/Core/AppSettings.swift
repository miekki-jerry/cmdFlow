import Foundation

/// Który backend przetwarza tekst.
enum ProviderMode: String, Codable, CaseIterable, Identifiable {
    case appleOnly            // tylko model on-device Apple
    case appleWithFallback    // Apple, a przy odmowie fallback do OpenRouter
    case openRouterOnly       // wyłącznie OpenRouter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appleOnly: return "Apple (on-device)"
        case .appleWithFallback: return "Apple + fallback"
        case .openRouterOnly: return "OpenRouter"
        }
    }

    var usesOpenRouter: Bool { self != .appleOnly }
    var usesApple: Bool { self != .openRouterOnly }
}

/// Ustawienia aplikacji (bez sekretu — klucz API trzymamy w Keychain).
struct AppSettings: Codable, Equatable {
    var providerMode: ProviderMode = .appleOnly
    var openRouterModel: String = "openai/gpt-4o-mini"
}
