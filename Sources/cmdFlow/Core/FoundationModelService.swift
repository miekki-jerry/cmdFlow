import Foundation
import FoundationModels

/// Cienka warstwa nad Apple Foundation Models (model on-device, Apple Intelligence).
enum ModelStatus: Equatable {
    case available
    case unavailable(String)
}

@available(macOS 26.0, *)
enum FoundationModelService {

    static func status() -> ModelStatus {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(describe(reason))
        @unknown default:
            return .unavailable("Nieznany status modelu.")
        }
    }

    /// Błąd tłumaczony na czytelny komunikat dla użytkownika.
    struct FriendlyError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Przepuszcza `input` (tekst ze schowka) przez `instructions` (prompt użytkownika).
    /// Guardrail modelu potrafi niedeterministycznie odrzucić język (np. polski) —
    /// w takim wypadku ponawiamy raz, a przy powtórnym błędzie zwracamy jasny komunikat.
    static func transform(instructions: String, input: String) async throws -> String {
        do {
            return try await respond(instructions: instructions, input: input)
        } catch let error as LanguageModelSession.GenerationError {
            if case .unsupportedLanguageOrLocale = error {
                // Ponów raz — ten sam tekst potrafi przejść za drugim razem.
                do {
                    return try await respond(instructions: instructions, input: input)
                } catch {
                    throw FriendlyError(message: "Model odrzucił język tekstu. Apple Intelligence nie wspiera jeszcze oficjalnie m.in. polskiego — spróbuj krótszego fragmentu lub instrukcji po angielsku.")
                }
            }
            throw FriendlyError(message: friendly(error))
        }
    }

    private static func respond(instructions: String, input: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(to: input)
        return response.content
    }

    private static func friendly(_ error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            return "Tekst jest za długi dla modelu. Skróć zawartość schowka."
        case .guardrailViolation:
            return "Model zablokował treść ze względów bezpieczeństwa."
        default:
            return "Model nie zdołał przetworzyć tekstu. Spróbuj ponownie."
        }
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "To urządzenie nie obsługuje Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Włącz Apple Intelligence w Ustawieniach systemowych."
        case .modelNotReady:
            return "Model się pobiera lub przygotowuje. Spróbuj za chwilę."
        @unknown default:
            return "Model jest chwilowo niedostępny."
        }
    }
}
