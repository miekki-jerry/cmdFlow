import AppKit
import Carbon.HIToolbox

/// Rejestruje globalne skróty przez Carbon RegisterEventHotKey.
/// Nie wymaga uprawnień Accessibility — to standardowy mechanizm globalnych skrótów na macOS.
/// Zdarzenia hot-key trafiają do handlera na głównym wątku.
@MainActor
final class HotKeyManager {
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// 'CMDF'
    private let signature: OSType = 0x434D4446

    init() {
        installHandler()
    }

    private func installHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else { return status }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated {
                    manager.handlers[hkID.id]?()
                }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandler
        )
    }

    /// Rejestruje skrót. Zwraca id rejestracji lub nil, gdy się nie powiodło.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> UInt32? {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return nil }
        refs[id] = ref
        handlers[id] = action
        return id
    }

    func unregister(id: UInt32) {
        if let ref = refs[id] {
            UnregisterEventHotKey(ref)
        }
        refs[id] = nil
        handlers[id] = nil
    }

    func unregisterAll() {
        for id in Array(refs.keys) {
            unregister(id: id)
        }
    }
}
