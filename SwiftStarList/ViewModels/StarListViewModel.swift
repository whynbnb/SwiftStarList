import Foundation

enum SortOption: String, CaseIterable {
    case starredAt = "starred_at"
    case name = "name"
    case stars = "stars"
    case updated = "updated"

    var displayName: String {
        let s = L.s
        switch self {
        case .starredAt: return s.sortStarredAt
        case .name: return s.sortName
        case .stars: return s.sortStars
        case .updated: return s.sortUpdated
        }
    }
}

enum GroupOption: String, CaseIterable {
    case none = "none"
    case language = "language"
    case starredAtYear = "starred_at_year"
    case pushedAtYear = "pushed_at_year"
    case nameLetter = "name_letter"
    case starsRange = "stars_range"

    var displayName: String {
        let s = L.s
        switch self {
        case .none: return s.groupNone
        case .language: return s.groupLanguage
        case .starredAtYear: return s.groupStarredAtYear
        case .pushedAtYear: return s.groupPushedAtYear
        case .nameLetter: return s.groupNameLetter
        case .starsRange: return s.groupStarsRange
        }
    }

    static func available(for sort: SortOption) -> [GroupOption] {
        switch sort {
        case .starredAt: return [.none, .language, .starredAtYear]
        case .updated: return [.none, .language, .pushedAtYear]
        case .name: return [.none, .language, .nameLetter]
        case .stars: return [.none, .language, .starsRange]
        }
    }
}

enum SearchScope: String, CaseIterable {
    case all = "all"
    case name = "name"
    case language = "language"
    case topic = "topic"
    case description = "description"

    var displayName: String {
        let s = L.s
        switch self {
        case .all: return s.scopeAll
        case .name: return s.scopeName
        case .language: return s.scopeLanguage
        case .topic: return s.scopeTopic
        case .description: return s.scopeDescription
        }
    }
}

@MainActor
final class StarListViewModel: ObservableObject {
    @Published var repos: [StarredRepo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var searchScope: SearchScope = .all
    @Published var sortOption: SortOption = .starredAt
    @Published var groupOption: GroupOption = .none
    @Published var isFromCache = false

    private let githubService = GitHubService()
    private let cache = RepoCache.shared

    var filteredRepos: [StarredRepo] {
        var result = repos
        if !searchText.isEmpty {
            let query = searchText.trimmingCharacters(in: .whitespaces)
            result = result.filter {
                switch searchScope {
                case .all:
                    return $0.fullName.localizedCaseInsensitiveContains(query) ||
                    ($0.description?.localizedCaseInsensitiveContains(query) ?? false) ||
                    ($0.language?.caseInsensitiveCompare(query) == .orderedSame) ||
                    $0.topics.contains { $0.caseInsensitiveCompare(query) == .orderedSame }
                case .name:
                    return $0.fullName.localizedCaseInsensitiveContains(query)
                case .language:
                    return $0.language?.caseInsensitiveCompare(query) == .orderedSame
                case .topic:
                    return $0.topics.contains { $0.caseInsensitiveCompare(query) == .orderedSame } ||
                    $0.topics.contains { $0.localizedCaseInsensitiveContains(query) }
                case .description:
                    return ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
                }
            }
        }
        return sorted(result)
    }

    var groupedRepos: [(String, [StarredRepo])] {
        let filtered = filteredRepos
        switch groupOption {
        case .none:
            return [("", filtered)]
        case .language:
            let grouped = Dictionary(grouping: filtered) { $0.language ?? L.s.other }
            return grouped.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        case .starredAtYear:
            let grouped = Dictionary(grouping: filtered) { year(from: $0.starredAt) }
            return grouped.sorted { $0.key > $1.key }
        case .pushedAtYear:
            let grouped = Dictionary(grouping: filtered) { year(from: $0.pushedAt) }
            return grouped.sorted { $0.key > $1.key }
        case .nameLetter:
            let grouped = Dictionary(grouping: filtered) { firstLetter(of: $0.fullName) }
            return grouped.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        case .starsRange:
            let grouped = Dictionary(grouping: filtered) { starsRange($0.stargazersCount) }
            return grouped.sorted { starsRangeOrder[$0.key] ?? 0 > starsRangeOrder[$1.key] ?? 0 }
        }
    }

    private func year(from dateStr: String?) -> String {
        guard let s = dateStr, s.count >= 4 else { return L.s.unknown }
        return String(s.prefix(4))
    }

    private func firstLetter(of name: String) -> String {
        guard let ch = name.first else { return "#" }
        if ch.isLetter {
            let upper = String(ch.uppercased())
            if ch.isASCII { return upper }
            return upper
        }
        return "#"
    }

    private func starsRange(_ count: Int) -> String {
        switch count {
        case ..<100: return "0-99"
        case 100..<500: return "100-499"
        case 500..<1000: return "500-999"
        case 1000..<5000: return "1k-5k"
        case 5000..<10000: return "5k-10k"
        case 10000..<50000: return "10k-50k"
        default: return "50k+"
        }
    }

    private var starsRangeOrder: [String: Int] {
        ["50k+": 6, "10k-50k": 5, "5k-10k": 4, "1k-5k": 3, "500-999": 2, "100-499": 1, "0-99": 0]
    }

    private func sorted(_ repos: [StarredRepo]) -> [StarredRepo] {
        switch sortOption {
        case .starredAt:
            return repos.sorted { ($0.starredAt ?? "") > ($1.starredAt ?? "") }
        case .name:
            return repos.sorted { $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending }
        case .stars:
            return repos.sorted { $0.stargazersCount > $1.stargazersCount }
        case .updated:
            return repos.sorted { $0.pushedAt ?? "" > $1.pushedAt ?? "" }
        }
    }

    func loadFromCache() {
        if let cached = cache.load(), !cached.isEmpty {
            repos = cached
            isFromCache = true
        }
    }

    func fetchAll(settings: AppSettings) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let allRepos = try await githubService.fetchAllStarredRepos(settings: settings)
            repos = allRepos
            isFromCache = false
            cache.save(allRepos)
        } catch {
            // 刷新失败时保留已有列表/缓存，只在完全没有数据时展示错误页
            if repos.isEmpty {
                errorMessage = error.localizedDescription
            }
        }
    }
}
