import Foundation

/// Klient OpenRouter: chat completions + listowanie modeli.
enum OpenRouterService {

    struct ServiceError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Modele

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
        /// true, gdy prompt i completion kosztują 0 (model darmowy).
        var isFree: Bool {
            (Double(pricing?.prompt ?? "1") ?? 1) == 0 && (Double(pricing?.completion ?? "1") ?? 1) == 0
        }
    }

    private struct ModelsResponse: Decodable { let data: [Model] }

    static func listModels() async throws -> [Model] {
        let url = URL(string: "https://openrouter.ai/api/v1/models")!
        let (data, response) = try await URLSession.shared.data(from: url)
        try ensureOK(response, data)
        return try JSONDecoder().decode(ModelsResponse.self, from: data).data
    }

    // MARK: - Transformacja

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String? }
            let message: Message
        }
        let choices: [Choice]
    }

    static func transform(apiKey: String, model: String, instructions: String, input: String) async throws -> String {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw ServiceError(message: "Brak klucza API OpenRouter. Wklej go w Ustawieniach.")
        }
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ServiceError(message: "Nie wybrano modelu OpenRouter.")
        }

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://github.com/miekki-jerry/cmdFlow", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("cmdFlow", forHTTPHeaderField: "X-Title")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": instructions],
                ["role": "user", "content": input]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try ensureOK(response, data)

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw ServiceError(message: "OpenRouter zwrócił pustą odpowiedź.")
        }
        return content
    }

    // MARK: - Pomocnicze

    private static func ensureOK(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let apiMessage = extractErrorMessage(data)
            switch http.statusCode {
            case 401: throw ServiceError(message: "Nieprawidłowy klucz API OpenRouter (401).")
            case 402: throw ServiceError(message: "Brak środków na koncie OpenRouter (402).")
            case 429: throw ServiceError(message: "Limit zapytań OpenRouter przekroczony (429).")
            default: throw ServiceError(message: apiMessage ?? "OpenRouter: błąd HTTP \(http.statusCode).")
            }
        }
    }

    private static func extractErrorMessage(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any],
              let message = error["message"] as? String
        else { return nil }
        return "OpenRouter: \(message)"
    }
}
