import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SnapshotsView: View {
    @ObservedObject var store: SnapshotStore
    let currentRepos: [StarredRepo]

    @State private var selectedID: UUID?
    @State private var compareID: UUID?
    @State private var searchText = ""
    @State private var nameDraft = ""
    @State private var status: DataStatusMessage?
    @State private var snapshotToDelete: StarSnapshot?

    init(
        store: SnapshotStore,
        currentRepos: [StarredRepo],
        initialSnapshotID: UUID? = nil,
        initialCompareID: UUID? = nil
    ) {
        self.store = store
        self.currentRepos = currentRepos
        _selectedID = State(initialValue: initialSnapshotID)
        _compareID = State(initialValue: initialCompareID)
    }

    private var selectedSnapshot: StarSnapshot? {
        store.snapshots.first { $0.id == selectedID }
    }

    private var compareSnapshot: StarSnapshot? {
        store.snapshots.first { $0.id == compareID }
    }

    var body: some View {
        HSplitView {
            sidebar
            detail
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            ensureSelection()
            nameDraft = selectedSnapshot?.name ?? ""
        }
        .onChange(of: store.snapshots.map(\.id)) { _, _ in
            ensureSelection()
        }
        .onChange(of: selectedID) { _, _ in
            compareID = nil
            nameDraft = selectedSnapshot?.name ?? ""
            searchText = ""
        }
        .overlay(alignment: .bottom) {
            statusBanner
        }
        .alert(item: $snapshotToDelete) { snapshot in
            Alert(
                title: Text(L.d.deleteSnapshot),
                message: Text(L.d.deleteSnapshotMessage),
                primaryButton: .destructive(Text(L.d.delete)) {
                    store.delete(snapshot)
                    if selectedID == snapshot.id {
                        selectedID = store.snapshots.first?.id
                    }
                    if compareID == snapshot.id {
                        compareID = nil
                    }
                },
                secondaryButton: .cancel(Text(L.d.cancel))
            )
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(L.d.snapshots)
                    .font(.headline)

                Spacer()

                Button {
                    createSnapshot()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help(L.d.newSnapshot)
                .disabled(currentRepos.isEmpty)

                Button {
                    importSnapshot()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .help(L.d.importSnapshot)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if store.snapshots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(L.d.noSnapshots)
                        .font(.callout)
                    Text(L.d.noSnapshotsHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedID) {
                    ForEach(store.snapshots) { snapshot in
                        SnapshotRow(snapshot: snapshot)
                            .tag(snapshot.id)
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            Text(L.d.snapshotHelp)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04))
        }
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 340, maxHeight: .infinity)
    }

    // MARK: - Detail

    private var detail: some View {
        Group {
            if let snapshot = selectedSnapshot {
                VStack(spacing: 0) {
                    snapshotHeader(snapshot)
                    Divider()

                    if let compare = compareSnapshot {
                        SnapshotCompareView(base: snapshot, target: compare)
                    } else {
                        SnapshotDetailContent(
                            snapshot: snapshot,
                            searchText: $searchText
                        )
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 34))
                        .foregroundStyle(.tertiary)
                    Text(L.d.selectSnapshot)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
    }

    private func snapshotHeader(_ snapshot: StarSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField(L.d.snapshotName, text: $nameDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18, weight: .semibold))
                    .onSubmit { commitRename(snapshot) }

                Button {
                    commitRename(snapshot)
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderless)
                .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines) == snapshot.name)
                .help(L.d.snapshotName)

                Spacer()
            }

            HStack(spacing: 14) {
                Label(SnapshotFormat.date(snapshot.createdAt), systemImage: "calendar")
                Label(snapshot.repos.count.formatted(), systemImage: "shippingbox")
                Label(SnapshotFormat.number(snapshot.totalStars), systemImage: "star.fill")
                    .foregroundStyle(.orange)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Picker(L.d.compareWith, selection: $compareID) {
                    Text(L.d.noComparison).tag(Optional<UUID>.none)
                    ForEach(store.snapshots.filter { $0.id != snapshot.id }) { other in
                        Text(other.name).tag(Optional(other.id))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 260)

                if compareID != nil {
                    Button {
                        compareID = nil
                    } label: {
                        Label(L.d.close, systemImage: "xmark")
                    }
                    .buttonStyle(.borderless)
                }

                Spacer()

                Button {
                    exportSnapshot(snapshot)
                } label: {
                    Label(L.d.exportSnapshot, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive) {
                    snapshotToDelete = snapshot
                } label: {
                    Label(L.d.deleteSnapshot, systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
    }

    // MARK: - Actions

    private func ensureSelection() {
        if let selectedID, store.snapshots.contains(where: { $0.id == selectedID }) {
            return
        }
        selectedID = store.snapshots.first?.id
    }

    private func commitRename(_ snapshot: StarSnapshot) {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            nameDraft = snapshot.name
            return
        }
        store.rename(snapshot.id, to: trimmed)
        nameDraft = trimmed
    }

    private func createSnapshot() {
        guard let snapshot = store.createSnapshot(from: currentRepos) else {
            showStatus(store.lastError ?? L.d.noData, isError: true)
            return
        }
        selectedID = snapshot.id
        showStatus(String(format: L.d.snapshotCreated, snapshot.repos.count))
    }

    private func importSnapshot() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let snapshot = try store.importSnapshot(from: url)
            selectedID = snapshot.id
            showStatus(String(format: L.d.importedSnapshot, snapshot.name))
        } catch {
            showStatus("\(L.d.importFailed): \(error.localizedDescription)", isError: true)
        }
    }

    private func exportSnapshot(_ snapshot: StarSnapshot) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(safeFileName(snapshot.name)).json"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try store.export(snapshot, to: url)
            showStatus(L.d.exportSucceeded)
        } catch {
            showStatus("\(L.d.exportFailed): \(error.localizedDescription)", isError: true)
        }
    }

    private func safeFileName(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = name
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "snapshot" : cleaned
    }

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

// MARK: - Sidebar row

private struct SnapshotRow: View {
    let snapshot: StarSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(snapshot.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(SnapshotFormat.date(snapshot.createdAt))
                Spacer(minLength: 4)
                Label(snapshot.repos.count.formatted(), systemImage: "shippingbox")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Snapshot detail

struct SnapshotDetailContent: View {
    let snapshot: StarSnapshot
    @Binding var searchText: String

    private var filteredRepos: [StarredRepo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let repos: [StarredRepo]

        if query.isEmpty {
            repos = snapshot.repos
        } else {
            repos = snapshot.repos.filter {
                $0.fullName.localizedCaseInsensitiveContains(query)
                    || ($0.description?.localizedCaseInsensitiveContains(query) ?? false)
                    || ($0.language?.localizedCaseInsensitiveContains(query) ?? false)
                    || $0.topics.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }

        return repos.sorted { ($0.starredAt ?? "") > ($1.starredAt ?? "") }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    DataStatCard(
                        title: L.d.repositories,
                        value: snapshot.repos.count.formatted(),
                        icon: "shippingbox"
                    )
                    DataStatCard(
                        title: L.d.totalStars,
                        value: SnapshotFormat.number(snapshot.totalStars),
                        icon: "star.fill",
                        tint: .orange
                    )
                    DataStatCard(
                        title: L.d.languages,
                        value: snapshot.languageCounts.count.formatted(),
                        icon: "chevron.left.forwardslash.chevron.right"
                    )
                }

                if !snapshot.languageCounts.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(snapshot.languageCounts.prefix(10))) { item in
                            HStack(spacing: 4) {
                                LanguageTag(language: item.name)
                                Text(item.count.formatted())
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(L.d.searchRepos, text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
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

                if filteredRepos.isEmpty {
                    Text(L.d.noData)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredRepos) { repo in
                            SnapshotRepoRow(repo: repo)
                            Divider()
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Comparison

struct SnapshotCompareView: View {
    let base: StarSnapshot
    let target: StarSnapshot

    /// 始终按时间从旧到新对比，避免“新增/取消”语义反转。
    private var orderedBase: StarSnapshot {
        base.createdAt <= target.createdAt ? base : target
    }

    private var orderedTarget: StarSnapshot {
        base.createdAt <= target.createdAt ? target : base
    }

    private var diff: SnapshotDiff {
        SnapshotDiff(base: orderedBase, target: orderedTarget)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                comparisonHeader

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140), spacing: 10)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    DataStatCard(
                        title: L.d.added,
                        value: diff.added.count.formatted(),
                        icon: "plus.circle.fill",
                        tint: .green
                    )
                    DataStatCard(
                        title: L.d.removed,
                        value: diff.removed.count.formatted(),
                        icon: "minus.circle.fill",
                        tint: .red
                    )
                    DataStatCard(
                        title: L.d.changed,
                        value: diff.changed.count.formatted(),
                        icon: "arrow.triangle.2.circlepath",
                        tint: .orange
                    )
                    DataStatCard(
                        title: L.d.netStars,
                        value: SnapshotFormat.signedNumber(diff.starDelta),
                        icon: "star.fill",
                        tint: diff.starDelta == 0
                            ? .secondary
                            : (diff.starDelta > 0 ? .green : .red)
                    )
                }

                if !diff.hasDifferences {
                    VStack(spacing: 6) {
                        Image(systemName: "equal.circle")
                            .font(.system(size: 26))
                            .foregroundStyle(.tertiary)
                        Text(L.d.noDifferences)
                            .font(.callout)
                        Text(L.d.noDifferencesHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    if !diff.added.isEmpty {
                        repoSection(
                            title: L.d.added,
                            icon: "plus.circle.fill",
                            color: .green,
                            repos: diff.added
                        )
                    }

                    if !diff.removed.isEmpty {
                        repoSection(
                            title: L.d.removed,
                            icon: "minus.circle.fill",
                            color: .red,
                            repos: diff.removed
                        )
                    }

                    if !diff.changed.isEmpty {
                        changedSection
                    }
                }
            }
            .padding(16)
        }
    }

    private var comparisonHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L.d.base)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(orderedBase.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(SnapshotFormat.date(orderedBase.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(L.d.target)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(orderedTarget.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(SnapshotFormat.date(orderedTarget.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
    }

    private func repoSection(
        title: String,
        icon: String,
        color: Color,
        repos: [StarredRepo]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                Spacer()
                Text(repos.count.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)

            LazyVStack(spacing: 0) {
                ForEach(repos) { repo in
                    SnapshotRepoRow(repo: repo)
                    Divider()
                }
            }
        }
    }

    private var changedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(L.d.changed, systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Text(diff.changed.count.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)

            LazyVStack(spacing: 0) {
                ForEach(diff.changed) { change in
                    ChangedRepoRow(change: change)
                    Divider()
                }
            }
        }
    }
}

// MARK: - Rows

private struct SnapshotRepoRow: View {
    let repo: StarredRepo

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(repo.fullName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                if let description = repo.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    if let language = repo.language {
                        LanguageTag(language: language)
                    }
                    Label(SnapshotFormat.number(repo.stargazersCount), systemImage: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    if let starredAt = repo.starredAt {
                        Label(String(starredAt.prefix(10)), systemImage: "star")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
    }
}

private struct ChangedRepoRow: View {
    let change: SnapshotDiff.ChangedRepo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(change.repo.fullName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                if change.starDelta != 0 {
                    Label(SnapshotFormat.signedNumber(change.starDelta), systemImage: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(change.starDelta > 0 ? Color.green : Color.red)
                }
            }

            ForEach(change.changes) { fieldChange in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(fieldChange.field.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(fieldChange.oldValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .strikethrough()
                        .lineLimit(1)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)

                    Text(fieldChange.newValue)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 7)
    }
}
