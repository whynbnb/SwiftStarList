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
    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(L.d.openDataManagement) {
                DataManagementWindowController.shared.show(
                    settingsManager: SettingsManager.shared,
                    returnWindow: NSApp.keyWindow ?? NSApp.mainWindow
                )
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}
