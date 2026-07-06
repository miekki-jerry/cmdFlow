import Foundation

/// OpenAI client: chat completions via CloudChat.
enum OpenAIService {
    /// Common chat models for quick selection in Settings.
    static let suggestedModels = [
        "gpt-5.5",
        "gpt-5.4",
        "gpt-5.4-mini",
        "gpt-5.4-nano",
        "gpt-5-mini",
        "gpt-4.1-mini"
    ]

    /// Vision-capable OpenAI models suggested for the screenshot chat.
    static let suggestedVisionModels = ["gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-4o"]

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
