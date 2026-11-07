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

        if loaded.llmConfig.profiles.isEmpty {
            loaded.llmConfig = .default
        }
        if loaded.llmConfig.defaultProfileID == nil
            || !loaded.llmConfig.profiles.contains(where: { $0.id == loaded.llmConfig.defaultProfileID }) {
            loaded.llmConfig.defaultProfileID = loaded.llmConfig.profiles.first?.id
        }

        let credentials = CredentialStore.load()
        loaded.githubToken = credentials?.githubToken ?? ""

        // 按 profile 恢复各自的 API Key
        let storedKeys = credentials?.apiKeys ?? [:]
        for index in loaded.llmConfig.profiles.indices {
            let key = loaded.llmConfig.profiles[index].id.uuidString
            if let stored = storedKeys[key] {
                loaded.llmConfig.profiles[index].apiKey = stored
            }
        }

        // 旧版本的单 Key 迁移到默认配置
        if let legacyKey = credentials?.apiKey, !legacyKey.isEmpty,
           loaded.llmConfig.profiles.allSatisfy({ $0.apiKey.isEmpty }),
           let defaultID = loaded.llmConfig.defaultProfile?.id,
           let index = loaded.llmConfig.profiles.firstIndex(where: { $0.id == defaultID }) {
            loaded.llmConfig.profiles[index].apiKey = legacyKey
        }

        settings = loaded
        persist(loaded)
    }

    private func persist(_ settings: AppSettings) {
        var redacted = settings
        redacted.githubToken = ""
        for index in redacted.llmConfig.profiles.indices {
            redacted.llmConfig.profiles[index].apiKey = ""
        }

        if let data = try? JSONEncoder().encode(redacted) {
            defaults.set(data, forKey: settingsKey)
        }

        var apiKeys: [String: String] = [:]
        for profile in settings.llmConfig.profiles where !profile.apiKey.isEmpty {
            apiKeys[profile.id.uuidString] = profile.apiKey
        }
        CredentialStore.save(.init(githubToken: settings.githubToken, apiKeys: apiKeys))
    }
}
