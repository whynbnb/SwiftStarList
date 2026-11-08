import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum DataTab: Hashable {
    case transfer
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

    @State private var selectedTab: DataTab = .transfer
    @State private var currentRepos: [StarredRepo] = []
    @State private var lastModified: Date?
    @State private var status: DataStatusMessage?
    @State private var showClearCacheAlert = false

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()

            switch selectedTab {
            case .transfer:
                transferTab
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
