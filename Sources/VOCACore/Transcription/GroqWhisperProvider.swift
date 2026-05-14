import Foundation

public struct GroqWhisperProvider: STTProvider {
    public let id: STTProviderID = .groqWhisper

    private let apiKey: String
    private let session: URLSession
    private let endpoint: URL

    public init(
        apiKey: String,
        session: URLSession,
        endpoint: URL = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    public func transcribe(_ request: STTRequest, model: String) async throws -> STTResult {
        guard !apiKey.isEmpty else { throw STTError.missingAPIKey(provider: "Groq") }
        try EndpointValidator.validate(endpoint)

        var body = MultipartBody()
        body.appendFile(name: "file", filename: request.filename, mimeType: request.mimeType, fileData: request.audio)
        body.appendField("model", model.isEmpty ? "whisper-large-v3-turbo" : model)
        body.appendField("response_format", "verbose_json")
        body.appendField("temperature", "0")
        if request.language != "auto" && !request.language.isEmpty {
            body.appendField("language", request.language)
        }
        if let prompt = request.prompt, !prompt.isEmpty {
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
            throw STTError.http(status: -1, body: "no response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw STTError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        do {
            let decoded = try JSONDecoder().decode(WhisperResponse.self, from: data)
            return STTResult(text: decoded.text, detectedLanguage: decoded.language)
        } catch {
            throw STTError.decoding(error.localizedDescription)
        }
    }
}

private struct WhisperResponse: Decodable {
    let text: String
    let language: String?
}
