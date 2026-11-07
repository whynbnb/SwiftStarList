import Foundation

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let stream: Bool?
}

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatCompletionResponse: Codable {
    let choices: [ChatChoice]
}

struct ChatChoice: Codable {
    let message: ChatMessage
}

struct ChatCompletionStreamResponse: Codable {
    let choices: [ChatStreamChoice]
}

struct ChatStreamChoice: Codable {
    let delta: ChatStreamDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

struct ChatStreamDelta: Codable {
    let content: String?
}

/// 传给 LLM 的仓库上下文
struct RepoAnalysisInput {
    let repo: StarredRepo
    let details: RepoDetails?
    let readme: String
    let languages: [String: Int]
    let contributors: [RepoContributor]
    let releases: [RepoRelease]
    let commits: [RepoCommit]
    let issues: [RepoIssue]
    let pulls: [RepoPullRequest]
    let license: RepoLicense?
}

/// LLM 结构化分析结果
struct RepoAnalysis: Codable {
    let summary: String
    let categories: [String]?
    let coreFeatures: [String]?
    let techStack: [String]?
    let useCases: [String]?
    let activityLevel: String?
    let activityReason: String?
    let audience: String?
    let pros: [String]?
    let cons: [String]?
    let similarProjects: [String]?
    let recommendation: String?

    /// 兼容模型偶尔输出的 ```json 代码块或前后说明文字
    static func parse(from text: String) -> RepoAnalysis? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let json = extractJSONObject(from: cleaned) else { return nil }
        return try? JSONDecoder().decode(RepoAnalysis.self, from: Data(json.utf8))
    }

    /// 找到第一个完整、括号平衡的 JSON 对象，忽略前后的说明文字
    private static func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]

            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(text[start...index])
                    }
                }
            }

            index = text.index(after: index)
        }

        return nil
    }
}
