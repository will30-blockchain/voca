import Foundation

/// OpenAI-compatible Chat Completions client used by both OpenAI and Groq.
enum OpenAICompatibleClient {
    struct ChatRequest: Encodable {
        struct Message: Encodable { let role: String; let content: String }
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int?
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { let content: String? }
            let message: Msg
        }
        let choices: [Choice]
    }

    static func chat(
        endpoint: URL,
        apiKey: String,
        model: String,
        request: LLMRequest,
        session: URLSession
    ) async throws -> LLMResult {
        let body = ChatRequest(
            model: model,
            messages: request.messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            temperature: request.temperature,
            max_tokens: request.maxTokens
        )
        let payload = try JSONEncoder().encode(body)

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.http(status: -1, body: "no response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            let text = decoded.choices.first?.message.content ?? ""
            return LLMResult(text: text)
        } catch {
            throw LLMError.decoding(error.localizedDescription)
        }
    }
}
