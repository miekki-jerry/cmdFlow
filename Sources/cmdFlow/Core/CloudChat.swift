import Foundation

/// Shared client for the OpenAI-format chat/completions endpoint.
/// Used by both OpenRouter and OpenAI.
enum CloudChat {
    struct ServiceError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    static func complete(
        endpoint: URL,
        providerName: String,
        apiKey: String,
        model: String,
        instructions: String,
        input: String,
        extraHeaders: [String: String] = [:]
    ) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw ServiceError(message: "No \(providerName) API key. Paste one in Settings.")
        }
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError(message: "No \(providerName) model selected.")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": instructions],
                ["role": "user", "content": input]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response, data, providerName: providerName)

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw ServiceError(message: "\(providerName) returned an empty response.")
        }
        return content
    }

    private static func ensureOK(_ response: URLResponse, _ data: Data, providerName: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let apiMessage = extractErrorMessage(data)
            switch http.statusCode {
            case 401: throw ServiceError(message: "Invalid \(providerName) API key (401).")
            case 402: throw ServiceError(message: "No credit on your \(providerName) account (402).")
            case 429: throw ServiceError(message: "\(providerName) rate limit exceeded (429).")
            default: throw ServiceError(message: apiMessage ?? "\(providerName): HTTP error \(http.statusCode).")
            }
        }
    }

    private static func extractErrorMessage(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any],
              let message = error["message"] as? String
        else { return nil }
        return message
    }
}
