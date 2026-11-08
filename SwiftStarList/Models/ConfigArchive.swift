import Foundation

/// 配置文件：包含语言、外观、代理、分析与 LLM 配置。
/// 只有当 `includesCredentials` 为 true 时，GitHub Token 和 LLM API Key 才会被写入。
struct AppConfigArchive: Codable {
    static let formatIdentifier = "swiftstarlist.config"
    static let currentVersion = 1

    var format: String
    var version: Int
    var exportedAt: Date
    var includesCredentials: Bool
    var settings: AppSettings

    static func make(
        settings: AppSettings,
        includeCredentials: Bool,
        exportedAt: Date = Date()
    ) -> AppConfigArchive {
        var copy = settings

        if includeCredentials {
            // 以内存设置为主，但用本地凭据补全缺失字段，避免导出时丢 Key。
            let credentials = CredentialStore.load()

            if copy.githubToken.isEmpty {
                copy.githubToken = credentials?.githubToken ?? ""
            }

            let storedKeys = credentials?.apiKeys ?? [:]
            for index in copy.llmConfig.profiles.indices {
                guard copy.llmConfig.profiles[index].apiKey.isEmpty else { continue }

                let profile = copy.llmConfig.profiles[index]
                if let stored = storedKeys[profile.id.uuidString], !stored.isEmpty {
                    copy.llmConfig.profiles[index].apiKey = stored
                } else if let legacyKey = credentials?.apiKey,
                          !legacyKey.isEmpty,
                          profile.id == copy.llmConfig.defaultProfile?.id {
                    copy.llmConfig.profiles[index].apiKey = legacyKey
                }
            }
        } else {
            copy.githubToken = ""
            for index in copy.llmConfig.profiles.indices {
                copy.llmConfig.profiles[index].apiKey = ""
            }
        }

        return AppConfigArchive(
            format: formatIdentifier,
            version: currentVersion,
            exportedAt: exportedAt,
            includesCredentials: includeCredentials,
            settings: copy
        )
    }

    /// 合并导入配置：
    /// - 文件不含凭据时，保留当前 GitHub Token，并按 profile UUID 保留已有 API Key。
    /// - 文件包含凭据时，使用文件中的 Token 和 API Key。
    func merged(with current: AppSettings) -> AppSettings {
        var result = settings

        if !includesCredentials {
            result.githubToken = current.githubToken

            let existingKeys = Dictionary(
                current.llmConfig.profiles.map { ($0.id, $0.apiKey) },
                uniquingKeysWith: { first, _ in first }
            )

            for index in result.llmConfig.profiles.indices {
                let id = result.llmConfig.profiles[index].id
                result.llmConfig.profiles[index].apiKey = existingKeys[id] ?? ""
            }
        }

        if result.llmConfig.profiles.isEmpty {
            result.llmConfig = .default
        }

        if result.llmConfig.defaultProfileID == nil
            || !result.llmConfig.profiles.contains(where: {
                $0.id == result.llmConfig.defaultProfileID
            }) {
            result.llmConfig.defaultProfileID = result.llmConfig.profiles.first?.id
        }

        return result
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> AppConfigArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let archive = try? decoder.decode(AppConfigArchive.self, from: data),
              archive.format == formatIdentifier else {
            throw ConfigArchiveError.invalidFile
        }

        return archive
    }
}

enum ConfigArchiveError: LocalizedError {
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .invalidFile: return L.c.invalidConfigFile
        }
    }
}
