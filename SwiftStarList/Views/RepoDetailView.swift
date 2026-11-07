import SwiftUI
import MarkdownUI

struct RepoDetailView: View {
    let repo: StarredRepo
    @ObservedObject var settingsManager: SettingsManager
    @StateObject private var viewModel = RepoDetailViewModel()
    @State private var selectedTab: DetailTab = .readme

    private enum DetailTab {
        case readme, activity, info, issues, ai
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            Divider()
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: repo.id) {
            selectedTab = .readme
            viewModel.reset()
            async let readmeTask: Void = viewModel.fetchREADME(repo: repo, settings: settingsManager.settings)
            async let activityTask: Void = viewModel.fetchRepoActivity(repo: repo, settings: settingsManager.settings)
            _ = await (readmeTask, activityTask)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CachedAvatarView(urlString: repo.owner.avatarUrl)
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())

                Text(repo.fullName)
                    .font(.title2.bold())

                Spacer()

                if let url = URL(string: repo.htmlUrl) {
                    Link(destination: url) {
                        Label(L.s.openInGithub, systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.bordered)
                    .id(settingsManager.languageVersion)
                }
            }

            if let desc = repo.description {
                Text(desc)
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                if let lang = repo.language {
                    LanguageTag(language: lang)
                }
                Label("\(repo.stargazersCount)", systemImage: "star.fill")
                    .foregroundColor(.orange)
                if !repo.topics.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(repo.topics, id: \.self) { topic in
                                Text("#\(topic)")
                                    .font(.caption)
                                    .foregroundColor(.link)
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TabButton(title: L.s.readmeTab, icon: "doc.text", isSelected: selectedTab == .readme, selectedColor: .accentColor) {
                    selectedTab = .readme
                }
                .id(settingsManager.languageVersion)

                TabButton(title: L.s.activityTab, icon: "chart.bar", isSelected: selectedTab == .activity, selectedColor: .green) {
                    selectedTab = .activity
                }
                .id(settingsManager.languageVersion)

                TabButton(title: L.s.infoTab, icon: "person.3", isSelected: selectedTab == .info, selectedColor: .cyan) {
                    selectedTab = .info
                }
                .id(settingsManager.languageVersion)

                TabButton(title: L.s.issuesTab, icon: "ticket", isSelected: selectedTab == .issues, selectedColor: .orange) {
                    selectedTab = .issues
                }
                .id(settingsManager.languageVersion)

                TabButton(title: L.s.aiTab, icon: "sparkles", isSelected: selectedTab == .ai, selectedColor: .purple) {
                    selectedTab = .ai
                    if settingsManager.settings.autoAnalyze && viewModel.analysis == nil {
                        viewModel.startAnalysis(repo: repo, settings: settingsManager.settings)
                    }
                }
                .id(settingsManager.languageVersion)
            }
        }
        .padding()
    }

    private var mainContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading) {
                    switch selectedTab {
                    case .readme:
                        readmeView
                    case .activity:
                        activityView(proxy: proxy)
                    case .info:
                        infoView
                    case .issues:
                        issuesView
                    case .ai:
                        analysisView(proxy: proxy)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var readmeView: some View {
        if viewModel.isLoadingREADME {
            VStack(spacing: 12) {
                ProgressView()
                Text(L.s.loadingReadme)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if let content = viewModel.readmeContent {
            Markdown(content)
                .markdownTheme(.transparent)
                .tint(.accentColor)
        }
    }

    @ViewBuilder
    private func activityView(proxy: ScrollViewProxy) -> some View {
        if viewModel.isLoadingActivity {
            VStack(spacing: 12) {
                ProgressView()
                Text(L.s.loadingActivity)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                activityErrorBanner
                tagsSection(proxy: proxy)
                releasesSection
                commitsSection
            }
        }
    }

    @ViewBuilder
    private var infoView: some View {
        if viewModel.isLoadingActivity {
            VStack(spacing: 12) {
                ProgressView()
                Text(L.s.loadingActivity)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                activityErrorBanner
                contributorsSection
                languagesSection
                licenseSection
            }
        }
    }

    @ViewBuilder
    private var issuesView: some View {
        if viewModel.isLoadingActivity {
            VStack(spacing: 12) {
                ProgressView()
                Text(L.s.loadingActivity)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                activityErrorBanner
                openIssuesSection
                openPullsSection
            }
        }
    }

    @ViewBuilder
    private var activityErrorBanner: some View {
        if let message = viewModel.activityErrorMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.orange)
                .id(settingsManager.languageVersion)
        }
    }

    @ViewBuilder
    private var releasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.s.recentReleases)
                .font(.title3.bold())
                .id(settingsManager.languageVersion)

            if viewModel.recentReleases.isEmpty {
                Text(L.s.noReleases)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            } else {
                ForEach(viewModel.recentReleases) { release in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if let url = URL(string: repo.htmlUrl) {
                                Link(destination: url.appendingPathComponent("releases/tag/\(release.tagName)")) {
                                    Text(release.tagName)
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            } else {
                                Text(release.tagName)
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            if release.draft {
                                Text(L.s.draftBadge)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                            if release.prerelease {
                                Text(L.s.prereleaseBadge)
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(4)
                            }
                            Spacer()
                            if let published = release.publishedAt {
                                Text(published.prefix(10))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        if let name = release.name, name != release.tagName {
                            Text(name)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        if let author = release.author, let login = author.login {
                            HStack(spacing: 4) {
                                Text(login)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let body = release.body, !body.isEmpty {
                            let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
                            let preview = lines.prefix(8).joined(separator: "\n")
                            VStack(alignment: .leading, spacing: 2) {
                                Markdown(preview)
                                    .markdownTheme(.transparent)
                                    .tint(.link)
                                    .font(.system(size: 12))
                                if lines.count > 8 {
                                    Text("...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .id("release-\(release.tagName)")
                }
            }
        }
    }

    @ViewBuilder
    private func tagsSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.s.recentTags)
                .font(.title3.bold())
                .id(settingsManager.languageVersion)

            if viewModel.recentTags.isEmpty {
                Text(L.s.noTags)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(viewModel.recentTags) { tag in
                        let hasRelease = viewModel.recentReleases.contains { $0.tagName == tag.name }
                        Button {
                            if hasRelease {
                                withAnimation {
                                    proxy.scrollTo("release-\(tag.name)", anchor: .top)
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text(tag.name)
                                if hasRelease {
                                    Image(systemName: "arrow.up.right.circle.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.green)
                                }
                            }
                            .font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var commitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.s.recentCommits)
                .font(.title3.bold())
                .id(settingsManager.languageVersion)

            if viewModel.recentCommits.isEmpty {
                Text(L.s.noCommits)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            } else {
                ForEach(viewModel.recentCommits) { commit in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(commit.commit.message.split(separator: "\n").first.map(String.init) ?? "")
                                .font(.system(size: 12))
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                if let login = commit.author?.login {
                                    Text(login)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                if let date = commit.commit.author?.date {
                                    Text(date.prefix(10))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Spacer()
                        if let url = URL(string: repo.htmlUrl) {
                            Link(destination: url.appendingPathComponent("commit/\(commit.sha)")) {
                                Text(commit.sha.prefix(7))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func analysisView(proxy: ScrollViewProxy) -> some View {
        if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                Button(L.s.reanalyze) {
                    viewModel.startAnalysis(repo: repo, settings: settingsManager.settings)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if let result = viewModel.analysisResult {
            VStack(alignment: .leading, spacing: 12) {
                RepoAnalysisCard(result: result, raw: viewModel.analysis ?? "")
                Button(L.s.reanalyze) {
                    viewModel.startAnalysis(repo: repo, settings: settingsManager.settings)
                }
                .buttonStyle(.bordered)
            }
            .id(settingsManager.languageVersion)
        } else if viewModel.isLoadingAnalysis {
            VStack(spacing: 12) {
                ProgressView()
                Text(L.s.analyzing)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else if let analysis = viewModel.analysis, !analysis.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label(L.s.analysisRawFallback, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .id(settingsManager.languageVersion)
                Markdown(analysis)
                    .markdownTheme(.transparent)
                    .tint(.purple)
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundColor(.purple)
                Text(L.s.analyzeRepo)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
                Button(L.s.startAnalysis) {
                    viewModel.startAnalysis(repo: repo, settings: settingsManager.settings)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        }
    }

    @ViewBuilder
    private var contributorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.s.contributors)
                .font(.title3.bold())
                .id(settingsManager.languageVersion)

            if viewModel.contributors.isEmpty {
                Text(L.s.noContributors)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(viewModel.contributors) { contributor in
                        HStack(spacing: 4) {
                            CachedAvatarView(urlString: contributor.avatarUrl)
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())

                            Text(contributor.login)
                                .font(.system(size: 12))

                            Text("\(contributor.contributions)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.06))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var languagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.s.languages)
                .font(.title3.bold())
                .id(settingsManager.languageVersion)

            if viewModel.languages.isEmpty {
                Text(L.s.noLanguages)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            } else {
                let sorted = viewModel.languages.sorted { $0.value > $1.value }
                let total = sorted.map(\.value).reduce(0, +)

                VStack(spacing: 6) {
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            ForEach(sorted, id: \.key) { lang, bytes in
                                let ratio = total > 0 ? CGFloat(bytes) / CGFloat(total) : 0
                                Rectangle()
                                    .fill(languageColor(lang))
                                    .frame(width: max(geo.size.width * ratio, 2))
                            }
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 8)
                    .padding(.trailing, 8)

                    FlowLayout(spacing: 8) {
                        ForEach(sorted, id: \.key) { lang, bytes in
                            let pct = total > 0 ? String(format: "%.1f", Double(bytes) / Double(total) * 100) : "0"
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(languageColor(lang))
                                    .frame(width: 8, height: 8)
                                Text(lang)
                                    .font(.system(size: 11))
                                Text("\(pct)%")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.s.license)
                .font(.title3.bold())
                .id(settingsManager.languageVersion)

            if let lic = viewModel.license {
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge.gearshape")
                        .foregroundColor(.secondary)
                    if let url = lic.htmlUrl, let linkUrl = URL(string: url) {
                        Link(destination: linkUrl) {
                            Text(lic.name)
                                .font(.system(size: 13))
                        }
                    } else {
                        Text(lic.name)
                            .font(.system(size: 13))
                    }
                    if let spdx = lic.spdxId, spdx != "NOASSERTION" {
                        Text(spdx)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            } else {
                Text(L.s.noLicense)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            }
        }
    }

    @ViewBuilder
    private var openIssuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.s.openIssues)
                .font(.title3.bold())
                .id(settingsManager.languageVersion)

            if viewModel.openIssues.isEmpty {
                Text(L.s.noOpenIssues)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            } else {
                ForEach(viewModel.openIssues) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            if let url = URL(string: issue.htmlUrl) {
                                Link(destination: url) {
                                    Text("#\(issue.number) \(issue.title)")
                                        .font(.system(size: 12))
                                        .lineLimit(2)
                                }
                            } else {
                                Text("#\(issue.number) \(issue.title)")
                                    .font(.system(size: 12))
                                    .lineLimit(2)
                            }
                            HStack(spacing: 6) {
                                if let login = issue.user?.login {
                                    Text(login)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Text(issue.createdAt.prefix(10))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                if let labels = issue.labels, !labels.isEmpty {
                                    ForEach(labels, id: \.name) { label in
                                        Text(label.name)
                                            .font(.system(size: 9, weight: .medium))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color(hex: label.color).opacity(0.2))
                                            .foregroundColor(Color(hex: label.color))
                                            .cornerRadius(3)
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var openPullsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.s.openPulls)
                .font(.title3.bold())
                .id(settingsManager.languageVersion)

            if viewModel.openPulls.isEmpty {
                Text(L.s.noOpenPulls)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .id(settingsManager.languageVersion)
            } else {
                ForEach(viewModel.openPulls) { pr in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            if let url = URL(string: pr.htmlUrl) {
                                Link(destination: url) {
                                    Text("#\(pr.number) \(pr.title)")
                                        .font(.system(size: 12))
                                        .lineLimit(2)
                                }
                            } else {
                                Text("#\(pr.number) \(pr.title)")
                                    .font(.system(size: 12))
                                    .lineLimit(2)
                            }
                            HStack(spacing: 6) {
                                if let login = pr.user?.login {
                                    Text(login)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Text(pr.createdAt.prefix(10))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct RepoAnalysisCard: View {
    let result: RepoAnalysis
    let raw: String
    @State private var showRaw = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryView
            chipSection(L.s.analysisCategories, result.categories)
            bulletSection(L.s.analysisFeatures, result.coreFeatures)
            chipSection(L.s.analysisTechStack, result.techStack)
            bulletSection(L.s.analysisUseCases, result.useCases)
            activitySection
            audienceSection
            prosConsSection
            bulletSection(L.s.analysisSimilar, result.similarProjects)
            recommendationSection
            rawSection
        }
    }

    private var summaryView: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)
            Text(result.summary)
                .font(.system(size: 14, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func chipSection(_ title: String, _ values: [String]?) -> some View {
        if let values, !values.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle(title)
                FlowLayout(spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.system(size: 11))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(5)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bulletSection(_ title: String, _ values: [String]?) -> some View {
        if let values, !values.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle(title)
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text(value)
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        if let level = result.activityLevel, !level.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle(L.s.analysisActivity)
                HStack(alignment: .top, spacing: 8) {
                    Text(activityText(level))
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(activityColor(level).opacity(0.15))
                        .foregroundColor(activityColor(level))
                        .cornerRadius(5)
                    if let reason = result.activityReason, !reason.isEmpty {
                        Text(reason)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var audienceSection: some View {
        if let audience = result.audience, !audience.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle(L.s.analysisAudience)
                Text(audience)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var prosConsSection: some View {
        let pros = result.pros ?? []
        let cons = result.cons ?? []
        if !pros.isEmpty || !cons.isEmpty {
            HStack(alignment: .top, spacing: 20) {
                bulletColumn(L.s.analysisPros, pros, color: .green)
                bulletColumn(L.s.analysisCons, cons, color: .orange)
            }
        }
    }

    private func bulletColumn(_ title: String, _ values: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle(title)
            if values.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        Text(value)
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var recommendationSection: some View {
        if let recommendation = result.recommendation, !recommendation.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle(L.s.analysisRecommendation)
                Text(recommendation)
                    .font(.system(size: 12))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private var rawSection: some View {
        if !raw.isEmpty {
            DisclosureGroup(isExpanded: $showRaw) {
                Markdown(raw)
                    .markdownTheme(.transparent)
                    .tint(.purple)
                    .textSelection(.enabled)
                    .padding(.top, 6)
            } label: {
                Text(L.s.rawOutput)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
    }

    private func activityText(_ level: String) -> String {
        switch level.lowercased() {
        case "high": return L.s.activityHigh
        case "medium": return L.s.activityMedium
        case "low": return L.s.activityLow
        default: return level
        }
    }

    private func activityColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "high": return .green
        case "medium": return .orange
        case "low": return .gray
        default: return .secondary
        }
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? selectedColor : Color(nsColor: .controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .secondary)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

private func languageColor(_ name: String) -> Color {
    let map: [String: String] = [
        "Swift": "F05138", "Rust": "DEA584", "Python": "3572A5",
        "JavaScript": "F7DF1E", "TypeScript": "3178C6", "Go": "00ADD8",
        "Java": "B07219", "C": "555555", "C++": "F34B7D",
        "C#": "178600", "Ruby": "CC342D", "PHP": "4F5D95",
        "Kotlin": "A97BFF", "Dart": "00B4AB", "Shell": "89E051",
        "Scala": "C22D40", "Lua": "000080", "R": "198CE7",
        "Objective-C": "438EFF", "Perl": "0298C3", "Haskell": "5E5086",
        "Zig": "EC915C", "Elixir": "6E4A7E", "Clojure": "DB5857",
        "HTML": "E34C26", "CSS": "563D7C", "Vue": "41B883",
        "Svelte": "FF3E00", "Jupyter Notebook": "DA5B0B",
        "Makefile": "427819", "Dockerfile": "384D54",
    ]
    return Color(hex: map[name] ?? "8B949E")
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
