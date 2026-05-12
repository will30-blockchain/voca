import Foundation

public enum STTProviderFactory {
    public static func make(
        id: STTProviderID,
        credentials: ProviderCredentials,
        session: URLSession
    ) -> STTProvider {
        switch id {
        case .groqWhisper:
            return GroqWhisperProvider(apiKey: credentials.groqAPIKey, session: session)
        case .openaiWhisper:
            return OpenAIWhisperProvider(apiKey: credentials.openaiAPIKey, session: session)
        case .deepgram:
            return DeepgramProvider(apiKey: credentials.deepgramAPIKey, session: session)
        case .appleSpeech:
            return AppleSpeechProvider()
        }
    }
}
