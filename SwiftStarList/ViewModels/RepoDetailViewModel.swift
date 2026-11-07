import Foundation

@MainActor
final class RepoDetailViewModel: ObservableObject {
    @Published var readmeContent: String?
    @Published var readmeFailed = false
    @Published var analysis: String?
    @Published var analysisResult: RepoAnalysis?
    @Published var isLoadingREADME = false
    @Published var isLoadingAnalysis = false
    @Published var errorMessage: String?
    @Published var activityErrorMessage: String?

    private let githubService = GitHubService()
    private let llmService = LLMService()
    private var analysisTask: Task<Void, Never>?
    private var readmeGeneration = 0
    private var activityGeneration = 0
    private var analysisGeneration = 0

    @Published var recentTags: [RepoTag] = []
    @Published var recentCommits: [RepoCommit] = []
    @Published var recentReleases: [RepoRelease] = []
    @Published var contributors: [RepoContributor] = []
    @Published var languages: [String: Int] = [:]
    @Published var license: RepoLicense?
    @Published var openIssues: [RepoIssue] = []
    @Published var openPulls: [RepoPullRequest] = []
    @Published var isLoadingActivity = false

    func reset() {
        analysisGeneration += 1
        readmeGeneration += 1
        activityGeneration += 1
        analysisTask?.cancel()
        analysisTask = nil
        readmeContent = nil
        readmeFailed = false
        analysis = nil
        analysisResult = nil
        errorMessage = nil
        activityErrorMessage = nil
        isLoadingREADME = false
        isLoadingAnalysis = false
        recentTags = []
        recentCommits = []
        recentReleases = []
        contributors = []
        languages = [:]
        license = nil
        openIssues = []
        openPulls = []
        isLoadingActivity = false
    }

    func fetchREADME(repo: StarredRepo, settings: AppSettings) async {
        readmeGeneration += 1
        let generation = readmeGeneration
        isLoadingREADME = true
        defer {
            if generation == readmeGeneration { isLoadingREADME = false }
        }

        do {
            let content = try await githubService.fetchREADME(
                owner: repo.owner.login,
                repo: repo.name,
                settings: settings
            )
            guard generation == readmeGeneration, !Task.isCancelled else { return }
            readmeContent = content
            readmeFailed = false
        } catch is CancellationError {
            // 切换仓库导致取消，忽略
        } catch {
            guard generation == readmeGeneration, !Task.isCancelled else { return }
            readmeContent = L.s.cannotGetReadme
            readmeFailed = true
        }
    }

    /// 在 ViewModel 内持有任务句柄，切仓库时可以真正取消流式分析
    func startAnalysis(repo: StarredRepo, settings: AppSettings) {
        analysisGeneration += 1
        let generation = analysisGeneration
        analysisTask?.cancel()
        errorMessage = nil
        analysisResult = nil
        analysis = ""
        isLoadingAnalysis = true
        analysisTask = Task { [weak self] in
            await self?.analyzeRepo(repo: repo, settings: settings, generation: generation)
        }
    }

    private func analyzeRepo(repo: StarredRepo, settings: AppSettings, generation: Int) async {
        if readmeContent == nil {
            await fetchREADME(repo: repo, settings: settings)
        }

        guard generation == analysisGeneration, !Task.isCancelled else { return }

        // README 获取失败时仍然可以基于元数据分析
        let readme = readmeFailed ? "" : (readmeContent ?? "")

        isLoadingAnalysis = true
        errorMessage = nil
        analysis = ""
        analysisResult = nil
        defer {
            if generation == analysisGeneration { isLoadingAnalysis = false }
        }

        do {
            let details = try? await githubService.fetchRepoDetails(
                owner: repo.owner.login,
                repo: repo.name,
                settings: settings
            )
            guard generation == analysisGeneration, !Task.isCancelled else { return }

            // 给动态数据一点时间，尽量让提示词包含语言构成、贡献者、提交等信息
            await waitForActivityContext()
            guard generation == analysisGeneration, !Task.isCancelled else { return }

            let input = RepoAnalysisInput(
                repo: repo,
                details: details,
                readme: readme,
                languages: languages,
                contributors: contributors,
                releases: recentReleases,
                commits: recentCommits,
                issues: openIssues,
                pulls: openPulls,
                license: license
            )

            let result = try await llmService.analyzeStream(
                input: input, settings: settings,
                onChunk: { [weak self] partial in
                    guard !Task.isCancelled else { return }
                    Task { @MainActor in
                        guard let self, generation == self.analysisGeneration else { return }
                        self.analysis = partial
                    }
                }
            )
            guard generation == analysisGeneration, !Task.isCancelled else { return }
            analysis = result
            analysisResult = RepoAnalysis.parse(from: result)
        } catch is CancellationError {
            // 用户切换了仓库，丢弃结果
        } catch {
            if generation == analysisGeneration, !Task.isCancelled, (analysis?.isEmpty ?? true) {
                errorMessage = "\(L.s.analyzeFailed): \(error.localizedDescription)"
            }
        }
    }

    func fetchRepoActivity(repo: StarredRepo, settings: AppSettings) async {
        activityGeneration += 1
        let generation = activityGeneration
        isLoadingActivity = true
        activityErrorMessage = nil
        defer {
            if generation == activityGeneration { isLoadingActivity = false }
        }

        let service = githubService
        let owner = repo.owner.login
        let name = repo.name

        // 每个请求独立容错：单个接口失败（例如无许可证时 /license 返回 404）
        // 不再导致整个页面为空
        async let tagsResult = Self.capture { try await service.fetchRecentTags(owner: owner, repo: name, settings: settings) }
        async let commitsResult = Self.capture { try await service.fetchRecentCommits(owner: owner, repo: name, settings: settings) }
        async let releasesResult = Self.capture { try await service.fetchRecentReleases(owner: owner, repo: name, settings: settings) }
        async let contribsResult = Self.capture { try await service.fetchContributors(owner: owner, repo: name, settings: settings) }
        async let langsResult = Self.capture { try await service.fetchLanguages(owner: owner, repo: name, settings: settings) }
        async let licenseResult = Self.capture { try await service.fetchLicense(owner: owner, repo: name, settings: settings) }
        async let issuesResult = Self.capture { try await service.fetchOpenIssues(owner: owner, repo: name, settings: settings) }
        async let pullsResult = Self.capture { try await service.fetchOpenPulls(owner: owner, repo: name, settings: settings) }

        let (tags, commits, releases, contribs, langs, lic, issues, pulls) =
            await (tagsResult, commitsResult, releasesResult, contribsResult, langsResult, licenseResult, issuesResult, pullsResult)

        guard generation == activityGeneration, !Task.isCancelled else { return }

        var failures = 0

        if let tags { recentTags = tags } else { failures += 1 }
        if let commits { recentCommits = commits } else { failures += 1 }
        if let releases { recentReleases = releases } else { failures += 1 }
        if let contribs { contributors = contribs } else { failures += 1 }
        if let langs { languages = langs } else { failures += 1 }
        // 没有许可证时接口返回 404，属于正常情况，不算失败
        license = lic ?? nil
        if let issues { openIssues = issues } else { failures += 1 }
        if let pulls { openPulls = pulls } else { failures += 1 }

        if failures > 0 {
            activityErrorMessage = L.s.someDataFailed
        }
    }

    private nonisolated static func capture<T>(_ operation: @escaping () async throws -> T) async -> T? {
        try? await operation()
    }

    /// 最多等待 1.5 秒，避免自动分析时动态数据尚未加载完成
    private func waitForActivityContext() async {
        var waited = 0
        while isLoadingActivity && waited < 1500 {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(100))
            waited += 100
        }
    }
}
