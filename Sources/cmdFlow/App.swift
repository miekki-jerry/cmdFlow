import SwiftUI

extension Notification.Name {
    static let openCmdFlowSettings = Notification.Name("cmdflow.openSettings")
}

@main
struct CmdFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(AppState.shared)
        } label: {
            MenuBarLabel(app: AppState.shared)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Ikona w pasku menu reagująca na stan pracy.
private struct MenuBarLabel: View {
    @ObservedObject var app: AppState

    var body: some View {
        Image(systemName: symbol)
    }

    private var symbol: String {
        switch app.activity {
        case .idle: return "command"
        case .running: return "hourglass"
        case .success: return "checkmark.circle.fill"
        case .failure: return "exclamationmark.circle.fill"
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var settingsWindow = SettingsWindowController(appState: .shared)

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Aplikacja żyje w pasku menu, bez ikony w Docku.
        NSApplication.shared.setActivationPolicy(.accessory)

        NotificationCenter.default.addObserver(
            forName: .openCmdFlowSettings, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsWindow.show() }
        }

        // Otwórz Ustawienia przy starcie — inaczej użytkownik widzi tylko ikonę w pasku menu.
        settingsWindow.show()
    }

    /// Ponowne kliknięcie aplikacji (Finder/Launchpad/Dock) otwiera Ustawienia.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return true
    }
}

/// Okno Ustawień oparte o NSWindow — niezawodne dla aplikacji typu menu bar (accessory).
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView().environmentObject(appState))
            let win = NSWindow(contentViewController: hosting)
            win.title = "Ustawienia cmdFlow"
            win.styleMask = [.titled, .closable, .miniaturizable]
            win.isReleasedWhenClosed = false
            win.center()
            window = win
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
