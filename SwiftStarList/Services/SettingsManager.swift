import Foundation

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    private let defaults = UserDefaults.standard
    private let settingsKey = "app_settings"

    @Published var settings: AppSettings {
        didSet {
            persist(settings)
            if oldValue.language != settings.language {
                languageVersion += 1
            }
        }
    }

    @Published var languageVersion = 0
    @Published var isSettingsOpen = false

    private init() {
        var loaded = AppSettings.default
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            loaded = decoded
        }

        let credentials = CredentialStore.load()
        loaded.githubToken = credentials?.githubToken ?? ""
        loaded.llmConfig.apiKey = credentials?.apiKey ?? ""
        settings = loaded
    }

    private func persist(_ settings: AppSettings) {
        var redacted = settings
        redacted.githubToken = ""
        redacted.llmConfig.apiKey = ""

        if let data = try? JSONEncoder().encode(redacted) {
            defaults.set(data, forKey: settingsKey)
        }

        CredentialStore.save(.init(
            githubToken: settings.githubToken,
            apiKey: settings.llmConfig.apiKey
        ))
    }
}
