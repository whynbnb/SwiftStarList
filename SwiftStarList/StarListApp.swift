import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            if SettingsManager.shared.settings.theme == .system {
                NSApp.appearance = nil
            } else {
                NSApp.appearance = SettingsManager.shared.settings.theme.appearance
            }
            NSApp.activate()
            NSApp.keyWindow?.makeKey()
        }
    }
}

@main
struct StarListApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some Scene {
        WindowGroup("Github Star List") {
            StarListView(settingsManager: settingsManager)
                .environmentObject(settingsManager)
                .preferredColorScheme(settingsManager.settings.theme.resolvedColorScheme)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1000, height: 700)
        .defaultAppStorage(UserDefaults.standard)
        .commands {
            DataManagementCommands()
        }

        Window(L.d.dataManagement, id: "data-management") {
            DataManagementView(settingsManager: settingsManager)
                .environmentObject(settingsManager)
                .preferredColorScheme(settingsManager.settings.theme.resolvedColorScheme)
        }
        .defaultSize(width: 900, height: 620)

        Settings {
            SettingsView(settingsManager: settingsManager)
                .preferredColorScheme(settingsManager.settings.theme.resolvedColorScheme)
        }
        .onChange(of: settingsManager.settings.theme) { _, newTheme in
            let concrete = newTheme.resolvedAppearance
            NSApp.appearance = concrete
            for window in NSApp.windows {
                window.appearance = concrete
                window.invalidateShadow()
            }
        }
    }
}

private struct DataManagementCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(L.d.openDataManagement) {
                openWindow(id: "data-management")
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
