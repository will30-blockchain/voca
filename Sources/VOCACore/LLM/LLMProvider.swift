import Foundation

public struct LLMMessage: Sendable, Equatable {
    public enum Role: String, Sendable { case system, user, assistant }
    public let role: Role
    public let content: String
    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

public struct LLMRequest: Sendable {
    public let messages: [LLMMessage]
    public let temperature: Double
    public let maxTokens: Int?
    public init(messages: [LLMMessage], temperature: Double = 0.2, maxTokens: Int? = 1024) {
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

public struct LLMResult: Sendable {
    public let text: String
    public init(text: String) { self.text = text }
}

public protocol LLMProvider: Sendable {
    var id: LLMProviderID { get }
    func complete(_ request: LLMRequest, model: String) async throws -> LLMResult
}

public enum LLMError: LocalizedError {
    case missingAPIKey(provider: String)
    case http(status: Int, body: String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p): return "Missing API key for \(p). Open Settings → Providers to add it."
        case .http(let s, let b): return "LLM HTTP \(s): \(b)"
        case .decoding(let m): return "Could not decode LLM response: \(m)"
        }
    }
}
