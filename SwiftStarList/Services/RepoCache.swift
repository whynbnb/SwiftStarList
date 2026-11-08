import Foundation
import OSLog

extension Notification.Name {
    /// 本地缓存被外部操作（导入、清除）修改时发出，用于刷新列表与数据管理界面。
    static let repoCacheDidChange = Notification.Name("SwiftStarList.repoCacheDidChange")
    /// 任意一次本地缓存写入后发出，仅用于数据管理界面的实时统计。
    static let repoCacheDidSave = Notification.Name("SwiftStarList.repoCacheDidSave")
}

@MainActor
final class RepoCache {
    static let shared = RepoCache()
    private let reposFile: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.swiftstarlist.app", category: "RepoCache")

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let cacheDirectory = appSupport.appendingPathComponent("SwiftStarList", isDirectory: true)
        reposFile = cacheDirectory.appendingPathComponent("starred_repos.json")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    var lastModified: Date? {
        (try? FileManager.default.attributesOfItem(atPath: reposFile.path)[.modificationDate]) as? Date
    }

    /// 保存缓存。`notify` 用于标记来自导入/清除等外部操作，
    /// 避免普通刷新时把“来自缓存”的状态错误地覆盖回界面。
    func save(_ repos: [StarredRepo], notify: Bool = false) {
        do {
            let data = try encoder.encode(repos)
            try data.write(to: reposFile, options: .atomic)
            NotificationCenter.default.post(name: .repoCacheDidSave, object: self)
            if notify {
                NotificationCenter.default.post(name: .repoCacheDidChange, object: self)
            }
        } catch {
            logger.error("Cache save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func load() -> [StarredRepo]? {
        guard FileManager.default.fileExists(atPath: reposFile.path) else { return nil }
        do {
            let data = try Data(contentsOf: reposFile)
            return try decoder.decode([StarredRepo].self, from: data)
        } catch {
            logger.error("Cache load failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: reposFile)
        NotificationCenter.default.post(name: .repoCacheDidChange, object: self)
    }
}
