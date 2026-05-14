import Foundation

public struct STTRequest: Sendable {
    /// Audio data, encoded as a WAV blob unless otherwise stated.
    public let audio: Data
    /// Sample rate of the encoded audio.
    public let sampleRate: Double
    /// MIME type (default: audio/wav).
    public let mimeType: String
    /// Suggested filename for multipart upload.
    public let filename: String
    /// Language hint or "auto".
    public let language: String
    /// Optional prompt to bias transcription (used for glossary).
    public let prompt: String?

    public init(
        audio: Data,
        sampleRate: Double,
        mimeType: String = "audio/wav",
        filename: String = "audio.wav",
        language: String = "auto",
        prompt: String? = nil
    ) {
        self.audio = audio
        self.sampleRate = sampleRate
        self.mimeType = mimeType
        self.filename = filename
        self.language = language
        self.prompt = prompt
    }
}

public struct STTResult: Sendable, Equatable {
    public let text: String
    public let detectedLanguage: String?

    public init(text: String, detectedLanguage: String? = nil) {
        self.text = text
        self.detectedLanguage = detectedLanguage
    }
}

public protocol STTProvider: Sendable {
    var id: STTProviderID { get }
    func transcribe(_ request: STTRequest, model: String) async throws -> STTResult
}

public enum STTError: LocalizedError {
    case missingAPIKey(provider: String)
    case http(status: Int, body: String)
    case decoding(String)
    case empty
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p): return "Missing API key for \(p). Open Settings → Providers to add it."
        case .http(let s, let b): return "Transcription HTTP \(s): \(b)"
        case .decoding(let m): return "Could not decode transcription response: \(m)"
        case .empty: return "Recording was empty or too short."
        case .unsupported(let m): return "Unsupported: \(m)"
        }
    }
}
