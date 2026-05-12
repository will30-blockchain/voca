import Foundation

public enum LLMProviderFactory {
    public static func make(
        id: LLMProviderID,
        credentials: ProviderCredentials,
        session: URLSession
    ) -> LLMProvider {
        switch id {
        case .groq:
            return GroqLLMProvider(apiKey: credentials.groqAPIKey, session: session)
        case .openai:
            return OpenAILLMProvider(apiKey: credentials.openaiAPIKey, session: session)
        case .anthropic:
            return AnthropicProvider(apiKey: credentials.anthropicAPIKey, session: session)
        case .disabled:
            return DisabledLLMProvider()
        }
    }
}

struct DisabledLLMProvider: LLMProvider {
    let id: LLMProviderID = .disabled
    func complete(_ request: LLMRequest, model _: String) async throws -> LLMResult {
        // Return the last user message verbatim — equivalent to "no refinement".
        let text = request.messages.last(where: { $0.role == .user })?.content ?? ""
        return LLMResult(text: text)
    }
}
