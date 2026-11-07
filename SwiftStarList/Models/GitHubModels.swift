import Foundation

struct StarredRepoEnvelope: Codable {
    let starredAt: String
    let repo: StarredRepo

    enum CodingKeys: String, CodingKey {
        case starredAt = "starred_at"
        case repo
    }
}

struct StarredRepo: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let fullName: String
    let owner: RepoOwner
    let htmlUrl: String
    let description: String?
    let stargazersCount: Int
    let language: String?
    let topics: [String]
    let createdAt: String
    let updatedAt: String
    let pushedAt: String?
    let fork: Bool
    let homepage: String?
    var starredAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, owner, description, language, topics, fork, homepage, starredAt
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case stargazersCount = "stargazers_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pushedAt = "pushed_at"
    }

    static func == (lhs: StarredRepo, rhs: StarredRepo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct RepoOwner: Codable, Hashable {
    let login: String
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct RepoTag: Codable, Identifiable {
    let name: String
    let commit: TagCommit

    var id: String { name }
}

struct TagCommit: Codable {
    let sha: String
    let url: String?
}

struct RepoCommit: Codable, Identifiable {
    let sha: String
    let htmlUrl: String?
    let commit: CommitDetail
    let author: CommitAuthorInfo?

    var id: String { sha }

    enum CodingKeys: String, CodingKey {
        case sha, commit, author
        case htmlUrl = "html_url"
    }
}

struct CommitDetail: Codable {
    let author: CommitUser?
    let committer: CommitUser?
    let message: String
}

struct CommitUser: Codable {
    let name: String?
    let email: String?
    let date: String?
}

struct CommitAuthorInfo: Codable {
    let login: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct RepoRelease: Codable, Identifiable {
    let id: Int
    let tagName: String
    let name: String?
    let body: String?
    let draft: Bool
    let prerelease: Bool
    let createdAt: String
    let publishedAt: String?
    let htmlUrl: String
    let author: ReleaseAuthorInfo?

    enum CodingKeys: String, CodingKey {
        case id, name, body, draft, prerelease, author
        case tagName = "tag_name"
        case createdAt = "created_at"
        case publishedAt = "published_at"
        case htmlUrl = "html_url"
    }
}

struct ReleaseAuthorInfo: Codable {
    let login: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct RepoContributor: Codable, Identifiable, Hashable {
    let id: Int
    let login: String
    let avatarUrl: String
    let contributions: Int

    enum CodingKeys: String, CodingKey {
        case id, login, contributions
        case avatarUrl = "avatar_url"
    }
}

struct RepoLicense: Codable {
    let key: String
    let name: String
    let spdxId: String?
    let htmlUrl: String?

    enum CodingKeys: String, CodingKey {
        case key, name
        case spdxId = "spdx_id"
        case htmlUrl = "html_url"
    }
}

/// GET /repos/{owner}/{repo}，用于给 AI 提供更完整的项目概况
struct RepoDetails: Codable {
    let fullName: String
    let description: String?
    let homepage: String?
    let language: String?
    let topics: [String]?
    let stargazersCount: Int
    let watchersCount: Int?
    let forksCount: Int
    let openIssuesCount: Int
    let subscribersCount: Int?
    let networkCount: Int?
    let size: Int?
    let defaultBranch: String?
    let archived: Bool?
    let disabled: Bool?
    let fork: Bool?
    let hasIssues: Bool?
    let hasWiki: Bool?
    let hasPages: Bool?
    let createdAt: String?
    let updatedAt: String?
    let pushedAt: String?
    let license: RepoLicense?

    enum CodingKeys: String, CodingKey {
        case description, homepage, language, topics, size, archived, disabled, fork, license
        case fullName = "full_name"
        case stargazersCount = "stargazers_count"
        case watchersCount = "watchers_count"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case subscribersCount = "subscribers_count"
        case networkCount = "network_count"
        case defaultBranch = "default_branch"
        case hasIssues = "has_issues"
        case hasWiki = "has_wiki"
        case hasPages = "has_pages"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pushedAt = "pushed_at"
    }
}

struct RepoIssue: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let htmlUrl: String
    let state: String
    let createdAt: String
    let user: IssueUser?
    let labels: [IssueLabel]?
    let pullRequest: IssuePullRequest?

    enum CodingKeys: String, CodingKey {
        case id, number, title, state, labels, user
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case pullRequest = "pull_request"
    }
}

struct IssuePullRequest: Codable {
    let url: String?
    let htmlUrl: String?

    enum CodingKeys: String, CodingKey {
        case url
        case htmlUrl = "html_url"
    }
}

struct IssueUser: Codable {
    let login: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}

struct IssueLabel: Codable {
    let name: String
    let color: String
}

struct RepoPullRequest: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let htmlUrl: String
    let state: String
    let createdAt: String
    let user: IssueUser?

    enum CodingKeys: String, CodingKey {
        case id, number, title, state, user
        case htmlUrl = "html_url"
        case createdAt = "created_at"
    }
}
