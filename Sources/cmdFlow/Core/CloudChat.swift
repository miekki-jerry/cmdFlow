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

    /// - Parameter imageBase64PNG: optional base64 PNG for vision (attached as an `image_url`
    ///   data URL). Both OpenAI and OpenRouter accept this via chat/completions.
    static func complete(
        endpoint: URL,
        providerName: String,
        apiKey: String,
        model: String,
        instructions: String,
        input: String,
        imageBase64PNG: String? = nil,
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

        let userContent: Any
        if let image = imageBase64PNG {
            userContent = [
                ["type": "text", "text": input],
                ["type": "image_url", "image_url": ["url": "data:image/png;base64,\(image)"]]
            ]
        } else {
            userContent = input
        }

        let messages: [[String: Any]] = [
            ["role": "system", "content": instructions],
            ["role": "user", "content": userContent]
        ]
        return try await send(request: request, model: model, messages: messages,
                              providerName: providerName)
    }

    /// Multi-turn variant: caller supplies the already-serialized request body
    /// (`{"model": …, "messages": […]}`) as `Data`, which is Sendable.
    static func postJSON(
        endpoint: URL,
        providerName: String,
        apiKey: String,
        bodyData: Data,
        extraHeaders: [String: String] = [:]
    ) async throws -> String {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw ServiceError(message: "No \(providerName) API key. Paste one in Settings.")
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in extraHeaders { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = bodyData
        return try await perform(request, providerName: providerName)
    }

    private static func send(request: URLRequest, model: String,
                             messages: [[String: Any]], providerName: String) async throws -> String {
        var request = request
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "messages": messages])
        return try await perform(request, providerName: providerName)
    }

    /// Streams a chat completion (SSE). `bodyData` must include `"stream": true`.
    /// Calls `onDelta` with each content chunk as it arrives.
    static func streamJSON(
        endpoint: URL,
        providerName: String,
        apiKey: String,
        bodyData: Data,
        extraHeaders: [String: String] = [:],
        onDelta: @Sendable (String) -> Void
    ) async throws {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw ServiceError(message: "No \(providerName) API key. Paste one in Settings.")
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        for (name, value) in extraHeaders { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = bodyData

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            switch http.statusCode {
            case 401: throw ServiceError(message: "Invalid \(providerName) API key (401).")
            case 402: throw ServiceError(message: "No credit on your \(providerName) account (402).")
            case 429: throw ServiceError(message: "\(providerName) rate limit exceeded (429).")
            default: throw ServiceError(message: "\(providerName): HTTP error \(http.statusCode).")
            }
        }

        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String
            else { continue }
            onDelta(content)
        }
    }

    private static func perform(_ request: URLRequest, providerName: String) async throws -> String {
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
