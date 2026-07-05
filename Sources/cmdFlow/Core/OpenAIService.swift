import Foundation

/// OpenAI client: chat completions via CloudChat.
enum OpenAIService {
    /// Common chat models for quick selection in Settings.
    static let suggestedModels = [
        "gpt-4o-mini",
        "gpt-4o",
        "gpt-4.1",
        "gpt-4.1-mini",
        "gpt-4.1-nano",
        "o4-mini"
    ]

    static func transform(apiKey: String, model: String, instructions: String, input: String) async throws -> String {
        try await CloudChat.complete(
            endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
            providerName: "OpenAI",
            apiKey: apiKey,
            model: model,
            instructions: instructions,
            input: input
        )
    }
}
