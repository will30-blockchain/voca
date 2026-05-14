import Foundation

/// Validates that a provider endpoint URL is HTTPS and points at a known
/// host. Used at request time so a future code path that lets the
/// endpoint be configured (plugin, test harness, malformed import) can't
/// silently route API keys to an attacker-controlled server.
enum EndpointValidator {
    /// Allowed host prefixes per provider family. A request whose URL
    /// host doesn't match any of these is rejected outright.
    static let allowedHosts: Set<String> = [
        "api.groq.com",
        "api.openai.com",
        "api.deepgram.com",
        "api.anthropic.com"
    ]

    enum ValidationError: LocalizedError {
        case insecureScheme(String)
        case hostNotAllowed(String)

        var errorDescription: String? {
            switch self {
            case .insecureScheme(let s): return "Provider endpoint must use HTTPS (got \(s))."
            case .hostNotAllowed(let h): return "Provider host \"\(h)\" is not in the allowlist."
            }
        }
    }

    static func validate(_ url: URL) throws {
        if (url.scheme ?? "").lowercased() != "https" {
            throw ValidationError.insecureScheme(url.scheme ?? "(none)")
        }
        guard let host = url.host, allowedHosts.contains(host) else {
            throw ValidationError.hostNotAllowed(url.host ?? "(no host)")
        }
    }
}
