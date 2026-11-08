import SwiftUI
import AppKit

@main
struct ScreenshotMain {
    static func main() {
        MainActor.assumeIsolated {
            run()
        }
    }

    @MainActor
    private static func run() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        NSApp.appearance = NSAppearance(named: .darkAqua)

        let arguments = Array(CommandLine.arguments.dropFirst())
        let outputDirectory = URL(
            fileURLWithPath: arguments.first ?? "docs",
            isDirectory: true
        )
        let kind = arguments.count > 1 ? arguments[1] : "analysis"
        let language = arguments.count > 2 ? arguments[2] : "en"
        let isChinese = language == "zh"

        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let manager = SettingsManager.shared
        manager.settings.theme = .dark
        manager.settings.language = isChinese ? .zh : .en
        manager.settings.llmConfig.simpleMode = false

        let firstProfile = LLMProfile(
            name: "OpenAI",
            baseURL: "https://api.openai.com",
            apiKey: "sk-demo",
            model: "gpt-4o-mini",
            proxyConfig: .default
        )
        let secondProfile = LLMProfile(
            name: "Local Ollama",
            baseURL: "http://localhost:11434",
            apiKey: "",
            model: "llama3.1",
            proxyConfig: .default
        )
        manager.settings.llmConfig.profiles = [firstProfile, secondProfile]
        manager.settings.llmConfig.defaultProfileID = firstProfile.id

        switch kind {
        case "analysis":
            render(
                AnalysisShot(
                    analysis: isChinese ? chineseAnalysis : englishAnalysis,
                    description: isChinese
                        ? "在 SwiftUI 中渲染 Markdown，支持自定义主题。"
                        : "Render Markdown in SwiftUI with customizable themes."
                ),
                size: CGSize(width: 1000, height: 900),
                to: outputDirectory.appendingPathComponent("analysis-\(language).png")
            )
        case "overview":
            render(
                OverviewShot(
                    analysis: isChinese ? chineseOverviewAnalysis : englishOverviewAnalysis,
                    description: isChinese
                        ? "在 SwiftUI 中渲染 Markdown，支持自定义主题。"
                        : "Render Markdown in SwiftUI with customizable themes."
                ),
                size: CGSize(width: 1200, height: 860),
                to: outputDirectory.appendingPathComponent("overview-\(language).png")
            )
        case "data":
            RepoCache.shared.save(sampleRepos)
            renderHosting(
                DataManagementView(settingsManager: manager),
                size: CGSize(width: 900, height: 620),
                to: outputDirectory.appendingPathComponent("data-\(language).png")
            )
        case "snapshots":
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("swiftstarlist-snapshots-\(UUID().uuidString)", isDirectory: true)
            let store = SnapshotStore(directory: directory)
            let olderDate = ISO8601DateFormatter().date(from: "2026-10-01T10:00:00Z") ?? Date()
            let newerDate = ISO8601DateFormatter().date(from: "2026-11-08T10:00:00Z") ?? Date()
            let older = store.createSnapshot(
                from: snapshotOld,
                name: isChinese ? "2026-10-01 快照" : "2026-10-01 Snapshot",
                createdAt: olderDate
            )
            let newer = store.createSnapshot(
                from: snapshotNew,
                name: isChinese ? "2026-11-08 快照" : "2026-11-08 Snapshot",
                createdAt: newerDate
            )
            renderHosting(
                SnapshotsView(
                    store: store,
                    currentRepos: snapshotNew,
                    initialSnapshotID: newer?.id,
                    initialCompareID: older?.id
                ),
                size: CGSize(width: 1000, height: 700),
                to: outputDirectory.appendingPathComponent("snapshots-\(language).png")
            )
            try? FileManager.default.removeItem(at: directory)
        default:
            renderHosting(
                SettingsShot(manager: manager),
                size: CGSize(width: 480, height: 550),
                to: outputDirectory.appendingPathComponent("settings-\(language).png")
            )
        }
    }

    @MainActor
    private static func render<V: View>(_ view: V, size: CGSize, to url: URL) {
        let renderer = ImageRenderer(
            content: view
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            print("Failed to render \(url.lastPathComponent)")
            return
        }

        do {
            try png.write(to: url, options: .atomic)
            print("Wrote \(url.path)")
        } catch {
            print("Failed to write \(url.path): \(error)")
        }
    }

    @MainActor
    private static func renderHosting<V: View>(_ view: V, size: CGSize, to url: URL) {
        let content = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)

        let hosting = NSHostingView(rootView: content)
        hosting.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.alphaValue = 0
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.contentView = hosting
        window.orderFrontRegardless()
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("Failed to create bitmap for \(url.lastPathComponent)")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)

        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: url, options: .atomic)
            print("Wrote \(url.path)")
        }

        window.orderOut(nil)
        window.contentView = nil
    }

    private static var englishAnalysis: RepoAnalysis {
        RepoAnalysis(
            summary: "A SwiftUI library for rendering Markdown with fully customizable themes.",
            categories: ["SwiftUI", "Markdown", "macOS & iOS"],
            coreFeatures: [
                "Renders Markdown directly inside SwiftUI views",
                "Custom themes, fonts and spacing",
                "Supports images, tables and code blocks"
            ],
            techStack: ["Swift", "SwiftUI", "cmark-gfm"],
            useCases: [
                "AI chat and assistant interfaces",
                "Documentation and note-taking apps",
                "Any text-rich SwiftUI interface"
            ],
            activityLevel: "medium",
            activityReason: "Regular releases and recent commits, maintained by a small team.",
            audience: "Swift developers building text-heavy interfaces",
            pros: [
                "Idiomatic SwiftUI API",
                "Highly customizable themes",
                "Handles CommonMark and GFM"
            ],
            cons: [
                "Limited control over some block layouts",
                "Small contributor base"
            ],
            similarProjects: ["MarkdownKit", "Down"],
            recommendation: "Recommended if you need Markdown rendering inside a SwiftUI app without building a parser or layout engine yourself."
        )
    }

    private static var chineseAnalysis: RepoAnalysis {
        RepoAnalysis(
            summary: "一个在 SwiftUI 中渲染 Markdown 的库，支持完全自定义主题。",
            categories: ["SwiftUI", "Markdown", "macOS & iOS"],
            coreFeatures: [
                "在 SwiftUI 视图中直接渲染 Markdown",
                "自定义主题、字体与间距",
                "支持图片、表格与代码块"
            ],
            techStack: ["Swift", "SwiftUI", "cmark-gfm"],
            useCases: [
                "AI 对话与助手界面",
                "文档与笔记应用",
                "需要展示富文本的 SwiftUI 界面"
            ],
            activityLevel: "medium",
            activityReason: "保持稳定发布和近期提交，由小团队维护。",
            audience: "需要构建富文本界面的 Swift 开发者",
            pros: [
                "符合 SwiftUI 习惯的 API",
                "主题定制能力强",
                "支持 CommonMark 与 GFM"
            ],
            cons: [
                "部分块级布局的可控性有限",
                "贡献者规模较小"
            ],
            similarProjects: ["MarkdownKit", "Down"],
            recommendation: "如果需要在 SwiftUI 应用中渲染 Markdown，又不想自己实现解析和排版，推荐使用。"
        )
    }

    private static var englishOverviewAnalysis: RepoAnalysis {
        RepoAnalysis(
            summary: "A SwiftUI library for rendering Markdown with fully customizable themes.",
            categories: ["SwiftUI", "Markdown"],
            coreFeatures: [
                "Renders Markdown directly inside SwiftUI views",
                "Custom themes, fonts and spacing"
            ],
            techStack: ["Swift", "SwiftUI", "cmark-gfm"],
            useCases: ["AI chat and assistant interfaces"],
            activityLevel: "medium",
            activityReason: "Regular releases and recent commits.",
            audience: "Swift developers building text-heavy interfaces",
            pros: ["Idiomatic SwiftUI API", "Highly customizable themes"],
            cons: ["Small contributor base"],
            similarProjects: ["MarkdownKit"],
            recommendation: "Recommended for SwiftUI apps that need Markdown rendering."
        )
    }

    private static var chineseOverviewAnalysis: RepoAnalysis {
        RepoAnalysis(
            summary: "一个在 SwiftUI 中渲染 Markdown 的库，支持完全自定义主题。",
            categories: ["SwiftUI", "Markdown"],
            coreFeatures: [
                "在 SwiftUI 视图中直接渲染 Markdown",
                "自定义主题、字体与间距"
            ],
            techStack: ["Swift", "SwiftUI", "cmark-gfm"],
            useCases: ["AI 对话与助手界面"],
            activityLevel: "medium",
            activityReason: "保持稳定发布和近期提交。",
            audience: "需要构建富文本界面的 Swift 开发者",
            pros: ["符合 SwiftUI 习惯的 API", "主题定制能力强"],
            cons: ["贡献者规模较小"],
            similarProjects: ["MarkdownKit"],
            recommendation: "适合需要在 SwiftUI 应用中渲染 Markdown 的场景。"
        )
    }

    private static var sampleRepos: [StarredRepo] {
        [
            StarredRepo(
                id: 1,
                name: "swift-markdown-ui",
                fullName: "gonzalezreal/swift-markdown-ui",
                owner: RepoOwner(login: "gonzalezreal", avatarUrl: ""),
                htmlUrl: "https://github.com/gonzalezreal/swift-markdown-ui",
                description: "Render Markdown in SwiftUI with customizable themes.",
                stargazersCount: 2476,
                language: "Swift",
                topics: ["markdown", "swiftui"],
                createdAt: "2020-01-01T00:00:00Z",
                updatedAt: "2026-11-05T00:00:00Z",
                pushedAt: "2026-11-05T00:00:00Z",
                fork: false,
                homepage: nil,
                starredAt: "2026-09-25T00:00:00Z"
            ),
            StarredRepo(
                id: 2,
                name: "openai-codex",
                fullName: "openai/codex",
                owner: RepoOwner(login: "openai", avatarUrl: ""),
                htmlUrl: "https://github.com/openai/codex",
                description: "Lightweight coding agent that runs in your terminal.",
                stargazersCount: 133540,
                language: "Rust",
                topics: ["agent", "cli"],
                createdAt: "2025-01-01T00:00:00Z",
                updatedAt: "2026-11-07T00:00:00Z",
                pushedAt: "2026-11-07T00:00:00Z",
                fork: false,
                homepage: nil,
                starredAt: "2026-07-20T00:00:00Z"
            ),
            StarredRepo(
                id: 3,
                name: "mitmproxy",
                fullName: "mitmproxy/mitmproxy",
                owner: RepoOwner(login: "mitmproxy", avatarUrl: ""),
                htmlUrl: "https://github.com/mitmproxy/mitmproxy",
                description: "An interactive TLS-capable intercepting HTTP proxy.",
                stargazersCount: 46699,
                language: "Python",
                topics: ["proxy", "security"],
                createdAt: "2010-01-01T00:00:00Z",
                updatedAt: "2026-11-04T00:00:00Z",
                pushedAt: "2026-11-04T00:00:00Z",
                fork: false,
                homepage: nil,
                starredAt: "2026-07-09T00:00:00Z"
            ),
            StarredRepo(
                id: 4,
                name: "libdeflate",
                fullName: "ebiggers/libdeflate",
                owner: RepoOwner(login: "ebiggers", avatarUrl: ""),
                htmlUrl: "https://github.com/ebiggers/libdeflate",
                description: "Heavily optimized library for DEFLATE/zlib/gzip compression.",
                stargazersCount: 1324,
                language: "C",
                topics: ["compression"],
                createdAt: "2016-01-01T00:00:00Z",
                updatedAt: "2026-11-06T00:00:00Z",
                pushedAt: "2026-11-06T00:00:00Z",
                fork: false,
                homepage: nil,
                starredAt: "2026-09-14T00:00:00Z"
            ),
            StarredRepo(
                id: 5,
                name: "scriban",
                fullName: "scriban/scriban",
                owner: RepoOwner(login: "scriban", avatarUrl: ""),
                htmlUrl: "https://github.com/scriban/scriban",
                description: "A fast, powerful and safe scripting language for .NET.",
                stargazersCount: 3989,
                language: "C#",
                topics: ["dotnet", "templating"],
                createdAt: "2016-01-01T00:00:00Z",
                updatedAt: "2026-10-24T00:00:00Z",
                pushedAt: "2026-10-24T00:00:00Z",
                fork: false,
                homepage: nil,
                starredAt: "2026-07-29T00:00:00Z"
            ),
            StarredRepo(
                id: 6,
                name: "herdr",
                fullName: "herdrdev/herdr",
                owner: RepoOwner(login: "herdrdev", avatarUrl: ""),
                htmlUrl: "https://github.com/herdrdev/herdr",
                description: "The runtime your coding agents live on.",
                stargazersCount: 48883,
                language: "Rust",
                topics: ["agents", "runtime"],
                createdAt: "2025-01-01T00:00:00Z",
                updatedAt: "2026-11-03T00:00:00Z",
                pushedAt: "2026-11-03T00:00:00Z",
                fork: false,
                homepage: nil,
                starredAt: "2026-07-12T00:00:00Z"
            )
        ]
    }

    private static var snapshotOld: [StarredRepo] {
        [
            demoRepo(1, "gonzalezreal/swift-markdown-ui", description: "Render Markdown in SwiftUI with customizable themes.", language: "Swift", stars: 2400, starredAt: "2026-09-25T00:00:00Z"),
            demoRepo(2, "openai/codex", description: "Lightweight coding agent that runs in your terminal.", language: "Rust", stars: 130000, starredAt: "2026-07-20T00:00:00Z"),
            demoRepo(3, "mitmproxy/mitmproxy", description: "An interactive TLS-capable intercepting HTTP proxy.", language: "Python", stars: 46699, starredAt: "2026-07-09T00:00:00Z"),
            demoRepo(4, "ebiggers/libdeflate", description: "Heavily optimized library for DEFLATE/zlib/gzip compression.", language: "C", stars: 1300, starredAt: "2026-09-14T00:00:00Z"),
            demoRepo(5, "scriban/scriban", description: "A fast, powerful and safe scripting language for .NET.", language: "C#", stars: 3989, starredAt: "2026-07-29T00:00:00Z")
        ]
    }

    private static var snapshotNew: [StarredRepo] {
        [
            demoRepo(1, "gonzalezreal/swift-markdown-ui", description: "Render Markdown in SwiftUI with customizable themes.", language: "Swift", stars: 2476, starredAt: "2026-09-25T00:00:00Z"),
            demoRepo(2, "openai/codex", description: "Lightweight coding agent that runs in your terminal.", language: "Rust", stars: 133540, starredAt: "2026-07-20T00:00:00Z"),
            demoRepo(3, "mitmproxy/mitmproxy", description: "An interactive TLS-capable intercepting HTTP proxy.", language: "Python", stars: 46699, starredAt: "2026-07-09T00:00:00Z"),
            demoRepo(4, "ebiggers/libdeflate", description: "Heavily optimized library for DEFLATE/zlib/gzip compression.", language: "C", stars: 1324, starredAt: "2026-09-14T00:00:00Z"),
            demoRepo(6, "herdrdev/herdr", description: "The runtime your coding agents live on.", language: "Rust", stars: 48883, starredAt: "2026-07-12T00:00:00Z")
        ]
    }

    private static func demoRepo(
        _ id: Int,
        _ fullName: String,
        description: String,
        language: String,
        stars: Int,
        starredAt: String
    ) -> StarredRepo {
        let parts = fullName.split(separator: "/")
        let owner = parts.first.map(String.init) ?? "owner"
        let name = parts.last.map(String.init) ?? fullName

        return StarredRepo(
            id: id,
            name: name,
            fullName: fullName,
            owner: RepoOwner(login: owner, avatarUrl: ""),
            htmlUrl: "https://github.com/\(fullName)",
            description: description,
            stargazersCount: stars,
            language: language,
            topics: [],
            createdAt: "2020-01-01T00:00:00Z",
            updatedAt: "2026-11-05T00:00:00Z",
            pushedAt: "2026-11-05T00:00:00Z",
            fork: false,
            homepage: nil,
            starredAt: starredAt
        )
    }
}

private struct AnalysisShot: View {
    let analysis: RepoAnalysis
    let description: String

    var body: some View {
        DetailPreview(analysis: analysis, description: description)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct OverviewShot: View {
    let analysis: RepoAnalysis
    let description: String

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                SidebarPreview()
                    .frame(width: 320)
                Divider()
                DetailPreview(analysis: analysis, description: description)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 1.0, green: 0.37, blue: 0.34))
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color(red: 0.15, green: 0.78, blue: 0.25))
                .frame(width: 12, height: 12)

            Spacer()

            Text("Github Star List")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12))
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(Circle())
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SidebarPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 8)
                .padding(.top, 8)

            filterBar
                .padding(.horizontal, 12)
                .padding(.vertical, 4)

            VStack(spacing: 2) {
                row(
                    index: 0,
                    name: "gonzalezreal/swift-markdown-ui",
                    description: "Render Markdown in SwiftUI with customizable themes.",
                    language: "Swift",
                    stars: "2,476",
                    starredAt: "2026-09-25",
                    pushedAt: "2026-11-05",
                    selected: true
                )
                row(index: 1, name: "ebiggers/libdeflate", description: "Heavily optimized library for DEFLATE/zlib/gzip compression.", language: "C", stars: "1,324", starredAt: "2026-09-14", pushedAt: "2026-11-06")
                row(index: 2, name: "openai/codex", description: "Lightweight coding agent that runs in your terminal.", language: "Rust", stars: "133,540", starredAt: "2026-07-20", pushedAt: "2026-11-07")
                row(index: 3, name: "mitmproxy/mitmproxy", description: "An interactive TLS-capable intercepting HTTP proxy.", language: "Python", stars: "46,699", starredAt: "2026-07-09", pushedAt: "2026-11-04")
                row(index: 4, name: "scriban/scriban", description: "A fast, powerful and safe scripting language for .NET.", language: "C#", stars: "3,989", starredAt: "2026-07-29", pushedAt: "2026-10-24")
                row(index: 5, name: "ravindu644/Droidspaces-OSS", description: "A lightweight container runtime for Android and Linux.", language: "Kotlin", stars: "2,476", starredAt: "2026-09-25", pushedAt: "2026-11-05")
                row(index: 6, name: "herdrdev/herdr", description: "The runtime your coding agents live on.", language: "Rust", stars: "48,883", starredAt: "2026-07-12", pushedAt: "2026-11-03")
            }
            .padding(.horizontal, 6)

            Spacer(minLength: 0)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(L.s.searchRepo)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    private var filterBar: some View {
        HStack(spacing: 6) {
            picker(L.s.sortStarredAt)
            picker(L.s.groupNone)
            Spacer()
            Text("337")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Image(systemName: "info.circle")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private func picker(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11))
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }

    private func row(
        index: Int,
        name: String,
        description: String,
        language: String,
        stars: String,
        starredAt: String,
        pushedAt: String,
        selected: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(avatarGradient(index))
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(selected ? .white : .primary)
                    .lineLimit(1)

                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(selected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if selected {
                        Text(language)
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    } else {
                        LanguageTag(language: language)
                    }
                    Label(stars, systemImage: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(selected ? .white : .orange)
                }

                HStack(spacing: 12) {
                    Label(starredAt, systemImage: "star")
                    Label(pushedAt, systemImage: "clock")
                }
                .font(.system(size: 9))
                .foregroundColor(selected ? .white.opacity(0.7) : .secondary.opacity(0.7))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selected ? Color.accentColor : Color.clear)
        )
    }

    private func avatarGradient(_ index: Int) -> LinearGradient {
        let palettes: [[Color]] = [
            [.purple, .blue],
            [.orange, .pink],
            [.teal, .blue],
            [.green, .mint],
            [.pink, .purple],
            [.indigo, .cyan],
            [.red, .orange]
        ]
        let colors = palettes[index % palettes.count]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct DetailPreview: View {
    let analysis: RepoAnalysis
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            RepoAnalysisCard(analysis: analysis, state: .finished, raw: nil)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            Spacer(minLength: 0)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.9), .blue.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("M")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("gonzalezreal/swift-markdown-ui")
                        .font(.system(size: 19, weight: .bold))
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Label(L.s.openInGithub, systemImage: "arrow.up.right.square")
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(6)
            }

            HStack(spacing: 12) {
                LanguageTag(language: "Swift")
                Label("2,476", systemImage: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text("#markdown")
                    .font(.caption)
                    .foregroundColor(.link)
                Text("#swiftui")
                    .font(.caption)
                    .foregroundColor(.link)
            }

            HStack(spacing: 8) {
                tab(L.s.readmeTab, icon: "doc.text", selected: false, color: .accentColor)
                tab(L.s.activityTab, icon: "chart.bar", selected: false, color: .green)
                tab(L.s.infoTab, icon: "person.3", selected: false, color: .cyan)
                tab(L.s.issuesTab, icon: "ticket", selected: false, color: .orange)
                Spacer()
                tab(L.s.aiTab, icon: "sparkles", selected: true, color: .purple)
            }
        }
        .padding(16)
    }

    private func tab(_ title: String, icon: String, selected: Bool, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selected ? color : Color(nsColor: .controlBackgroundColor))
            .foregroundColor(selected ? .white : .secondary)
            .cornerRadius(6)
    }
}

private struct SettingsShot: View {
    let manager: SettingsManager

    var body: some View {
        VStack(spacing: 0) {
            windowChrome
            Divider()
            tabBar
            Divider()

            SettingsView(settingsManager: manager).llmTab
                .frame(width: 480, height: 470)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var windowChrome: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 1.0, green: 0.37, blue: 0.34))
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color(red: 1.0, green: 0.74, blue: 0.18))
                .frame(width: 12, height: 12)
            Circle()
                .fill(Color(red: 0.15, green: 0.78, blue: 0.25))
                .frame(width: 12, height: 12)

            Spacer()

            Text("Github Star List Settings")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)

            Spacer()

            HStack(spacing: 8) {
                Color.clear.frame(width: 12, height: 12)
                Color.clear.frame(width: 12, height: 12)
                Color.clear.frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            tab(L.s.generalTab, icon: "gearshape", selected: false)
            tab(L.s.githubSection, icon: "network", selected: false)
            tab("LLM", icon: "sparkles", selected: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func tab(_ title: String, icon: String, selected: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(selected ? Color.accentColor.opacity(0.18) : Color.clear)
            .foregroundColor(selected ? .primary : .secondary)
            .cornerRadius(6)
    }
}
