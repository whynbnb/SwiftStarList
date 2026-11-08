import Foundation

@MainActor
final class SnapshotStore: ObservableObject {
    @Published private(set) var snapshots: [StarSnapshot] = []
    @Published private(set) var lastError: String?

    private let directory: URL
    private let fileManager = FileManager.default

    var storageDirectory: URL { directory }

    init(directory: URL? = nil) {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.directory = directory
            ?? appSupport
                .appendingPathComponent("SwiftStarList", isDirectory: true)
                .appendingPathComponent("Snapshots", isDirectory: true)

        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        reload()
    }

    func reload() {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let decoder = StarDataCodec.makeDecoder()
        var loaded: [StarSnapshot] = []

        for url in urls where url.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: url),
                  let snapshot = try? decoder.decode(StarSnapshot.self, from: data) else {
                continue
            }
            loaded.append(snapshot)
        }

        snapshots = loaded.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func createSnapshot(
        from repos: [StarredRepo],
        name: String? = nil,
        createdAt: Date = Date()
    ) -> StarSnapshot? {
        guard !repos.isEmpty else { return nil }

        let snapshot = StarSnapshot(
            name: name ?? defaultSnapshotName(),
            createdAt: createdAt,
            repos: repos
        )
        guard save(snapshot) else { return nil }
        return snapshot
    }

    func rename(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = snapshots.firstIndex(where: { $0.id == id }) else {
            return
        }

        var snapshot = snapshots[index]
        guard snapshot.name != trimmed else { return }
        snapshot.name = trimmed
        _ = save(snapshot)
    }

    func delete(_ snapshot: StarSnapshot) {
        do {
            try fileManager.removeItem(at: fileURL(for: snapshot.id))
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        reload()
    }

    func export(_ snapshot: StarSnapshot, to url: URL) throws {
        let data = try StarDataCodec.makeEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    func exportArchive(_ repos: [StarredRepo], to url: URL) throws {
        let data = try StarDataCodec.exportArchive(repos)
        try data.write(to: url, options: .atomic)
    }

    func exportCSV(_ repos: [StarredRepo], to url: URL) throws {
        let data = Data(StarDataCodec.csv(from: repos).utf8)
        try data.write(to: url, options: .atomic)
    }

    @discardableResult
    func importSnapshot(from url: URL) throws -> StarSnapshot {
        let data = try Data(contentsOf: url)
        let decoder = StarDataCodec.makeDecoder()

        if var snapshot = try? decoder.decode(StarSnapshot.self, from: data),
           !snapshot.repos.isEmpty {
            // 避免覆盖已有同名 ID 的快照
            if snapshots.contains(where: { $0.id == snapshot.id }) {
                snapshot.id = UUID()
            }
            guard save(snapshot) else { throw StarDataError.writeFailed }
            return snapshot
        }

        let repos = try StarDataCodec.decodeRepos(from: data)
        guard !repos.isEmpty else { throw StarDataError.emptyFile }

        let name = url.deletingPathExtension().lastPathComponent
        guard let snapshot = createSnapshot(from: repos, name: name) else {
            throw StarDataError.writeFailed
        }
        return snapshot
    }

    private func save(_ snapshot: StarSnapshot) -> Bool {
        do {
            let data = try StarDataCodec.makeEncoder().encode(snapshot)
            try data.write(to: fileURL(for: snapshot.id), options: .atomic)
            lastError = nil
            reload()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func defaultSnapshotName() -> String {
        "\(L.d.snapshot) \(SnapshotFormat.date(Date()))"
    }
}
