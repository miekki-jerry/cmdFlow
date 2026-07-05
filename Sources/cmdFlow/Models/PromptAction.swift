import Foundation

/// Jedna akcja: globalny skrót klawiszowy -> prompt przepuszczający tekst ze schowka
/// przez model Apple Foundation, wynik trafia z powrotem do schowka.
struct PromptAction: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    /// Wirtualny keyCode (NSEvent.keyCode == Carbon virtual key). nil = skrót nieprzypisany.
    var keyCode: UInt32?
    /// Maska modyfikatorów w formacie Carbon (cmdKey, optionKey, controlKey, shiftKey).
    var modifiers: UInt32
    /// Instrukcja/prompt dla modelu. Tekst ze schowka jest przekazywany jako wiadomość użytkownika.
    var prompt: String
    var enabled: Bool = true

    var hasShortcut: Bool { keyCode != nil && modifiers != 0 }

    static func newTemplate() -> PromptAction {
        PromptAction(
            name: "Nowa akcja",
            keyCode: nil,
            modifiers: 0,
            prompt: "You are a translation engine. Translate the user's text to English. Output only the translation, with no greetings, notes, or commentary.",
            enabled: true
        )
    }
}
