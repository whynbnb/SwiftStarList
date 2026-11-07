import AppKit
import CryptoKit

final class AvatarCache {
    static let shared = AvatarCache()
    private var memoryCache: NSCache<NSString, NSImage>
    private let diskCacheDir: URL

    private init() {
        memoryCache = NSCache()
        memoryCache.countLimit = 500

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        diskCacheDir = appSupport.appendingPathComponent("SwiftStarList/avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }

    func image(for url: String) -> NSImage? {
        if let cached = memoryCache.object(forKey: url as NSString) {
            return cached
        }
        if let diskImage = loadFromDisk(url: url) {
            memoryCache.setObject(diskImage, forKey: url as NSString)
            return diskImage
        }
        return nil
    }

    /// 下载头像，遵循 GitHub 代理配置；失败或任务被取消时返回 nil
    func loadImage(for url: String) async -> NSImage? {
        if let cached = image(for: url) {
            return cached
        }
        guard let requestURL = URL(string: url) else { return nil }

        let session = NetworkManager.shared.makeSessionForProxy(
            SettingsManager.shared.settings.githubProxyConfig
        )
        do {
            let (data, response) = try await session.data(from: requestURL)
            guard !Task.isCancelled else { return nil }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            guard let image = NSImage(data: data) else { return nil }
            setImage(image, for: url)
            return image
        } catch {
            return nil
        }
    }

    func setImage(_ image: NSImage, for url: String) {
        memoryCache.setObject(image, forKey: url as NSString)
        saveToDisk(image: image, url: url)
    }

    func clear() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheDir)
        try? FileManager.default.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }

    /// base64 结果可能包含 "/"，不能直接作为文件名，改用 SHA256
    private func cacheKey(for url: String) -> String {
        let digest = SHA256.hash(data: Data(url.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func fileURL(for url: String) -> URL {
        diskCacheDir.appendingPathComponent(cacheKey(for: url))
    }

    private func saveToDisk(image: NSImage, url: String) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: fileURL(for: url))
    }

    private func loadFromDisk(url: String) -> NSImage? {
        let file = fileURL(for: url)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return NSImage(contentsOf: file)
    }
}
