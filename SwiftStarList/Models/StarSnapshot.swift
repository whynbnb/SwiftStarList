import Foundation

// MARK: - Snapshot

struct StarSnapshot: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var repos: [StarredRepo]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        repos: [StarredRepo]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.repos = repos
    }

    var totalStars: Int {
        repos.reduce(0) { $0 + $1.stargazersCount }
    }

    var languageCounts: [LanguageCount] {
        Dictionary(grouping: repos) { $0.language ?? L.s.unknown }
            .map { LanguageCount(name: $0.key, count: $0.value.count) }
            .sorted {
                if $0.count == $1.count {
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                return $0.count > $1.count
            }
    }

    static func == (lhs: StarSnapshot, rhs: StarSnapshot) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct LanguageCount: Identifiable, Hashable {
    let name: String
    let count: Int

    var id: String { name }
}

// MARK: - Archive

/// Star 列表导出文件。既可作为备份，也可重新导入。
struct StarDataArchive: Codable {
    static let formatIdentifier = "swiftstarlist.stars"
    static let currentVersion = 1

    var format: String
    var version: Int
    var exportedAt: Date
    var repos: [StarredRepo]

    init(repos: [StarredRepo], exportedAt: Date = Date()) {
        self.format = Self.formatIdentifier
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.repos = repos
    }
}

enum StarDataError: LocalizedError {
    case invalidFormat
    case emptyFile
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return L.d.invalidFormat
        case .emptyFile: return L.d.emptyFile
        case .writeFailed: return L.d.writeFailed
        }
    }
}

enum StarDataCodec {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func exportArchive(_ repos: [StarredRepo]) throws -> Data {
        try makeEncoder().encode(StarDataArchive(repos: repos))
    }

    /// 兼容多种输入：SwiftStarList 备份、`[StarredRepo]`、GitHub starred 接口
    /// 返回的 `{ starred_at, repo }` 数组，以及搜索接口的 `{ items: [...] }`。
    static func decodeRepos(from data: Data) throws -> [StarredRepo] {
        let decoder = makeDecoder()

        if let archive = try? decoder.decode(StarDataArchive.self, from: data),
           !archive.repos.isEmpty {
            return archive.repos
        }

        struct SnapshotShape: Decodable {
            let repos: [StarredRepo]
        }

        if let snapshot = try? decoder.decode(SnapshotShape.self, from: data),
           !snapshot.repos.isEmpty {
            return snapshot.repos
        }

        if let repos = try? decoder.decode([StarredRepo].self, from: data),
           !repos.isEmpty {
            return repos
        }

        if let envelopes = try? decoder.decode([StarredRepoEnvelope].self, from: data),
           !envelopes.isEmpty {
            return envelopes.map { envelope in
                var repo = envelope.repo
                if repo.starredAt == nil {
                    repo.starredAt = envelope.starredAt
                }
                return repo
            }
        }

        struct SearchResponse: Decodable {
            let items: [StarredRepo]
        }

        if let response = try? decoder.decode(SearchResponse.self, from: data),
           !response.items.isEmpty {
            return response.items
        }

        throw StarDataError.invalidFormat
    }

    static func csv(from repos: [StarredRepo]) -> String {
        let header = [
            "full_name", "description", "language", "stars",
            "topics", "starred_at", "pushed_at", "url"
        ].joined(separator: ",")

        let rows = repos.map { repo in
            [
                repo.fullName,
                repo.description ?? "",
                repo.language ?? "",
                String(repo.stargazersCount),
                repo.topics.joined(separator: " "),
                repo.starredAt ?? "",
                repo.pushedAt ?? "",
                repo.htmlUrl
            ]
            .map(escapeCSV)
            .joined(separator: ",")
        }

        // 带 BOM，方便 Excel 正确识别 UTF-8
        return "\u{FEFF}" + ([header] + rows).joined(separator: "\n")
    }

    private static func escapeCSV(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}

// MARK: - Diff

struct SnapshotDiff {
    enum Field: String {
        case language
        case description
        case pushedAt
        case topics

        var label: String {
            switch self {
            case .language: return L.d.language
            case .description: return L.d.description
            case .pushedAt: return L.d.lastPush
            case .topics: return L.d.topics
            }
        }
    }

    struct FieldChange: Identifiable {
        let field: Field
        let oldValue: String
        let newValue: String

        var id: String { field.rawValue }
    }

    struct ChangedRepo: Identifiable {
        let repo: StarredRepo
        let previous: StarredRepo
        let changes: [FieldChange]

        var id: Int { repo.id }
        var starDelta: Int { repo.stargazersCount - previous.stargazersCount }
    }

    let base: StarSnapshot
    let target: StarSnapshot
    let added: [StarredRepo]
    let removed: [StarredRepo]
    let changed: [ChangedRepo]

    init(base: StarSnapshot, target: StarSnapshot) {
        self.base = base
        self.target = target

        let baseByID = Dictionary(
            base.repos.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let targetByID = Dictionary(
            target.repos.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        self.added = target.repos
            .filter { baseByID[$0.id] == nil }
            .sorted { ($0.starredAt ?? "") > ($1.starredAt ?? "") }

        self.removed = base.repos
            .filter { targetByID[$0.id] == nil }
            .sorted { ($0.starredAt ?? "") > ($1.starredAt ?? "") }

        self.changed = target.repos.compactMap { current -> ChangedRepo? in
            guard let previous = baseByID[current.id] else { return nil }

            var changes: [FieldChange] = []

            if previous.language != current.language {
                changes.append(FieldChange(
                    field: .language,
                    oldValue: previous.language ?? "—",
                    newValue: current.language ?? "—"
                ))
            }

            if (previous.description ?? "") != (current.description ?? "") {
                changes.append(FieldChange(
                    field: .description,
                    oldValue: previous.description ?? "—",
                    newValue: current.description ?? "—"
                ))
            }

            if (previous.pushedAt ?? "") != (current.pushedAt ?? "") {
                changes.append(FieldChange(
                    field: .pushedAt,
                    oldValue: previous.pushedAt.map { String($0.prefix(10)) } ?? "—",
                    newValue: current.pushedAt.map { String($0.prefix(10)) } ?? "—"
                ))
            }

            if previous.topics.sorted() != current.topics.sorted() {
                changes.append(FieldChange(
                    field: .topics,
                    oldValue: previous.topics.isEmpty ? "—" : previous.topics.joined(separator: ", "),
                    newValue: current.topics.isEmpty ? "—" : current.topics.joined(separator: ", ")
                ))
            }

            guard previous.stargazersCount != current.stargazersCount || !changes.isEmpty else {
                return nil
            }

            return ChangedRepo(repo: current, previous: previous, changes: changes)
        }
        .sorted {
            if $0.starDelta != $1.starDelta {
                return abs($0.starDelta) > abs($1.starDelta)
            }
            return $0.repo.fullName.localizedStandardCompare($1.repo.fullName) == .orderedAscending
        }
    }

    var starDelta: Int {
        target.totalStars - base.totalStars
    }

    var hasDifferences: Bool {
        !added.isEmpty || !removed.isEmpty || !changed.isEmpty
    }
}

// MARK: - Formatting

enum SnapshotFormat {
    static var locale: Locale {
        AppLanguage.resolved == .zh
            ? Locale(identifier: "zh_CN")
            : Locale(identifier: "en_US")
    }

    static func number(_ value: Int) -> String {
        value.formatted()
    }

    static func signedNumber(_ value: Int) -> String {
        value > 0 ? "+\(number(value))" : number(value)
    }

    static func date(_ date: Date) -> String {
        let style = Date.FormatStyle(
            date: .abbreviated,
            time: .shortened,
            locale: locale
        )
        return date.formatted(style)
    }

    static func timestamp(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
