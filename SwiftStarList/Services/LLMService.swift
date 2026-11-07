import Foundation

actor LLMService {
    private let network = NetworkManager.shared

    func analyzeStream(input: RepoAnalysisInput, settings: AppSettings, onChunk: @escaping (String) -> Void) async throws -> String {
        let s = L.s
        let isZh = AppLanguage.resolve(settings.language) == .zh
        guard let profile = settings.llmConfig.defaultProfile else {
            throw NetworkError.invalidConfiguration
        }

        let simpleMode = settings.llmConfig.simpleMode == true
        let systemMessage: String

        if simpleMode {
            systemMessage = isZh
                ? "你是一个专业的 GitHub 仓库分析助手，请用中文简洁地分析仓库，直接输出 Markdown，不要输出 JSON。"
                : "You are a professional GitHub repository analysis assistant. Provide a concise analysis in English as Markdown, not JSON."
        } else if isZh {
            systemMessage = """
            你是一个专业的开源项目分析助手。请只输出一个合法的 JSON 对象，不要输出 Markdown 代码块、前后说明或其他文字。所有文本使用中文。
            JSON 结构（所有字段都必须存在；没有内容的数组输出 []；请严格按下列字段顺序输出，便于客户端逐步渲染）：
            {
              "summary": "一句话概括项目",
              "categories": ["分类"],
              "coreFeatures": ["核心功能"],
              "techStack": ["技术/框架"],
              "useCases": ["适用场景"],
              "activityLevel": "high | medium | low",
              "activityReason": "活跃度判断依据",
              "audience": "目标用户",
              "pros": ["优点"],
              "cons": ["不足"],
              "similarProjects": ["相似项目"],
              "recommendation": "是否推荐及理由"
            }
            """
        } else {
            systemMessage = """
            You are a professional open-source project analyst. Output exactly one valid JSON object, with no Markdown code fences, explanations, or other text. All text in English.
            JSON schema (all fields must be present; use [] for empty arrays; output fields in exactly this order so the client can render progressively):
            {
              "summary": "one sentence summary",
              "categories": ["category"],
              "coreFeatures": ["core feature"],
              "techStack": ["technology/framework"],
              "useCases": ["use case"],
              "activityLevel": "high | medium | low",
              "activityReason": "reason for the activity rating",
              "audience": "target users",
              "pros": ["strength"],
              "cons": ["weakness"],
              "similarProjects": ["similar project"],
              "recommendation": "whether to recommend and why"
            }
            """
        }

        var context = makeContext(input: input, isZh: isZh)
        if let extra = settings.llmConfig.customPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
           !extra.isEmpty {
            context += "\n\n" + (isZh ? "## 额外要求（优先遵守）\n" : "## Additional Requirements (follow these)\n") + extra
        }

        let outputInstruction: String
        if simpleMode {
            outputInstruction = isZh
                ? """
                请从以下方面分析该仓库，使用 Markdown 输出：
                1. 项目简介（一句话概括）
                2. 核心功能
                3. 技术栈
                4. 适用场景
                5. 活跃度评估
                """
                : """
                Analyze the repository from these aspects and output Markdown:
                1. Brief summary (one sentence)
                2. Core features
                3. Tech stack
                4. Use cases
                5. Activity assessment
                """
        } else {
            outputInstruction = isZh
                ? "请根据以上信息分析该仓库，并严格按要求的 JSON 结构输出。"
                : "Analyze this repository using the information above and output strictly in the required JSON schema."
        }

        let prompt = """
        \(context)

        \(outputInstruction)
        """

        let request = ChatCompletionRequest(
            model: profile.model,
            messages: [
                ChatMessage(role: "system", content: systemMessage),
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.3,
            stream: true
        )

        let baseURL = profile.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !baseURL.isEmpty, !profile.model.isEmpty else { throw NetworkError.invalidConfiguration }
        let path = baseURL.hasSuffix("/v1") ? "chat/completions" : "v1/chat/completions"
        guard let url = URL(string: "\(baseURL)/\(path)"), url.scheme != nil else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !profile.apiKey.isEmpty {
            urlRequest.setValue("Bearer \(profile.apiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let session = network.makeSessionForProxy(profile.proxyConfig)
        let (bytes, response) = try await session.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            return s.llmNoResponse
        }
        if httpResponse.statusCode == 401 { throw NetworkError.unauthorized }
        if !(200...299).contains(httpResponse.statusCode) {
            var body = ""
            for try await line in bytes.lines {
                body.append(line)
            }
            throw NetworkError.httpError(httpResponse.statusCode, body)
        }

        var result = ""
        let decoder = JSONDecoder()
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if data == "[DONE]" { break }
            guard let lineData = data.data(using: .utf8) else { continue }
            guard let chunk = try? decoder.decode(ChatCompletionStreamResponse.self, from: lineData) else { continue }
            guard let content = chunk.choices.first?.delta.content else { continue }
            result.append(content)
            onChunk(result)
        }

        guard !result.isEmpty else {
            return s.llmNoResponse
        }
        return result
    }

    private func makeContext(input: RepoAnalysisInput, isZh: Bool) -> String {
        let repo = input.repo
        let details = input.details
        var lines: [String] = []

        lines.append(isZh ? "## 基本信息" : "## Basic Info")
        lines.append("Name: \(repo.fullName)")
        lines.append("Description: \(details?.description ?? repo.description ?? "-")")
        if let homepage = details?.homepage, !homepage.isEmpty {
            lines.append("Homepage: \(homepage)")
        }
        lines.append("Primary language: \(details?.language ?? repo.language ?? "unknown")")

        let stars = details?.stargazersCount ?? repo.stargazersCount
        let forks = details.map { String($0.forksCount) } ?? "-"
        let watchers = details?.watchersCount.map(String.init) ?? "-"
        let openIssues = details.map { String($0.openIssuesCount) } ?? "-"
        lines.append("Stars: \(stars) | Forks: \(forks) | Watchers: \(watchers) | Open issues (incl. PRs): \(openIssues)")

        if let subscribers = details?.subscribersCount {
            lines.append("Subscribers: \(subscribers)")
        }
        let topics = (details?.topics ?? []).isEmpty ? repo.topics : (details?.topics ?? [])
        if !topics.isEmpty {
            lines.append("Topics: \(topics.joined(separator: ", "))")
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        lines.append("Current date: \(dateFormatter.string(from: Date()))")
        lines.append("Created: \(details?.createdAt ?? repo.createdAt)")
        lines.append("Last pushed: \(details?.pushedAt ?? repo.pushedAt ?? "-")")
        if let branch = details?.defaultBranch {
            lines.append("Default branch: \(branch)")
        }
        if let size = details?.size {
            lines.append("Repo size: \(size) KB")
        }
        if details?.archived == true { lines.append("Archived: yes") }
        if details?.disabled == true { lines.append("Disabled: yes") }
        if details?.fork == true { lines.append("Fork: yes") }

        let license = details?.license ?? input.license
        if let license {
            let spdx = license.spdxId.map { " (\($0))" } ?? ""
            lines.append("License: \(license.name)\(spdx)")
        } else {
            lines.append("License: none")
        }

        let totalBytes = input.languages.values.reduce(0, +)
        if totalBytes > 0 {
            let parts = input.languages
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map { name, bytes -> String in
                    let percentage = Double(bytes) / Double(totalBytes) * 100
                    return "\(name) \(String(format: "%.1f", percentage))%"
                }
            lines.append("Language breakdown: \(parts.joined(separator: ", "))")
        }

        if !input.contributors.isEmpty {
            let parts = input.contributors.prefix(10).map { "\($0.login)(\($0.contributions))" }
            lines.append("Top contributors: \(parts.joined(separator: ", "))")
        }

        if !input.releases.isEmpty {
            let parts = input.releases.prefix(5).map { release -> String in
                var text = release.tagName
                if let name = release.name, !name.isEmpty, name != release.tagName {
                    text += " (\(name))"
                }
                if let date = release.publishedAt {
                    text += " @ \(date.prefix(10))"
                }
                if release.prerelease { text += " [prerelease]" }
                return text
            }
            lines.append("Recent releases: \(parts.joined(separator: "; "))")

            if let latest = input.releases.first,
               let body = latest.body?.trimmingCharacters(in: .whitespacesAndNewlines),
               !body.isEmpty {
                lines.append(isZh ? "最新 Release 说明（截断）：" : "Latest release notes (truncated):")
                lines.append(String(body.prefix(800)))
            }
        }

        if !input.commits.isEmpty {
            let parts = input.commits.prefix(10).map { commit -> String in
                let message = commit.commit.message
                    .split(separator: "\n").first.map(String.init) ?? ""
                let date = commit.commit.author?.date?.prefix(10) ?? ""
                let author = commit.author?.login ?? commit.commit.author?.name ?? ""
                return "\(date) \(message) — \(author)"
            }
            lines.append(isZh ? "最近提交：" : "Recent commits:")
            lines.append(contentsOf: parts.map { "- \($0)" })
        }

        if !input.issues.isEmpty {
            lines.append(isZh ? "未关闭 Issue：" : "Open issues:")
            lines.append(contentsOf: input.issues.prefix(5).map { "- #\($0.number) \($0.title)" })
        }

        if !input.pulls.isEmpty {
            lines.append(isZh ? "未合并 PR：" : "Open pull requests:")
            lines.append(contentsOf: input.pulls.prefix(5).map { "- #\($0.number) \($0.title)" })
        }

        lines.append("")
        if input.readme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(isZh
                ? "## README 不可用（请基于以上元数据进行分析）"
                : "## README unavailable (analyze based on the metadata above)")
        } else {
            lines.append(isZh ? "## README（截断到 12000 字符）" : "## README (truncated to 12000 characters)")
            lines.append(String(input.readme.prefix(12000)))
        }

        return lines.joined(separator: "\n")
    }
}
