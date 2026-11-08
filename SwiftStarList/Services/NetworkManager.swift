import Foundation
import Network

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidConfiguration
    case unauthorized
    case httpError(Int, String)
    case decodingError(Error)

    var errorDescription: String? {
        let s = L.s
        switch self {
        case .invalidURL: return s.invalidURL
        case .invalidConfiguration: return s.invalidConfiguration
        case .unauthorized: return s.unauthorized
        case .httpError(let code, let msg): return "\(s.httpError) \(code): \(msg)"
        case .decodingError(let e): return "\(s.decodingError): \(e.localizedDescription)"
        }
    }
}

final class NetworkManager: @unchecked Sendable {
    static let shared = NetworkManager()
    private init() {}

    private let sessionLock = NSLock()
    private var sessions: [String: URLSession] = [:]

    func request<T: Decodable>(_ url: String, settings: AppSettings, accept: String = "application/vnd.github+json") async throws -> T {
        let (data, _) = try await perform(url, settings: settings, accept: accept)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    func requestWithPagination<T: Decodable>(_ url: String, settings: AppSettings, accept: String = "application/vnd.github+json") async throws -> (T, Bool) {
        let (data, response) = try await perform(url, settings: settings, accept: accept)

        let decoded: T
        do {
            decoded = try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }

        let hasNextPage: Bool
        if let httpResponse = response as? HTTPURLResponse,
           let linkHeader = httpResponse.value(forHTTPHeaderField: "Link") {
            hasNextPage = linkHeader.contains("rel=\"next\"")
        } else {
            hasNextPage = false
        }

        return (decoded, hasNextPage)
    }

    func requestRaw(_ url: String, settings: AppSettings, accept: String = "application/vnd.github.object") async throws -> Data {
        let (data, _) = try await perform(url, settings: settings, accept: accept)
        return data
    }

    func postJSON<T: Decodable>(_ url: String, body: Encodable, apiKey: String, proxyConfig: ProxyConfig) async throws -> T {
        guard let url = URL(string: url) else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let session = makeSessionForProxy(proxyConfig)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    private func perform(_ urlString: String, settings: AppSettings, accept: String) async throws -> (Data, URLResponse) {
        guard let url = URL(string: urlString) else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if !settings.githubToken.isEmpty {
            request.setValue("Bearer \(settings.githubToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")

        let session = makeSessionForProxy(settings.githubProxyConfig)
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return (data, response)
    }

    func makeSessionForProxy(_ proxyConfig: ProxyConfig) -> URLSession {
        let key = "\(proxyConfig.mode.rawValue)|\(proxyConfig.host)|\(proxyConfig.port)"

        sessionLock.lock()
        defer { sessionLock.unlock() }
        if let existing = sessions[key] {
            return existing
        }

        let config = URLSessionConfiguration.default
        switch proxyConfig.mode {
        case .none:
            // 空字典表示不使用任何代理（覆盖系统代理设置）
            config.connectionProxyDictionary = [:]
        case .system:
            // nil 表示跟随系统代理设置
            config.connectionProxyDictionary = nil
        case .http:
            let proxy: [AnyHashable: Any] = [
                "HTTPEnable": 1,
                "HTTPProxy": proxyConfig.host,
                "HTTPPort": proxyConfig.port,
                "HTTPSEnable": 1,
                "HTTPSProxy": proxyConfig.host,
                "HTTPSPort": proxyConfig.port,
            ]
            config.connectionProxyDictionary = proxy
        case .socks:
            // URLSession 的 connectionProxyDictionary 在未指定 SOCKSVersion 时
            // 可能按 SOCKS4 处理，导致现代 SOCKS5 代理连接失败。
            // 优先使用 Network 框架的 SOCKS5 配置。
            if (1...65535).contains(proxyConfig.port),
               let port = NWEndpoint.Port(rawValue: UInt16(proxyConfig.port)) {
                let endpoint = NWEndpoint.hostPort(
                    host: NWEndpoint.Host(proxyConfig.host),
                    port: port
                )
                var proxy = ProxyConfiguration(socksv5Proxy: endpoint)
                proxy.allowFailover = false
                config.proxyConfigurations = [proxy]
            } else {
                config.connectionProxyDictionary = [
                    "SOCKSEnable": 1,
                    "SOCKSProxy": proxyConfig.host,
                    "SOCKSPort": proxyConfig.port,
                    "SOCKSVersion": 5,
                ]
            }
        }

        let session = URLSession(configuration: config)
        sessions[key] = session
        return session
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        if httpResponse.statusCode == 401 { throw NetworkError.unauthorized }
        if !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NetworkError.httpError(httpResponse.statusCode, body)
        }
    }
}
