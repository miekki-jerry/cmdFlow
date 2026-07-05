import Carbon.HIToolbox

/// Heuristic list of common macOS system shortcuts.
///
/// Note: fully reliable detection of globally-taken shortcuts needs private APIs
/// (CGSGetSymbolicHotKeyValue). Instead we warn about the most common collisions;
/// the real test is whether `RegisterEventHotKey` actually receives the event.
enum ReservedShortcuts {

    struct Entry {
        let name: String
        let modifiers: UInt32
        let keyCode: UInt32
    }

    static let all: [Entry] = [
        Entry(name: "Spotlight", modifiers: cmd, keyCode: UInt32(kVK_Space)),
        Entry(name: "Character / emoji viewer", modifiers: ctrl | cmd, keyCode: UInt32(kVK_Space)),
        Entry(name: "Switch apps", modifiers: cmd, keyCode: UInt32(kVK_Tab)),
        Entry(name: "Quit app", modifiers: cmd, keyCode: UInt32(kVK_ANSI_Q)),
        Entry(name: "Close window", modifiers: cmd, keyCode: UInt32(kVK_ANSI_W)),
        Entry(name: "Hide app", modifiers: cmd, keyCode: UInt32(kVK_ANSI_H)),
        Entry(name: "Screenshot (area)", modifiers: shift | cmd, keyCode: UInt32(kVK_ANSI_4)),
        Entry(name: "Screenshot (full)", modifiers: shift | cmd, keyCode: UInt32(kVK_ANSI_3)),
        Entry(name: "Screenshot tool", modifiers: shift | cmd, keyCode: UInt32(kVK_ANSI_5)),
        Entry(name: "Force Quit", modifiers: opt | cmd, keyCode: UInt32(kVK_Escape)),
    ]

    /// Returns the system feature name if the combination collides with a common shortcut.
    static func conflict(modifiers: UInt32, keyCode: UInt32) -> String? {
        all.first { $0.modifiers == modifiers && $0.keyCode == keyCode }?.name
    }

    private static let cmd = UInt32(cmdKey)
    private static let ctrl = UInt32(controlKey)
    private static let opt = UInt32(optionKey)
    private static let shift = UInt32(shiftKey)
}
