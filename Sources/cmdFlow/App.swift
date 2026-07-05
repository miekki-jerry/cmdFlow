import SwiftUI

@main
struct CmdFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var app = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(app)
        } label: {
            Image(systemName: menuBarSymbol)
        }
        .menuBarExtraStyle(.menu)

        Window("Ustawienia cmdFlow", id: "settings") {
            SettingsView()
                .environmentObject(app)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private var menuBarSymbol: String {
        switch app.activity {
        case .idle:
            if case .unavailable = app.modelStatus { return "command.circle.fill" }
            return "command"
        case .running:
            return "hourglass"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "exclamationmark.circle.fill"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Aplikacja żyje w pasku menu, bez ikony w Docku.
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
