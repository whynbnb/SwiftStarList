import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum DataTab: Hashable {
    case transfer
    case browse
    case snapshots
}

struct DataStatusMessage: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
}

struct DataManagementView: View {
    @ObservedObject var settingsManager: SettingsManager
    @StateObject private var snapshotStore = SnapshotStore()

    @State private var selectedTab: DataTab
    @State private var currentRepos: [StarredRepo] = []
    @State private var lastModified: Date?
    @State private var status: DataStatusMessage?
    @State private var showClearCacheAlert = false

    init(settingsManager: SettingsManager, initialTab: DataTab = .transfer) {
        self.settingsManager = settingsManager
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()

            switch selectedTab {
            case .transfer:
                transferTab
            case .browse:
                StarBrowserView(repos: currentRepos)
            case .snapshots:
                SnapshotsView(store: snapshotStore, currentRepos: currentRepos)
            }
        }
        .frame(minWidth: 820, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: reloadCurrent)
        .onReceive(NotificationCenter.default.publisher(for: .repoCacheDidChange)) { _ in
            reloadCurrent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .repoCacheDidSave)) { _ in
            reloadCurrent()
        }
        .overlay(alignment: .bottom) {
            statusBanner
        }
        .alert(L.d.clearCache, isPresented: $showClearCacheAlert) {
            Button(L.d.delete, role: .destructive) {
                RepoCache.shared.clear()
                reloadCurrent()
                showStatus(L.d.clearCacheDone)
            }
            Button(L.d.cancel, role: .cancel) {}
        } message: {
            Text(L.d.clearCacheMessage)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            tabButton(L.d.transferTab, icon: "arrow.up.arrow.down.circle", tab: .transfer)
            tabButton(L.d.browseTab, icon: "list.bullet.rectangle", tab: .browse)
            tabButton(L.d.snapshotsTab, icon: "clock.arrow.circlepath", tab: .snapshots)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tabButton(_ title: String, icon: String, tab: DataTab) -> some View {
        let selected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.accentColor.opacity(0.18) : Color.clear)
                )
                .foregroundStyle(selected ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transfer tab

    private var transferTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L.d.dataManagementSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                currentDataSection
                storageSection
            }
            .padding(20)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private var currentDataSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    DataStatCard(
                        title: L.d.repositories,
                        value: currentRepos.count.formatted(),
                        icon: "shippingbox"
                    )
                    DataStatCard(
                        title: L.d.totalStars,
                        value: SnapshotFormat.number(currentRepos.reduce(0) { $0 + $1.stargazersCount }),
                        icon: "star.fill",
                        tint: .orange
                    )
                    DataStatCard(
                        title: L.d.languages,
                        value: Set(currentRepos.compactMap(\.language)).count.formatted(),
                        icon: "chevron.left.forwardslash.chevron.right"
                    )
                    DataStatCard(
                        title: L.d.lastUpdated,
                        value: lastModified.map(SnapshotFormat.date) ?? L.d.never,
                        icon: "clock"
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        exportJSON()
                    } label: {
                        Label(L.d.exportJSON, systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentRepos.isEmpty)

                    Button {
                        exportCSV()
                    } label: {
                        Label(L.d.exportCSV, systemImage: "tablecells")
                    }
                    .disabled(currentRepos.isEmpty)

                    Button {
                        importJSON()
                    } label: {
                        Label(L.d.importJSON, systemImage: "square.and.arrow.down")
                    }

                    Button {
                        createSnapshot()
                    } label: {
                        Label(L.d.createSnapshot, systemImage: "camera")
                    }
                    .disabled(currentRepos.isEmpty)

                    Spacer(minLength: 0)
                }

                Text(L.d.importHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(6)
        } label: {
            Label(L.d.currentData, systemImage: "shippingbox")
        }
    }

    private var storageSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(L.d.dataFolder)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        revealDataFolder()
                    } label: {
                        Label(L.d.revealInFinder, systemImage: "folder")
                    }
                    .buttonStyle(.borderless)

                    Button(role: .destructive) {
                        showClearCacheAlert = true
                    } label: {
                        Label(L.d.clearCache, systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(currentRepos.isEmpty)
                }

                Text(displayFolderPath)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                    )
            }
            .padding(6)
        } label: {
            Label(L.d.storage, systemImage: "externaldrive")
        }
    }

    // MARK: - Actions

    private func reloadCurrent() {
        currentRepos = RepoCache.shared.load() ?? []
        lastModified = RepoCache.shared.lastModified
    }

    private func exportJSON() {
        guard !currentRepos.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "swiftstarlist-stars-\(SnapshotFormat.timestamp()).json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try snapshotStore.exportArchive(currentRepos, to: url)
            showStatus(L.d.exportSucceeded)
        } catch {
            showStatus("\(L.d.exportFailed): \(error.localizedDescription)", isError: true)
        }
    }

    private func exportCSV() {
        guard !currentRepos.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "swiftstarlist-stars-\(SnapshotFormat.timestamp()).csv"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try snapshotStore.exportCSV(currentRepos, to: url)
            showStatus(L.d.exportSucceeded)
        } catch {
            showStatus("\(L.d.exportFailed): \(error.localizedDescription)", isError: true)
        }
    }

    private func importJSON() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let repos = try StarDataCodec.decodeRepos(from: data)
            guard !repos.isEmpty else { throw StarDataError.emptyFile }

            var message = String(format: L.d.importSucceeded, repos.count)

            if !currentRepos.isEmpty {
                let backupName = "\(L.d.autoBackup) \(SnapshotFormat.date(Date()))"
                snapshotStore.createSnapshot(from: currentRepos, name: backupName)
                message += " · \(L.d.importBackupCreated)"
            }

            RepoCache.shared.save(repos, notify: true)
            reloadCurrent()
            showStatus(message)
        } catch {
            showStatus("\(L.d.importFailed): \(error.localizedDescription)", isError: true)
        }
    }

    private func createSnapshot() {
        guard let snapshot = snapshotStore.createSnapshot(from: currentRepos) else {
            showStatus(snapshotStore.lastError ?? L.d.noData, isError: true)
            return
        }
        selectedTab = .snapshots
        showStatus(String(format: L.d.snapshotCreated, snapshot.repos.count))
    }

    private func revealDataFolder() {
        let folder = dataFolderURL
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    private var dataFolderURL: URL {
        snapshotStore.storageDirectory.deletingLastPathComponent()
    }

    private var displayFolderPath: String {
        let path = dataFolderURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix(home) else { return path }
        return "~" + path.dropFirst(home.count)
    }

    // MARK: - Status

    private var statusBanner: some View {
        Group {
            if let status {
                HStack(spacing: 8) {
                    Image(systemName: status.isError
                          ? "exclamationmark.triangle.fill"
                          : "checkmark.circle.fill")
                    Text(status.text)
                        .lineLimit(3)
                }
                .font(.callout)
                .foregroundStyle(status.isError ? Color.red : Color.green)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08))
                )
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                .padding(.bottom, 18)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @MainActor
    private func showStatus(_ text: String, isError: Bool = false) {
        let message = DataStatusMessage(text: text, isError: isError)
        withAnimation(.easeOut(duration: 0.2)) {
            status = message
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard status?.id == message.id else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                status = nil
            }
        }
    }
}

// MARK: - Star browser

private struct StarBrowserView: View {
    let repos: [StarredRepo]

    @State private var searchText = ""

    private var filteredRepos: [StarredRepo] {
        RepoSearch.filter(repos, query: searchText)
    }

    private var totalStars: Int {
        repos.reduce(0) { $0 + $1.stargazersCount }
    }

    private var yearCount: Int {
        Set(repos.compactMap { repo -> String? in
            guard let starred = repo.starredAt, starred.count >= 4 else { return nil }
            let year = String(starred.prefix(4))
            return Int(year) == nil ? nil : year
        }).count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Label(
                String(format: L.d.repositoryCountFormat, repos.count),
                systemImage: "shippingbox"
            )
            Label(
                String(format: L.d.yearCountFormat, yearCount),
                systemImage: "calendar"
            )
            .help(L.d.groupedByYearHint)
            Label(SnapshotFormat.number(totalStars), systemImage: "star.fill")
                .foregroundStyle(.orange)

            Spacer(minLength: 12)

            StarSearchField(text: $searchText)
                .frame(width: 240)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if repos.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 30))
                    .foregroundStyle(.tertiary)
                Text(L.d.noData)
                    .font(.callout)
                Text(L.d.noDataHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredRepos.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 26))
                    .foregroundStyle(.tertiary)
                Text(L.d.noMatchingRepos)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                RepoYearList(repos: filteredRepos)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Shared search

struct StarSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(L.d.searchRepos, text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

enum RepoSearch {
    static func filter(_ repos: [StarredRepo], query rawQuery: String) -> [StarredRepo] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return repos }

        return repos.filter { repo in
            repo.fullName.localizedCaseInsensitiveContains(query)
                || repo.owner.login.localizedCaseInsensitiveContains(query)
                || (repo.description?.localizedCaseInsensitiveContains(query) ?? false)
                || (repo.language?.localizedCaseInsensitiveContains(query) ?? false)
                || (repo.homepage?.localizedCaseInsensitiveContains(query) ?? false)
                || (repo.starredAt?.localizedCaseInsensitiveContains(query) ?? false)
                || repo.topics.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
}

// MARK: - Year grouping

struct StarYearGroup: Identifiable {
    let year: String
    let repos: [StarredRepo]

    var id: String { year }

    var totalStars: Int {
        repos.reduce(0) { $0 + $1.stargazersCount }
    }

    static func make(from repos: [StarredRepo]) -> [StarYearGroup] {
        let grouped = Dictionary(grouping: repos) { repo -> String in
            guard let starred = repo.starredAt, starred.count >= 4 else {
                return L.d.unknownYear
            }
            let year = String(starred.prefix(4))
            return year.allSatisfy(\.isNumber) ? year : L.d.unknownYear
        }

        return grouped
            .map { entry in
                StarYearGroup(
                    year: entry.key,
                    repos: entry.value.sorted {
                        ($0.starredAt ?? "") > ($1.starredAt ?? "")
                    }
                )
            }
            .sorted { lhs, rhs in
                switch (Int(lhs.year), Int(rhs.year)) {
                case let (left?, right?):
                    return left > right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return false
                }
            }
    }
}

struct RepoYearList: View {
    let repos: [StarredRepo]

    @State private var collapsedYears: Set<String> = []

    private var groups: [StarYearGroup] {
        StarYearGroup.make(from: repos)
    }

    var body: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(groups) { group in
                Section {
                    if !collapsedYears.contains(group.id) {
                        ForEach(group.repos) { repo in
                            StarRepoBrowserRow(repo: repo)
                        }
                    }
                } header: {
                    yearHeader(group)
                }
            }
        }
    }

    private func yearHeader(_ group: StarYearGroup) -> some View {
        let collapsed = collapsedYears.contains(group.id)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if collapsed {
                    collapsedYears.remove(group.id)
                } else {
                    collapsedYears.insert(group.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 10)

                Text(group.year)
                    .font(.system(size: 13, weight: .semibold))

                Text(String(format: L.d.repositoryCountFormat, group.repos.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Label(SnapshotFormat.number(group.totalStars), systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .buttonStyle(.plain)
    }
}

struct StarRepoBrowserRow: View {
    let repo: StarredRepo

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(repo.fullName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                if repo.fork {
                    Text("Fork")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Label(SnapshotFormat.number(repo.stargazersCount), systemImage: "star.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)

                if let url = URL(string: repo.htmlUrl) {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(L.d.openInGitHub)
                }
            }

            if let description = repo.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let language = repo.language {
                    LanguageTag(language: language)
                }

                if let starredAt = repo.starredAt {
                    Label(String(starredAt.prefix(10)), systemImage: "star")
                        .foregroundStyle(.secondary)
                        .help(L.d.starredAt)
                }

                if let pushedAt = repo.pushedAt {
                    Label(String(pushedAt.prefix(10)), systemImage: "clock")
                        .foregroundStyle(.tertiary)
                        .help(L.d.lastPush)
                }

                Spacer(minLength: 0)
            }
            .font(.system(size: 10))

            if !repo.topics.isEmpty {
                FlowLayout(spacing: 5) {
                    ForEach(Array(repo.topics.prefix(8)), id: \.self) { topic in
                        Text("#\(topic)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.primary.opacity(0.045) : Color.clear)
        )
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 6)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct DataStatCard: View {
    let title: String
    let value: String
    var icon: String = "circle"
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.caption)

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06))
        )
    }
}
