import Foundation

public struct OpenAIWhisperProvider: STTProvider {
    public let id: STTProviderID = .openaiWhisper

    private let apiKey: String
    private let session: URLSession
    private let endpoint: URL

    public init(
        apiKey: String,
        session: URLSession,
        endpoint: URL = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    public func transcribe(_ request: STTRequest, model: String) async throws -> STTResult {
        guard !apiKey.isEmpty else { throw STTError.missingAPIKey(provider: "OpenAI") }
        try EndpointValidator.validate(endpoint)

        var body = MultipartBody()
        body.appendFile(name: "file", filename: request.filename, mimeType: request.mimeType, fileData: request.audio)
        body.appendField("model", model.isEmpty ? "whisper-1" : model)
        body.appendField("response_format", "verbose_json")
        body.appendField("temperature", "0")
        if request.language != "auto" && !request.language.isEmpty {
            body.appendField("language", request.language)
        }
        if let prompt = STTBias.whisperPrompt(terms: request.biasTerms) {
            body.appendField("prompt", prompt)
        }
        let payload = body.finalize()

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue(body.contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = payload

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw STTError.http(provider: "OpenAI", status: -1, body: "no response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw STTError.fromHTTP(provider: "OpenAI", response: http, data: data)
        }

        struct Response: Decodable { let text: String; let language: String? }
        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            return STTResult(text: decoded.text, detectedLanguage: decoded.language)
        } catch {
            throw STTError.decoding(error.localizedDescription)
        }
    }
}
