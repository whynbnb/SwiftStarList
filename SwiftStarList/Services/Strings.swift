import Foundation

enum L {
    static var s: Strings {
        AppLanguage.resolved == .zh ? .zh : .en
    }
}

struct Strings {
    let sortStarredAt: String
    let sortName: String
    let sortStars: String
    let sortUpdated: String
    let groupNone: String
    let groupLanguage: String
    let groupStarredAtYear: String
    let groupPushedAtYear: String
    let groupNameLetter: String
    let groupStarsRange: String
    let scopeAll: String
    let scopeName: String
    let scopeLanguage: String
    let scopeTopic: String
    let scopeDescription: String
    let starListTitle: String
    let showingCache: String
    let loading: String
    let loadFailed: String
    let someDataFailed: String
    let retry: String
    let refresh: String
    let searchRepo: String
    let selectRepo: String
    let openInGithub: String
    let readmeTab: String
    let aiTab: String
    let loadingReadme: String
    let cannotGetReadme: String
    let encodingFailed: String
    let analyzing: String
    let analyzeRepo: String
    let startAnalysis: String
    let llmNoResponse: String
    let configureApiKey: String
    let analyzeFailed: String
    let readReadmeFirst: String
    let githubSection: String
    let githubToken: String
    let llmSection: String
    let baseURL: String
    let apiKey: String
    let model: String
    let proxyMode: String
    let host: String
    let port: String
    let autoAnalyze: String
    let languageSection: String
    let generalTab: String
    let themeSection: String
    let systemLanguage: String
    let systemTheme: String
    let lightTheme: String
    let darkTheme: String
    let proxyNone: String
    let proxySystem: String
    let hintTitle: String
    let hintTopic: String
    let hintPrivate: String
    let other: String
    let unknown: String
    let invalidURL: String
    let unauthorized: String
    let httpError: String
    let decodingError: String
    let sortLabel: String
    let groupLabel: String
    let activityTab: String
    let recentTags: String
    let recentCommits: String
    let recentReleases: String
    let noTags: String
    let noCommits: String
    let noReleases: String
    let loadingActivity: String
    let draftBadge: String
    let prereleaseBadge: String
    let contributors: String
    let noContributors: String
    let languages: String
    let noLanguages: String
    let license: String
    let noLicense: String
    let openIssues: String
    let noOpenIssues: String
    let openPulls: String
    let noOpenPulls: String
    let infoTab: String
    let issuesTab: String

    static let zh = Strings(
        sortStarredAt: "收藏时间",
        sortName: "名称",
        sortStars: "Star数",
        sortUpdated: "更新时间",
        groupNone: "无分组",
        groupLanguage: "按语言",
        groupStarredAtYear: "按收藏年份",
        groupPushedAtYear: "按更新年份",
        groupNameLetter: "按首字母",
        groupStarsRange: "按Star数",
        scopeAll: "全部",
        scopeName: "标题",
        scopeLanguage: "语言",
        scopeTopic: "标签",
        scopeDescription: "描述",
        starListTitle: "Star 列表",
        showingCache: "正在显示本地缓存",
        loading: "加载中...",
        loadFailed: "加载失败",
        someDataFailed: "部分数据加载失败",
        retry: "重试",
        refresh: "刷新",
        searchRepo: "搜索仓库...",
        selectRepo: "选择一个仓库查看详情",
        openInGithub: "在GitHub中打开",
        readmeTab: "README",
        aiTab: "AI 分析",
        loadingReadme: "加载README...",
        cannotGetReadme: "无法获取README",
        encodingFailed: "编码转换失败",
        analyzing: "AI 正在分析...",
        analyzeRepo: "点击下方按钮让AI分析此仓库",
        startAnalysis: "开始分析",
        llmNoResponse: "LLM未返回有效响应",
        configureApiKey: "请先配置LLM API Key",
        analyzeFailed: "LLM分析失败",
        readReadmeFirst: "无法获取README，请先确保README加载成功",
        githubSection: "GitHub",
        githubToken: "GitHub Token",
        llmSection: "LLM 设置",
        baseURL: "Base URL",
        apiKey: "API Key",
        model: "Model",
        proxyMode: "代理模式",
        host: "主机地址",
        port: "端口",
        autoAnalyze: "点击AI分析时自动开始",
        languageSection: "语言",
        generalTab: "通用",
        themeSection: "外观",
        systemLanguage: "跟随系统",
        systemTheme: "跟随系统",
        lightTheme: "浅色",
        darkTheme: "深色",
        proxyNone: "无",
        proxySystem: "系统代理",
        hintTitle: "提示",
        hintTopic: "• GitHub 页面包含关注的主题，因此数量可能更多",
        hintPrivate: "• 此处不包含私有仓库的 Star",
        other: "其他",
        unknown: "未知",
        invalidURL: "无效的URL",
        unauthorized: "未授权，请检查 Token 或 API Key",
        httpError: "HTTP错误",
        decodingError: "解码错误",
        sortLabel: "排序",
        groupLabel: "分组",
        activityTab: "动态",
        recentTags: "最近标签",
        recentCommits: "最近提交",
        recentReleases: "最近发布",
        noTags: "暂无标签",
        noCommits: "暂无提交",
        noReleases: "暂无发布",
        loadingActivity: "加载动态...",
        draftBadge: "草稿",
        prereleaseBadge: "预发布",
        contributors: "贡献者",
        noContributors: "暂无贡献者",
        languages: "语言",
        noLanguages: "暂无语言数据",
        license: "许可证",
        noLicense: "暂无许可证",
        openIssues: "未关闭 Issue",
        noOpenIssues: "暂无未关闭 Issue",
        openPulls: "未合并 PR",
        noOpenPulls: "暂无未合并 PR",
        infoTab: "概览",
        issuesTab: "Issue/PR"
    )

    static let en = Strings(
        sortStarredAt: "Starred At",
        sortName: "Name",
        sortStars: "Stars",
        sortUpdated: "Updated",
        groupNone: "None",
        groupLanguage: "By Language",
        groupStarredAtYear: "By Starred Year",
        groupPushedAtYear: "By Updated Year",
        groupNameLetter: "By First Letter",
        groupStarsRange: "By Stars",
        scopeAll: "All",
        scopeName: "Name",
        scopeLanguage: "Language",
        scopeTopic: "Topic",
        scopeDescription: "Description",
        starListTitle: "Star List",
        showingCache: "Showing cached data",
        loading: "Loading...",
        loadFailed: "Load Failed",
        someDataFailed: "Some data failed to load",
        retry: "Retry",
        refresh: "Refresh",
        searchRepo: "Search repos...",
        selectRepo: "Select a repo to view details",
        openInGithub: "Open in GitHub",
        readmeTab: "README",
        aiTab: "AI Analysis",
        loadingReadme: "Loading README...",
        cannotGetReadme: "Unable to get README",
        encodingFailed: "Encoding conversion failed",
        analyzing: "AI is analyzing...",
        analyzeRepo: "Click the button below to let AI analyze this repo",
        startAnalysis: "Start Analysis",
        llmNoResponse: "LLM returned no valid response",
        configureApiKey: "Please configure LLM API Key first",
        analyzeFailed: "LLM analysis failed",
        readReadmeFirst: "Unable to get README, please ensure README loads successfully first",
        githubSection: "GitHub",
        githubToken: "GitHub Token",
        llmSection: "LLM Settings",
        baseURL: "Base URL",
        apiKey: "API Key",
        model: "Model",
        proxyMode: "Proxy Mode",
        host: "Host",
        port: "Port",
        autoAnalyze: "Auto-start on clicking AI Analysis",
        languageSection: "Language",
        generalTab: "General",
        themeSection: "Appearance",
        systemLanguage: "System",
        systemTheme: "System",
        lightTheme: "Light",
        darkTheme: "Dark",
        proxyNone: "None",
        proxySystem: "System Proxy",
        hintTitle: "Tip",
        hintTopic: "• GitHub page includes followed topics, so count may be higher",
        hintPrivate: "• Private repos' stars are not included here",
        other: "Other",
        unknown: "Unknown",
        invalidURL: "Invalid URL",
        unauthorized: "Unauthorized, please check your token or API key",
        httpError: "HTTP Error",
        decodingError: "Decoding error",
        sortLabel: "Sort",
        groupLabel: "Group",
        activityTab: "Activity",
        recentTags: "Recent Tags",
        recentCommits: "Recent Commits",
        recentReleases: "Recent Releases",
        noTags: "No tags yet",
        noCommits: "No commits yet",
        noReleases: "No releases yet",
        loadingActivity: "Loading activity...",
        draftBadge: "Draft",
        prereleaseBadge: "Pre-release",
        contributors: "Contributors",
        noContributors: "No contributors",
        languages: "Languages",
        noLanguages: "No language data",
        license: "License",
        noLicense: "No license",
        openIssues: "Open Issues",
        noOpenIssues: "No open issues",
        openPulls: "Open PRs",
        noOpenPulls: "No open PRs",
        infoTab: "Overview",
        issuesTab: "Issues/PRs"
    )
}
