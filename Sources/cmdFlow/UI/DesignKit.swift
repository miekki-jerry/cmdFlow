import SwiftUI

/// Wspólny język wizualny aplikacji.
enum Palette {
    static let accentA = Color(red: 0.36, green: 0.42, blue: 0.98)
    static let accentB = Color(red: 0.55, green: 0.30, blue: 0.95)

    static var gradient: LinearGradient {
        LinearGradient(colors: [accentA, accentB], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var softGradient: LinearGradient {
        LinearGradient(colors: [accentA.opacity(0.16), accentB.opacity(0.16)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Jednolita karta z materiałem, delikatną obwódką i cieniem.
private struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
            .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// Etykieta sekcji — małe wersaliki z tracking.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

/// Pojedynczy „klawisz" w stylu keycapa.
struct Keycap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .frame(minWidth: 24)
            .frame(height: 26)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12))
            )
    }
}

/// Animowany wielokropek „…".
struct AnimatedDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 3, height: 3)
                    .opacity(phase == i ? 1 : 0.25)
            }
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}
