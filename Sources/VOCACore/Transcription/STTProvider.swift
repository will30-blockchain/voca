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
    case authFailed(provider: String, body: String)
    case regionBlocked(provider: String, body: String)
    case rateLimited(provider: String, retryAfter: String?, body: String)
    case serverError(provider: String, status: Int, body: String)
    case http(provider: String, status: Int, body: String)
    case decoding(String)
    case empty
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p):
            return "Missing API key for \(p). Open Settings → Providers to add it."
        case .authFailed(let p, let b):
            return "\(p) rejected the API key (HTTP 401). Re-check the key in Settings → Providers. Response: \(Self.snippet(b))"
        case .regionBlocked(let p, let b):
            return "\(p) blocked the request from your current IP (HTTP 403 — looks like a region / network restriction). VPN exit nodes are often flagged; try a different exit (US/JP), turn the VPN off, or switch to Groq / Deepgram / Apple Speech in Settings → Providers. Response: \(Self.snippet(b))"
        case .rateLimited(let p, let retry, _):
            if let r = retry, !r.isEmpty {
                return "\(p) rate-limited the request (HTTP 429). Retry after \(r)s."
            }
            return "\(p) rate-limited the request (HTTP 429). Wait a moment and try again."
        case .serverError(let p, let s, let b):
            return "\(p) had a server-side error (HTTP \(s)). Usually temporary — retry, or switch provider. Response: \(Self.snippet(b))"
        case .http(let p, let s, let b):
            return "\(p) transcription failed (HTTP \(s)). Response: \(Self.snippet(b))"
        case .decoding(let m):
            return "Could not decode transcription response: \(m)"
        case .empty:
            return "Recording was empty or too short."
        case .unsupported(let m):
            return "Unsupported: \(m)"
        }
    }

    private static func snippet(_ body: String, max: Int = 400) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "(empty body)" }
        if trimmed.count <= max { return trimmed }
        return String(trimmed.prefix(max)) + "…"
    }

    /// Map an HTTP failure into the most specific STTError we can recognise.
    /// `provider` is the human-facing provider name (e.g. "OpenAI", "Groq", "Deepgram").
    public static func fromHTTP(provider: String, response: HTTPURLResponse, data: Data) -> STTError {
        let body = String(data: data, encoding: .utf8) ?? ""
        let lower = body.lowercased()
        switch response.statusCode {
        case 401:
            return .authFailed(provider: provider, body: body)
        case 403:
            // OpenAI's geo / network block returns:
            //   {"error":{"message":"Access denied. Please check your network settings."}}
            // Cloudflare and similar edges also return 403 with "access denied" / "blocked".
            let regionMarkers = [
                "access denied",
                "check your network",
                "country", "region", "territory",
                "unsupported_country",
                "blocked"
            ]
            if regionMarkers.contains(where: { lower.contains($0) }) {
                return .regionBlocked(provider: provider, body: body)
            }
            return .http(provider: provider, status: 403, body: body)
        case 429:
            let retry = response.value(forHTTPHeaderField: "Retry-After")
            return .rateLimited(provider: provider, retryAfter: retry, body: body)
        case 500..<600:
            return .serverError(provider: provider, status: response.statusCode, body: body)
        default:
            return .http(provider: provider, status: response.statusCode, body: body)
        }
    }
}
