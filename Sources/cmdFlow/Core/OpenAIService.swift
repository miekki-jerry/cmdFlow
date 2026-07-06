import Foundation

/// OpenAI client: chat completions via CloudChat.
enum OpenAIService {
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    static func transform(apiKey: String, model: String, instructions: String, input: String) async throws -> String {
        try await CloudChat.complete(
            endpoint: endpoint, providerName: "OpenAI",
            apiKey: apiKey, model: model, instructions: instructions, input: input
        )
    }

    static func chat(apiKey: String, bodyData: Data) async throws -> String {
        try await CloudChat.postJSON(
            endpoint: endpoint, providerName: "OpenAI",
            apiKey: apiKey, bodyData: bodyData
        )
    }

    static func stream(apiKey: String, bodyData: Data, onDelta: @Sendable (String) -> Void) async throws {
        try await CloudChat.streamJSON(
            endpoint: endpoint, providerName: "OpenAI",
            apiKey: apiKey, bodyData: bodyData, onDelta: onDelta
        )
    }

    // MARK: - Model listing (GET /v1/models, requires the key)

    private struct Model: Decodable { let id: String; let created: Int? }
    private struct ModelsResponse: Decodable { let data: [Model] }

    /// Chat-capable models from the account, newest first (filters out audio,
    /// embeddings, image, tts, etc.).
    static func listChatModels(apiKey: String) async throws -> [String] {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw CloudChat.ServiceError(message: "No OpenAI API key. Add it in the General tab.")
        }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CloudChat.ServiceError(
                message: http.statusCode == 401 ? "Invalid OpenAI API key (401)." : "OpenAI: HTTP error \(http.statusCode).")
        }
        let all = try JSONDecoder().decode(ModelsResponse.self, from: data).data
        let exclude = ["audio", "realtime", "embedding", "whisper", "tts", "dall-e",
                       "image", "moderation", "transcribe", "search", "instruct"]
        return all
            .filter { model in
                let id = model.id.lowercased()
                let isChat = id.hasPrefix("gpt-") || id.hasPrefix("o1") || id.hasPrefix("o3")
                    || id.hasPrefix("o4") || id.hasPrefix("chatgpt")
                return isChat && !exclude.contains { id.contains($0) }
            }
            .sorted { ($0.created ?? 0) > ($1.created ?? 0) }
            .map { $0.id }
    }
}
