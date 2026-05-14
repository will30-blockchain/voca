import Foundation

public struct AnthropicProvider: LLMProvider {
    public let id: LLMProviderID = .anthropic

    private let apiKey: String
    private let session: URLSession
    private let endpoint: URL

    public init(
        apiKey: String,
        session: URLSession,
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    public func complete(_ request: LLMRequest, model: String) async throws -> LLMResult {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey(provider: "Anthropic") }

        struct AnthropicMessage: Encodable { let role: String; let content: String }
        struct Body: Encodable {
            let model: String
            let system: String?
            let messages: [AnthropicMessage]
            let temperature: Double
            let max_tokens: Int
        }

        let system = request.messages.first(where: { $0.role == .system })?.content
        let conversational = request.messages
            .filter { $0.role != .system }
            .map { AnthropicMessage(role: $0.role == .assistant ? "assistant" : "user", content: $0.content) }

        let body = Body(
            model: model.isEmpty ? "claude-haiku-4-5-20251001" : model,
            system: system,
            messages: conversational,
            temperature: request.temperature,
            max_tokens: request.maxTokens ?? 1024
        )

        let payload = try JSONEncoder().encode(body)

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = payload

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw LLMError.http(status: -1, body: "no response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        struct Response: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            let text = decoded.content
                .compactMap { $0.type == "text" ? $0.text : nil }
                .joined(separator: "\n")
            return LLMResult(text: text)
        } catch {
            throw LLMError.decoding(error.localizedDescription)
        }
    }
}
