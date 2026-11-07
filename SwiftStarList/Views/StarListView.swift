import SwiftUI

struct StarListView: View {
    @ObservedObject var settingsManager: SettingsManager
    @StateObject private var viewModel = StarListViewModel()
    @State private var selectedRepo: StarredRepo?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchText)
                    .id(settingsManager.languageVersion)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                if !viewModel.searchText.isEmpty {
                    scopeBar
                        .id(settingsManager.languageVersion)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                }

                filterBar
                    .id(settingsManager.languageVersion)

                if viewModel.isFromCache {
                    cacheBanner
                }

                if viewModel.isLoading && viewModel.repos.isEmpty {
                    Spacer()
                    ProgressView(L.s.loading)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Text(L.s.loadFailed).font(.headline)
                        Text(error).font(.caption).foregroundColor(.secondary)
                        Button(L.s.retry) {
                            Task { await viewModel.fetchAll(settings: settingsManager.settings) }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    Spacer()
                } else {
                    repoList
                }
            }
            .navigationTitle(L.s.starListTitle)
            .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task { await viewModel.fetchAll(settings: settingsManager.settings) }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help(L.s.refresh)
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                viewModel.loadFromCache()
                if viewModel.repos.isEmpty {
                    await viewModel.fetchAll(settings: settingsManager.settings)
                }
            }
        } detail: {
            if let repo = selectedRepo {
                RepoDetailView(repo: repo, settingsManager: settingsManager)
            } else {
                Text(L.s.selectRepo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.automatic)
    }

    private var scopeBar: some View {
        HStack(spacing: 4) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Button(action: { viewModel.searchScope = scope }) {
                    Text(scope.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(viewModel.searchScope == scope ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                        .foregroundColor(viewModel.searchScope == scope ? .white : .secondary)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            Picker(L.s.sortLabel, selection: $viewModel.sortOption) {
                ForEach(SortOption.allCases, id: \.self) { opt in
                    Text(opt.displayName).tag(opt)
                }
            }
            .labelsHidden()
            .onChange(of: viewModel.sortOption) { _, _ in
                let available = GroupOption.available(for: viewModel.sortOption)
                if !available.contains(viewModel.groupOption) {
                    viewModel.groupOption = .none
                }
            }

            Picker(L.s.groupLabel, selection: $viewModel.groupOption) {
                ForEach(GroupOption.available(for: viewModel.sortOption), id: \.self) { opt in
                    Text(opt.displayName).tag(opt)
                }
            }
            .labelsHidden()

            Spacer()

            HStack(spacing: 6) {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
                Text("\(viewModel.filteredRepos.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                QuickTipView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var cacheBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "internaldrive")
            Text(L.s.showingCache)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var repoList: some View {
        List(selection: $selectedRepo) {
            ForEach(viewModel.groupedRepos, id: \.0) { group in
                if viewModel.groupOption != .none {
                    Section(group.0) {
                        ForEach(group.1) { repo in
                            StarRowView(repo: repo)
                                .tag(repo)
                        }
                    }
                } else {
                    ForEach(group.1) { repo in
                        StarRowView(repo: repo)
                                .tag(repo)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .id(viewModel.searchText + viewModel.searchScope.rawValue + viewModel.sortOption.rawValue + viewModel.groupOption.rawValue + String(settingsManager.languageVersion))
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField(L.s.searchRepo, text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
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

struct StarRowView: View {
    let repo: StarredRepo

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CachedAvatarView(urlString: repo.owner.avatarUrl)
                .frame(width: 32, height: 32)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(repo.fullName)
                    .font(.system(size: 13, weight: .medium))
                Group {
                    if let desc = repo.description {
                        Text(desc)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text(" ")
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                }
                .frame(height: 28, alignment: .topLeading)
                HStack(spacing: 8) {
                    if let lang = repo.language {
                        LanguageTag(language: lang)
                    }
                    Label("\(repo.stargazersCount)", systemImage: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
                HStack(spacing: 12) {
                    if let starredAt = repo.starredAt {
                        Label(starredAt.prefix(10), systemImage: "star")
                    }
                    if let pushedAt = repo.pushedAt {
                        Label(pushedAt.prefix(10), systemImage: "clock")
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .frame(height: 78)
    }
}

struct LanguageTag: View {
    let language: String

    var body: some View {
        Text(language)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(languageColor.opacity(0.15))
            .foregroundColor(languageColor)
            .cornerRadius(4)
    }

    private var languageColor: Color {
        switch language {
        case "Swift": return .orange
        case "Python": return .blue
        case "JavaScript": return .yellow
        case "TypeScript": return .blue
        case "Rust": return .red
        case "Go": return .cyan
        case "Java": return .red
        case "C++": return .purple
        case "C": return .purple
        case "Ruby": return .red
        case "Kotlin": return .purple
        case "Shell": return .green
        case "Dart": return .cyan
        case "PHP": return .purple
        case "C#": return .purple
        case "Objective-C": return .orange
        case "HTML": return .orange
        case "CSS": return .purple
        case "Vue": return .green
        default: return .gray
        }
    }
}

struct CachedAvatarView: View {
    let urlString: String
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color(nsColor: .placeholderTextColor).opacity(0.3)
            }
        }
        .onAppear {
            if let cached = AvatarCache.shared.image(for: urlString) {
                self.image = cached
            } else {
                Task { await loadImage() }
            }
        }
        .onChange(of: urlString) { _, _ in
            if let cached = AvatarCache.shared.image(for: urlString) {
                self.image = cached
            } else {
                image = nil
                Task { await loadImage() }
            }
        }
    }

    private func loadImage() async {
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let nsImage = NSImage(data: data) else { return }
            AvatarCache.shared.setImage(nsImage, for: urlString)
            self.image = nsImage
        } catch {}
    }
}

struct QuickTipView: View {
    @State private var isHovered = false

    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .onHover { hovering in
                isHovered = hovering
            }
            .popover(isPresented: $isHovered, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.s.hintTitle).font(.caption.bold())
                    Text(L.s.hintTopic)
                        .font(.caption)
                    Text(L.s.hintPrivate)
                        .font(.caption)
                }
                .frame(width: 240, alignment: .leading)
                .padding(8)
            }
    }
}
