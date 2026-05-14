import Foundation

/// Lightweight multipart/form-data builder used by STT providers.
///
/// SECURITY: every header field (`name`, `filename`, `mimeType`) and field
/// `value` is sanitised — CR, LF, NUL, and double-quote characters are
/// stripped before they're written into the body. Without that, an
/// attacker who can influence any of those strings (e.g. via the STT
/// `prompt` field which is populated from the user dictionary, which
/// itself is populated from auto-learning) could inject a fake boundary
/// or smuggle extra parts into the request.
public struct MultipartBody {
    public let boundary: String
    private var data = Data()

    public init(boundary: String = "vt-" + UUID().uuidString) {
        self.boundary = boundary
    }

    public mutating func appendField(_ name: String, _ value: String) {
        let safeName = Self.sanitiseHeader(name)
        let safeValue = Self.sanitiseValue(value)
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(safeName)\"\r\n\r\n")
        append("\(safeValue)\r\n")
    }

    public mutating func appendFile(name: String, filename: String, mimeType: String, fileData: Data) {
        let safeName = Self.sanitiseHeader(name)
        let safeFilename = Self.sanitiseHeader(filename)
        let safeMime = Self.sanitiseHeader(mimeType)
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(safeName)\"; filename=\"\(safeFilename)\"\r\n")
        append("Content-Type: \(safeMime)\r\n\r\n")
        data.append(fileData)
        append("\r\n")
    }

    public mutating func finalize() -> Data {
        append("--\(boundary)--\r\n")
        return data
    }

    public var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    // MARK: - Sanitisation

    /// Strip CR / LF / NUL / double-quote from header components. These are
    /// the only characters that can break out of a header line or out of a
    /// quoted-string value.
    static func sanitiseHeader(_ s: String) -> String {
        s.unicodeScalars.filter { scalar in
            scalar.value != 0x00 && scalar.value != 0x0A && scalar.value != 0x0D && scalar.value != 0x22
        }.reduce(into: "") { $0.unicodeScalars.append($1) }
    }

    /// Field values get CRLF stripped — anything else (including quotes)
    /// is legal inside a multipart body.
    static func sanitiseValue(_ s: String) -> String {
        s.unicodeScalars.filter { scalar in
            scalar.value != 0x00 && scalar.value != 0x0A && scalar.value != 0x0D
        }.reduce(into: "") { $0.unicodeScalars.append($1) }
    }

    private mutating func append(_ s: String) {
        if let d = s.data(using: .utf8) { data.append(d) }
    }
}
