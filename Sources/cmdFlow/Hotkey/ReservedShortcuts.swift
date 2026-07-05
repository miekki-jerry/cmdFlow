import Carbon.HIToolbox

/// Heurystyczna lista popularnych skrótów systemowych macOS.
///
/// Uwaga: pełne, pewne wykrycie zajętych globalnie skrótów wymaga prywatnych API
/// (CGSGetSymbolicHotKeyValue). Zamiast tego ostrzegamy o najczęstszych kolizjach,
/// a właściwym testem jest to, czy `RegisterEventHotKey` faktycznie odbierze zdarzenie.
enum ReservedShortcuts {

    struct Entry {
        let name: String
        let modifiers: UInt32
        let keyCode: UInt32
    }

    static let all: [Entry] = [
        Entry(name: "Spotlight", modifiers: cmd, keyCode: UInt32(kVK_Space)),
        Entry(name: "Podgląd znaków / emoji", modifiers: ctrl | cmd, keyCode: UInt32(kVK_Space)),
        Entry(name: "Przełączanie aplikacji", modifiers: cmd, keyCode: UInt32(kVK_Tab)),
        Entry(name: "Zamknij aplikację", modifiers: cmd, keyCode: UInt32(kVK_ANSI_Q)),
        Entry(name: "Zamknij okno", modifiers: cmd, keyCode: UInt32(kVK_ANSI_W)),
        Entry(name: "Ukryj aplikację", modifiers: cmd, keyCode: UInt32(kVK_ANSI_H)),
        Entry(name: "Zrzut ekranu (obszar)", modifiers: shift | cmd, keyCode: UInt32(kVK_ANSI_4)),
        Entry(name: "Zrzut ekranu (cały)", modifiers: shift | cmd, keyCode: UInt32(kVK_ANSI_3)),
        Entry(name: "Narzędzie zrzutu ekranu", modifiers: shift | cmd, keyCode: UInt32(kVK_ANSI_5)),
        Entry(name: "Wymuś zamknięcie", modifiers: opt | cmd, keyCode: UInt32(kVK_Escape)),
    ]

    /// Zwraca nazwę systemowej funkcji, jeśli kombinacja koliduje z popularnym skrótem.
    static func conflict(modifiers: UInt32, keyCode: UInt32) -> String? {
        all.first { $0.modifiers == modifiers && $0.keyCode == keyCode }?.name
    }

    private static let cmd = UInt32(cmdKey)
    private static let ctrl = UInt32(controlKey)
    private static let opt = UInt32(optionKey)
    private static let shift = UInt32(shiftKey)
}
