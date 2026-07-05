import Foundation

/// One action: a global shortcut -> a prompt that runs the clipboard text
/// through the model, with the result written back to the clipboard.
struct PromptAction: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    /// Virtual keyCode (NSEvent.keyCode == Carbon virtual key). nil = no shortcut assigned.
    var keyCode: UInt32?
    /// Modifier mask in Carbon format (cmdKey, optionKey, controlKey, shiftKey).
    var modifiers: UInt32
    /// Instruction/prompt for the model. Clipboard text is passed as the user message.
    var prompt: String
    var enabled: Bool = true

    var hasShortcut: Bool { keyCode != nil && modifiers != 0 }

    static func newTemplate() -> PromptAction {
        PromptAction(
            name: "New action",
            keyCode: nil,
            modifiers: 0,
            prompt: "You are a translation engine. Translate the user's text to English. Output only the translation, with no greetings, notes, or commentary.",
            enabled: true
        )
    }
}
