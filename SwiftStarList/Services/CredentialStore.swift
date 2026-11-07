import Foundation

/// 本地凭据存储：Application Support 下的 0600 权限 JSON 文件。
///
/// 不使用 Keychain：开发时的 ad-hoc 签名每次构建都会变化，
/// 钥匙串会把它当成新的 app，从而反复弹出授权窗口。
struct CredentialStore {
    struct Credentials: Codable {
        var githubToken: String
        /// 旧版本的单 LLM Key，仅用于迁移读取
        var apiKey: String?
        /// LLM profile UUID -> API Key
        var apiKeys: [String: String]?

        init(githubToken: String, apiKey: String? = nil, apiKeys: [String: String]? = nil) {
            self.githubToken = githubToken
            self.apiKey = apiKey
            self.apiKeys = apiKeys
        }
    }

    private static var directoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SwiftStarList", isDirectory: true)
    }

    private static var fileURL: URL {
        directoryURL.appendingPathComponent("credentials.json")
    }

    static func load() -> Credentials? {
        guard let data = try? Data(contentsOf: fileURL),
              let credentials = try? JSONDecoder().decode(Credentials.self, from: data) else {
            return nil
        }
        return credentials
    }

    static func save(_ credentials: Credentials) {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        try? data.write(to: fileURL, options: .atomic)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}
