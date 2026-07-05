import SwiftUI
import Carbon.HIToolbox

/// Pole nagrywania skrótu z dopracowaną animacją „nasłuchiwania".
struct ShortcutRecorder: View {
    @Binding var keyCode: UInt32?
    @Binding var modifiers: UInt32

    @State private var recording = false
    @State private var monitor: Any?
    @State private var breathing = false
    @State private var hovering = false
    @State private var warning: String?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            recorderButton
            statusLine
        }
        .onDisappear(perform: stopRecording)
    }

    // MARK: - Przycisk

    private var recorderButton: some View {
        Button(action: toggle) {
            ZStack {
                if recording { RadarRings() }
                capsuleContent
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: recording)
    }

    private var capsuleContent: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: recording)
                .foregroundStyle(recording ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Color.secondary))

            if recording {
                HStack(spacing: 5) {
                    Text("Nasłuchuję")
                        .font(.system(.callout, design: .rounded, weight: .medium))
                        .foregroundStyle(Palette.accentB)
                    AnimatedDots().foregroundStyle(Palette.accentB)
                }
            } else if let symbols = keySymbols {
                HStack(spacing: 4) {
                    ForEach(Array(symbols.enumerated()), id: \.offset) { _, s in
                        Keycap(text: s)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("Ustaw skrót")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if hovering && !recording && keyCode != nil {
                Button(action: clear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 130, alignment: .leading)
        .background(
            Capsule(style: .continuous)
                .fill(recording ? AnyShapeStyle(Palette.softGradient) : AnyShapeStyle(Color(nsColor: .controlBackgroundColor)))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    recording ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Color.primary.opacity(0.12)),
                    lineWidth: recording ? 2 : 1
                )
        )
        .shadow(color: Palette.accentB.opacity(recording && breathing ? 0.5 : 0.0),
                radius: recording && breathing ? 14 : 0)
        .scaleEffect(recording && breathing ? 1.015 : 1.0)
        .onChange(of: recording) { _, rec in
            withAnimation(rec ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default) {
                breathing = rec
            }
        }
    }

    private var iconName: String {
        if recording { return "dot.radiowaves.left.and.right" }
        return keyCode != nil ? "keyboard.fill" : "keyboard"
    }

    // MARK: - Status

    @ViewBuilder private var statusLine: some View {
        if recording {
            Text("Naciśnij kombinację  ·  ⎋ anuluje")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if let warning {
            Label(warning, systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .transition(.opacity)
        } else if let hint {
            Label(hint, systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
                .transition(.opacity)
        }
    }

    private var keySymbols: [String]? {
        guard let keyCode else { return nil }
        var arr = KeyCodes.modifierSymbols(modifiers).map { String($0) }
        arr.append(KeyCodes.keyName(keyCode))
        return arr
    }

    // MARK: - Nagrywanie

    private func toggle() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        warning = nil
        hint = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil // pochłoń zdarzenie
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func clear() {
        withAnimation {
            keyCode = nil
            modifiers = 0
            warning = nil
            hint = nil
        }
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .keyDown else { return }

        if event.keyCode == kVK_Escape,
           event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            stopRecording()
            return
        }

        let mods = KeyCodes.carbonModifiers(from: event.modifierFlags)
        guard KeyCodes.hasStrongModifier(mods) else {
            withAnimation { warning = "Dodaj ⌘, ⌃ lub ⌥ — sam znak to za mało." }
            return
        }

        let code = UInt32(event.keyCode)
        withAnimation {
            keyCode = code
            modifiers = mods
            if let conflict = ReservedShortcuts.conflict(modifiers: mods, keyCode: code) {
                warning = "Zwykle zajęty przez: \(conflict). Może nie zadziałać."
                hint = nil
            } else {
                warning = nil
                hint = "Skrót ustawiony"
            }
        }
        stopRecording()
    }
}

/// Rozchodzące się fale „radaru" widoczne podczas nasłuchiwania.
private struct RadarRings: View {
    @State private var animate = false
    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { i in
                Capsule(style: .continuous)
                    .stroke(Palette.accentB.opacity(0.55), lineWidth: 1.5)
                    .scaleEffect(animate ? 1.45 : 1.0)
                    .opacity(animate ? 0 : 0.55)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(Double(i) * 0.7),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}
