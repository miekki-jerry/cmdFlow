import SwiftUI
import Carbon.HIToolbox

/// Pole nagrywania skrótu z animacją „nasłuchiwania".
/// Podczas nagrywania przechwytuje kolejne zdarzenie klawiatury (lokalny monitor),
/// waliduje modyfikatory i ostrzega o kolizji z popularnym skrótem systemowym.
struct ShortcutRecorder: View {
    @Binding var keyCode: UInt32?
    @Binding var modifiers: UInt32

    @State private var recording = false
    @State private var monitor: Any?
    @State private var pulse = false
    @State private var warning: String?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: toggle) {
                HStack(spacing: 6) {
                    Image(systemName: recording ? "dot.radiowaves.left.and.right" : "keyboard")
                        .foregroundStyle(recording ? Color.accentColor : .secondary)
                    Text(label)
                        .font(.system(.body, design: .rounded))
                        .monospaced()
                        .frame(minWidth: 90, alignment: .leading)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(recording ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            recording ? Color.accentColor : Color.secondary.opacity(0.3),
                            lineWidth: recording ? 2 : 1
                        )
                        .scaleEffect(recording && pulse ? 1.04 : 1.0)
                        .opacity(recording && pulse ? 0.5 : 1.0)
                )
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)

            if recording {
                HStack(spacing: 8) {
                    Text("Naciśnij kombinację…  ⎋ anuluje")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if keyCode != nil {
                        Button("Wyczyść", role: .destructive, action: clear)
                            .buttonStyle(.plain)
                            .font(.caption2)
                    }
                }
            }
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else if let hint {
                Label(hint, systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var label: String {
        if recording { return "Nasłuchuję…" }
        return KeyCodes.describe(keyCode: keyCode, modifiers: modifiers) ?? "Ustaw skrót"
    }

    private func toggle() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        pulse = true
        warning = nil
        hint = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil // pochłoń zdarzenie
        }
    }

    private func stopRecording() {
        recording = false
        pulse = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func clear() {
        keyCode = nil
        modifiers = 0
        warning = nil
        hint = nil
        stopRecording()
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .keyDown else { return } // flagsChanged tylko dla wizualnego feedbacku

        if event.keyCode == kVK_Escape && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            stopRecording()
            return
        }

        let mods = KeyCodes.carbonModifiers(from: event.modifierFlags)
        guard KeyCodes.hasStrongModifier(mods) else {
            warning = "Dodaj ⌘, ⌃ lub ⌥ — sam znak to za mało dla globalnego skrótu."
            return
        }

        let code = UInt32(event.keyCode)
        keyCode = code
        modifiers = mods

        if let conflict = ReservedShortcuts.conflict(modifiers: mods, keyCode: code) {
            warning = "Ten skrót jest zwykle zajęty przez: \(conflict). Może nie zadziałać."
            hint = nil
        } else {
            warning = nil
            hint = "Skrót ustawiony."
        }
        stopRecording()
    }
}
