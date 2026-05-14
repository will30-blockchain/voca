import Foundation

/// Lightweight multipart/form-data builder, used by STT providers.
public struct MultipartBody {
    public let boundary: String
    private var data = Data()

    public init(boundary: String = "vt-" + UUID().uuidString) {
        self.boundary = boundary
    }

    public mutating func appendField(_ name: String, _ value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    public mutating func appendFile(name: String, filename: String, mimeType: String, fileData: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        append("\r\n")
    }

    public mutating func finalize() -> Data {
        append("--\(boundary)--\r\n")
        return data
    }

    public var contentType: String { "multipart/form-data; boundary=\(boundary)" }

    private mutating func append(_ s: String) {
        if let d = s.data(using: .utf8) { data.append(d) }
    }
}
