import Foundation

/// OpenRouter client: chat completions (via CloudChat) + model listing.
enum OpenRouterService {

    private static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private static let headers = [
        "HTTP-Referer": "https://github.com/miekki-jerry/cmdFlow",
        "X-Title": "cmdFlow"
    ]

    static func transform(apiKey: String, model: String, instructions: String, input: String,
                          webSearch: Bool = false) async throws -> String {
        try await CloudChat.complete(
            endpoint: endpoint, providerName: "OpenRouter",
            apiKey: apiKey, model: model, instructions: instructions, input: input,
            openRouterWebSearch: webSearch, extraHeaders: headers
        )
    }

    static func chat(apiKey: String, bodyData: Data) async throws -> String {
        try await CloudChat.postJSON(
            endpoint: endpoint, providerName: "OpenRouter",
            apiKey: apiKey, bodyData: bodyData, extraHeaders: headers
        )
    }

    static func stream(apiKey: String, bodyData: Data, onDelta: @Sendable (String) -> Void) async throws {
        try await CloudChat.streamJSON(
            endpoint: endpoint, providerName: "OpenRouter",
            apiKey: apiKey, bodyData: bodyData, extraHeaders: headers, onDelta: onDelta
        )
    }

    // MARK: - Models (for the search picker)

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
            throw CloudChat.ServiceError(message: "OpenRouter: HTTP error \(http.statusCode).")
        }
        return try JSONDecoder().decode(ModelsResponse.self, from: data).data
    }
}
