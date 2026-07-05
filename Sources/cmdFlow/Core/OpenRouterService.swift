import Foundation

/// Klient OpenRouter: chat completions (przez CloudChat) + listowanie modeli.
enum OpenRouterService {

    static func transform(apiKey: String, model: String, instructions: String, input: String) async throws -> String {
        try await CloudChat.complete(
            endpoint: URL(string: "https://openrouter.ai/api/v1/chat/completions")!,
            providerName: "OpenRouter",
            apiKey: apiKey,
            model: model,
            instructions: instructions,
            input: input,
            extraHeaders: [
                "HTTP-Referer": "https://github.com/miekki-jerry/cmdFlow",
                "X-Title": "cmdFlow"
            ]
        )
    }

    // MARK: - Modele (do wyszukiwarki)

    struct Model: Decodable, Identifiable, Equatable {
        let id: String
        let name: String?
        let context_length: Int?
        let pricing: Pricing?

        struct Pricing: Decodable, Equatable {
            let prompt: String?
            let completion: String?
        }

        var displayName: String { name ?? id }
        var isFree: Bool {
            (Double(pricing?.prompt ?? "1") ?? 1) == 0 && (Double(pricing?.completion ?? "1") ?? 1) == 0
        }
    }

    private struct ModelsResponse: Decodable { let data: [Model] }

    static func listModels() async throws -> [Model] {
        let url = URL(string: "https://openrouter.ai/api/v1/models")!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CloudChat.ServiceError(message: "OpenRouter: błąd HTTP \(http.statusCode).")
        }
        return try JSONDecoder().decode(ModelsResponse.self, from: data).data
    }
}
