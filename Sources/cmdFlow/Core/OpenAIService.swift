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

    /// Vision-capable OpenAI models suggested for the screenshot chat.
    static let suggestedVisionModels = ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini"]

    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    static func transform(apiKey: String, model: String, instructions: String, input: String) async throws -> String {
        try await CloudChat.complete(
            endpoint: endpoint, providerName: "OpenAI",
            apiKey: apiKey, model: model, instructions: instructions, input: input
        )
    }

    static func transformVision(apiKey: String, model: String, instructions: String, input: String, imageBase64PNG: String) async throws -> String {
        try await CloudChat.complete(
            endpoint: endpoint, providerName: "OpenAI",
            apiKey: apiKey, model: model, instructions: instructions, input: input,
            imageBase64PNG: imageBase64PNG
        )
    }
}
