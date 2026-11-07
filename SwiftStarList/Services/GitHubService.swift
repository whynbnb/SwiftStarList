import Foundation

actor GitHubService {
    private let network = NetworkManager.shared

    func fetchAllStarredRepos(settings: AppSettings) async throws -> [StarredRepo] {
        var allRepos: [StarredRepo] = []
        var page = 1
        let perPage = 100

        while true {
            let url = "https://api.github.com/user/starred?per_page=\(perPage)&page=\(page)&sort=created&direction=desc"
            let (envelopes, hasNextPage) = try await network.requestWithPagination(
                url, settings: settings, accept: "application/vnd.github.star+json"
            ) as ([StarredRepoEnvelope], Bool)
            let repos = envelopes.map { envelope in
                var repo = envelope.repo
                repo.starredAt = envelope.starredAt
                return repo
            }
            allRepos.append(contentsOf: repos)
            if !hasNextPage { break }
            page += 1
        }
        return allRepos
    }

    func fetchREADME(owner: String, repo: String, settings: AppSettings) async throws -> String {
        // /readme 会自动匹配 README.md / readme.rst 等任意支持的命名与大小写
        let url = "https://api.github.com/repos/\(owner)/\(repo)/readme"
        let data = try await network.requestRaw(url, settings: settings, accept: "application/vnd.github.raw")
        guard let text = String(data: data, encoding: .utf8) else {
            throw NetworkError.decodingError(
                DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: L.s.encodingFailed))
            )
        }
        return text
    }

    func fetchRecentTags(owner: String, repo: String, settings: AppSettings, perPage: Int = 10) async throws -> [RepoTag] {
        let url = "https://api.github.com/repos/\(owner)/\(repo)/tags?per_page=\(perPage)"
        return try await network.request(url, settings: settings)
    }

    func fetchRecentCommits(owner: String, repo: String, settings: AppSettings, perPage: Int = 10) async throws -> [RepoCommit] {
        let url = "https://api.github.com/repos/\(owner)/\(repo)/commits?per_page=\(perPage)"
        return try await network.request(url, settings: settings)
    }

    func fetchRecentReleases(owner: String, repo: String, settings: AppSettings, perPage: Int = 10) async throws -> [RepoRelease] {
        let url = "https://api.github.com/repos/\(owner)/\(repo)/releases?per_page=\(perPage)"
        return try await network.request(url, settings: settings)
    }

    func fetchContributors(owner: String, repo: String, settings: AppSettings, perPage: Int = 10) async throws -> [RepoContributor] {
        let url = "https://api.github.com/repos/\(owner)/\(repo)/contributors?per_page=\(perPage)"
        return try await network.request(url, settings: settings)
    }

    func fetchLanguages(owner: String, repo: String, settings: AppSettings) async throws -> [String: Int] {
        let url = "https://api.github.com/repos/\(owner)/\(repo)/languages"
        let data = try await network.requestRaw(url, settings: settings)
        return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    func fetchLicense(owner: String, repo: String, settings: AppSettings) async throws -> RepoLicense? {
        let url = "https://api.github.com/repos/\(owner)/\(repo)/license"
        let data = try await network.requestRaw(url, settings: settings)
        let wrapper = try? JSONDecoder().decode(LicenseWrapper.self, from: data)
        return wrapper?.license
    }

    func fetchOpenIssues(owner: String, repo: String, settings: AppSettings, perPage: Int = 5) async throws -> [RepoIssue] {
        let url = "https://api.github.com/repos/\(owner)/\(repo)/issues?state=open&sort=created&direction=desc&per_page=\(perPage)"
        let issues: [RepoIssue] = try await network.request(url, settings: settings)
        // /issues 也会返回 PR，这里只保留真正的 issue
        return issues.filter { $0.pullRequest == nil }
    }

    func fetchOpenPulls(owner: String, repo: String, settings: AppSettings, perPage: Int = 5) async throws -> [RepoPullRequest] {
        let url = "https://api.github.com/repos/\(owner)/\(repo)/pulls?state=open&sort=created&direction=desc&per_page=\(perPage)"
        return try await network.request(url, settings: settings)
    }
}

private struct LicenseWrapper: Codable {
    let license: RepoLicense?
}
