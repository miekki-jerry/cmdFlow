import Foundation
import FoundationModels

/// Thin layer over Apple Foundation Models (on-device model, Apple Intelligence).
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
            return .unavailable("Unknown model status.")
        }
    }

    /// Error translated into a readable user-facing message.
    struct FriendlyError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Runs `input` (clipboard text) through `instructions` (the user prompt).
    /// The model's guardrail can non-deterministically reject a language (e.g. Polish) —
    /// in that case we retry once, and on a second failure return a clear message.
    static func transform(instructions: String, input: String) async throws -> String {
        do {
            return try await respond(instructions: instructions, input: input)
        } catch let error as LanguageModelSession.GenerationError {
            if case .unsupportedLanguageOrLocale = error {
                // Retry once — the same text can pass on a second attempt.
                do {
                    return try await respond(instructions: instructions, input: input)
                } catch {
                    throw FriendlyError(message: "The model rejected the text's language. Apple Intelligence doesn't officially support Polish yet — try a shorter passage or an English instruction.")
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
            return "The text is too long for the model. Shorten the clipboard content."
        case .guardrailViolation:
            return "The model blocked the content for safety reasons."
        default:
            return "The model couldn't process the text. Try again."
        }
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Enable Apple Intelligence in System Settings."
        case .modelNotReady:
            return "The model is downloading or preparing. Try again shortly."
        @unknown default:
            return "The model is temporarily unavailable."
        }
    }
}
