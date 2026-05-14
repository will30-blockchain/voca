import Foundation

public struct DeepgramProvider: STTProvider {
    public let id: STTProviderID = .deepgram

    private let apiKey: String
    private let session: URLSession
    private let endpoint: URL

    public init(
        apiKey: String,
        session: URLSession,
        endpoint: URL = URL(string: "https://api.deepgram.com/v1/listen")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.endpoint = endpoint
    }

    public func transcribe(_ request: STTRequest, model: String) async throws -> STTResult {
        guard !apiKey.isEmpty else { throw STTError.missingAPIKey(provider: "Deepgram") }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "model", value: model.isEmpty ? "nova-2" : model),
            URLQueryItem(name: "punctuate", value: "true"),
            URLQueryItem(name: "smart_format", value: "true")
        ]
        if request.language != "auto" && !request.language.isEmpty {
            queryItems.append(URLQueryItem(name: "language", value: request.language))
        } else {
            queryItems.append(URLQueryItem(name: "detect_language", value: "true"))
        }
        if let prompt = request.prompt, !prompt.isEmpty {
            // Deepgram supports keyword biasing via "keywords" — best-effort split.
            for word in prompt.split(separator: ",").prefix(50) {
                let trimmed = word.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    queryItems.append(URLQueryItem(name: "keywords", value: trimmed))
                }
            }
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw STTError.unsupported("Could not build Deepgram request URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue(request.mimeType, forHTTPHeaderField: "Content-Type")
        req.httpBody = request.audio

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw STTError.http(status: -1, body: "no response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw STTError.http(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        struct Response: Decodable {
            struct Results: Decodable {
                struct Channel: Decodable {
                    struct Alt: Decodable { let transcript: String }
                    let alternatives: [Alt]
                    let detected_language: String?
                }
                let channels: [Channel]
            }
            let results: Results
        }
        do {
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            let transcript = decoded.results.channels.first?.alternatives.first?.transcript ?? ""
            let lang = decoded.results.channels.first?.detected_language
            return STTResult(text: transcript, detectedLanguage: lang)
        } catch {
            throw STTError.decoding(error.localizedDescription)
        }
    }
}
