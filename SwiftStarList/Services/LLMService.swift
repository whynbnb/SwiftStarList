import Foundation

actor LLMService {
    private let network = NetworkManager.shared

    func analyzeStream(repo: StarredRepo, readme: String, settings: AppSettings, onChunk: @escaping (String) -> Void) async throws -> String {
        let s = L.s
        let prompt: String
        let systemMessage: String

        let isZh = AppLanguage.resolve(settings.language) == .zh

        if isZh {
            prompt = """
            请分析以下GitHub仓库并提供总结：

            仓库名称：\(repo.fullName)
            描述：\(repo.description ?? "无")
            主要语言：\(repo.language ?? "未知")
            Star数：\(repo.stargazersCount)
            Topics：\(repo.topics.joined(separator: ", "))

            README内容：
            \(readme.prefix(8000))

            请从以下几个方面进行分析：
            1. 项目简介（一句话概括）
            2. 核心功能
            3. 技术栈
            4. 适用场景
            5. 活跃度评估
            """
            systemMessage = "你是一个专业的GitHub仓库分析助手，请用中文简洁地分析仓库。"
        } else {
            prompt = """
            Please analyze the following GitHub repository and provide a summary:

            Repository: \(repo.fullName)
            Description: \(repo.description ?? "None")
            Language: \(repo.language ?? "Unknown")
            Stars: \(repo.stargazersCount)
            Topics: \(repo.topics.joined(separator: ", "))

            README content:
            \(readme.prefix(8000))

            Please analyze from the following aspects:
            1. Brief summary (one sentence)
            2. Core features
            3. Tech stack
            4. Use cases
            5. Activity assessment
            """
            systemMessage = "You are a professional GitHub repository analysis assistant. Provide concise analysis in English."
        }

        let request = ChatCompletionRequest(
            model: settings.llmConfig.model,
            messages: [
                ChatMessage(role: "system", content: systemMessage),
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.3,
            stream: true
        )

        let baseURL = settings.llmConfig.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !baseURL.isEmpty else { throw NetworkError.invalidURL }
        let path = baseURL.hasSuffix("/v1") ? "chat/completions" : "v1/chat/completions"
        guard let url = URL(string: "\(baseURL)/\(path)"), url.scheme != nil else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.llmConfig.apiKey.isEmpty {
            urlRequest.setValue("Bearer \(settings.llmConfig.apiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let session = network.makeSessionForProxy(settings.llmConfig.proxyConfig)
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
}
