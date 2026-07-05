import AppKit
import Carbon.HIToolbox

/// Konwersje i opisy klawiszy. NSEvent.keyCode jest tożsame z wirtualnym keyCode Carbon,
/// więc tę samą wartość podajemy do RegisterEventHotKey.
enum KeyCodes {

    // MARK: - Modyfikatory

    /// NSEvent.ModifierFlags -> maska Carbon (cmdKey/optionKey/controlKey/shiftKey).
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    /// Czy maska zawiera przynajmniej jeden „mocny" modyfikator (⌘/⌃/⌥)?
    /// Sam Shift nie wystarcza dla globalnego skrótu.
    static func hasStrongModifier(_ modifiers: UInt32) -> Bool {
        modifiers & (UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey)) != 0
    }

    static func modifierSymbols(_ modifiers: UInt32) -> String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s
    }

    // MARK: - Nazwa klawisza

    static func keyName(_ keyCode: UInt32) -> String {
        if let special = specialKeys[Int(keyCode)] { return special }
        if let ch = character(for: keyCode) { return ch.uppercased() }
        return "?"
    }

    /// Pełny opis skrótu, np. „⌘⇧T".
    static func describe(keyCode: UInt32?, modifiers: UInt32) -> String? {
        guard let keyCode else { return nil }
        return modifierSymbols(modifiers) + keyName(keyCode)
    }

    /// Odczyt znaku dla keyCode wg bieżącego układu klawiatury.
    private static func character(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        var result: String?
        data.withUnsafeBytes { raw in
            guard let ptr = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return }
            var deadKeyState: UInt32 = 0
            var length = 0
            var chars = [UniChar](repeating: 0, count: 4)
            let status = UCKeyTranslate(
                ptr,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &length,
                &chars
            )
            if status == noErr, length > 0 {
                result = String(utf16CodeUnits: chars, count: length)
            }
        }
        return result
    }

    private static let specialKeys: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_Escape: "⎋", kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
        kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
        kVK_F11: "F11", kVK_F12: "F12"
    ]
}
