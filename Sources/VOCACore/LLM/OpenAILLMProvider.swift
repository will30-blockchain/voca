import Foundation

public struct OpenAILLMProvider: LLMProvider {
    public let id: LLMProviderID = .openai

    private let apiKey: String
    private let session: URLSession
    private let endpoint: URL

    public init(
        apiKey: String,
        session: URLSession,
        endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    public func complete(_ request: LLMRequest, model: String) async throws -> LLMResult {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey(provider: "OpenAI") }
        try EndpointValidator.validate(endpoint)
        return try await OpenAICompatibleClient.chat(
            endpoint: endpoint,
            apiKey: apiKey,
            model: model.isEmpty ? "gpt-4o-mini" : model,
            request: request,
            session: session
        )
    }
}
