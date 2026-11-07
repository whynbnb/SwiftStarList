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

/// LLM 结构化分析结果（流式解析时字段可能陆续到达）
struct RepoAnalysis: Codable {
    var summary: String?
    var categories: [String]?
    var coreFeatures: [String]?
    var techStack: [String]?
    var useCases: [String]?
    var activityLevel: String?
    var activityReason: String?
    var audience: String?
    var pros: [String]?
    var cons: [String]?
    var similarProjects: [String]?
    var recommendation: String?

    init(
        summary: String? = nil,
        categories: [String]? = nil,
        coreFeatures: [String]? = nil,
        techStack: [String]? = nil,
        useCases: [String]? = nil,
        activityLevel: String? = nil,
        activityReason: String? = nil,
        audience: String? = nil,
        pros: [String]? = nil,
        cons: [String]? = nil,
        similarProjects: [String]? = nil,
        recommendation: String? = nil
    ) {
        self.summary = summary
        self.categories = categories
        self.coreFeatures = coreFeatures
        self.techStack = techStack
        self.useCases = useCases
        self.activityLevel = activityLevel
        self.activityReason = activityReason
        self.audience = audience
        self.pros = pros
        self.cons = cons
        self.similarProjects = similarProjects
        self.recommendation = recommendation
    }

    var hasContent: Bool {
        summary != nil || categories != nil || coreFeatures != nil || techStack != nil
            || useCases != nil || activityLevel != nil || activityReason != nil
            || audience != nil || pros != nil || cons != nil
            || similarProjects != nil || recommendation != nil
    }

    /// 完整 JSON 解析（要求至少包含 summary）
    static func parse(from text: String) -> RepoAnalysis? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let json = extractJSONObject(from: cleaned),
              let analysis = try? JSONDecoder().decode(RepoAnalysis.self, from: Data(json.utf8)),
              analysis.summary?.isEmpty == false else {
            return nil
        }
        return analysis
    }

    /// 从仍在生成的 JSON 中提取已经完成的字段，用于流式渲染
    static func partial(from text: String) -> RepoAnalysis {
        var analysis = RepoAnalysis()
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")

        guard let start = cleaned.firstIndex(of: "{") else { return analysis }
        cleaned = String(cleaned[start...])

        var index = cleaned.index(after: cleaned.startIndex)
        while index < cleaned.endIndex {
            skipWhitespaceAndCommas(&index, in: cleaned)
            guard index < cleaned.endIndex, cleaned[index] == "\"" else { break }
            guard let key = readString(in: cleaned, from: index) else { break }
            index = key.end

            skipWhitespaceAndCommas(&index, in: cleaned)
            guard index < cleaned.endIndex, cleaned[index] == ":" else { break }
            index = cleaned.index(after: index)
            skipWhitespaceAndCommas(&index, in: cleaned)
            guard index < cleaned.endIndex else { break }

            if cleaned[index] == "\"" {
                guard let value = readString(in: cleaned, from: index) else { break }
                assignString(key.value, value.value, to: &analysis)
                index = value.end
            } else if cleaned[index] == "[" {
                let array = readStringArray(in: cleaned, from: index)
                if !array.values.isEmpty || array.closed {
                    assignArray(key.value, array.values, to: &analysis)
                }
                index = array.end
                if !array.closed { break }
            } else {
                // 目前 schema 没有数字/布尔字段，跳过未知值
                while index < cleaned.endIndex, cleaned[index] != ",", cleaned[index] != "}" {
                    index = cleaned.index(after: index)
                }
                if index < cleaned.endIndex, cleaned[index] == "}" { break }
            }
        }

        return analysis
    }

    private struct StringRead {
        let value: String
        let end: String.Index
    }

    private struct ArrayRead {
        let values: [String]
        let closed: Bool
        let end: String.Index
    }

    private static func readString(in text: String, from start: String.Index) -> StringRead? {
        guard start < text.endIndex, text[start] == "\"" else { return nil }

        var index = text.index(after: start)
        var raw = ""
        var escaped = false

        while index < text.endIndex {
            let character = text[index]
            if escaped {
                raw.append(character)
                escaped = false
            } else if character == "\\" {
                raw.append(character)
                escaped = true
            } else if character == "\"" {
                let json = "\"" + raw + "\""
                guard let data = json.data(using: .utf8),
                      let value = try? JSONDecoder().decode(String.self, from: data) else {
                    return nil
                }
                return StringRead(value: value, end: text.index(after: index))
            } else {
                raw.append(character)
            }
            index = text.index(after: index)
        }

        return nil
    }

    private static func readStringArray(in text: String, from start: String.Index) -> ArrayRead {
        var index = text.index(after: start)
        var values: [String] = []

        while index < text.endIndex {
            skipWhitespaceAndCommas(&index, in: text)
            guard index < text.endIndex else { break }

            if text[index] == "]" {
                return ArrayRead(values: values, closed: true, end: text.index(after: index))
            }
            if text[index] == "\"" {
                guard let value = readString(in: text, from: index) else {
                    return ArrayRead(values: values, closed: false, end: text.endIndex)
                }
                values.append(value.value)
                index = value.end
            } else {
                return ArrayRead(values: values, closed: false, end: index)
            }
        }

        return ArrayRead(values: values, closed: false, end: text.endIndex)
    }

    private static func skipWhitespaceAndCommas(_ index: inout String.Index, in text: String) {
        while index < text.endIndex {
            let character = text[index]
            if character == " " || character == "\n" || character == "\r"
                || character == "\t" || character == "," {
                index = text.index(after: index)
            } else {
                break
            }
        }
    }

    private static func assignString(_ key: String, _ value: String, to analysis: inout RepoAnalysis) {
        switch key {
        case "summary": analysis.summary = value
        case "activityLevel": analysis.activityLevel = value
        case "activityReason": analysis.activityReason = value
        case "audience": analysis.audience = value
        case "recommendation": analysis.recommendation = value
        default: break
        }
    }

    private static func assignArray(_ key: String, _ values: [String], to analysis: inout RepoAnalysis) {
        switch key {
        case "categories": analysis.categories = values
        case "coreFeatures": analysis.coreFeatures = values
        case "techStack": analysis.techStack = values
        case "useCases": analysis.useCases = values
        case "pros": analysis.pros = values
        case "cons": analysis.cons = values
        case "similarProjects": analysis.similarProjects = values
        default: break
        }
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
