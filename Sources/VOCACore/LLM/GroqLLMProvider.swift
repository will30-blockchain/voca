import Foundation

public struct GroqLLMProvider: LLMProvider {
    public let id: LLMProviderID = .groq

    private let apiKey: String
    private let session: URLSession
    private let endpoint: URL

    public init(
        apiKey: String,
        session: URLSession,
        endpoint: URL = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    public func complete(_ request: LLMRequest, model: String) async throws -> LLMResult {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey(provider: "Groq") }
        return try await OpenAICompatibleClient.chat(
            endpoint: endpoint,
            apiKey: apiKey,
            model: model.isEmpty ? "llama-3.3-70b-versatile" : model,
            request: request,
            session: session
        )
    }
}
