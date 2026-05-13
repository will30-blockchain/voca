import Foundation
import Combine

/// In-app event log — distinct from `os.Logger` (which goes to Console.app).
/// Backs the Logs tab in Settings so the user can inspect what the engine
/// is doing without launching Console. File-backed JSONL at
/// ~/Library/Application Support/VoiceType/log.jsonl, capped at 500 entries.
@MainActor
public final class LogStore: ObservableObject {
    public enum Level: String, Codable, Sendable, CaseIterable {
        case info, warning, error

        public var sortKey: Int {
            switch self { case .info: return 0; case .warning: return 1; case .error: return 2 }
        }
    }

    public enum Category: String, Codable, Sendable, CaseIterable {
        case audio, hotkey, stt, llm, filter, inject, memory, engine, permissions, app

        public var displayName: String {
            switch self {
            case .audio: return "Audio"
            case .hotkey: return "Hotkey"
            case .stt: return "Transcribe"
            case .llm: return "LLM"
            case .filter: return "Filter"
            case .inject: return "Inject"
            case .memory: return "Memory"
            case .engine: return "Engine"
            case .permissions: return "Permissions"
            case .app: return "App"
            }
        }
    }

    public struct Entry: Codable, Sendable, Identifiable, Equatable {
        public var id: UUID
        public var date: Date
        public var level: Level
        public var category: Category
        public var message: String
        /// Free-form key/value metadata — surfaced in the detail row.
        public var detail: [String: String]

        public init(
            id: UUID = UUID(),
            date: Date = Date(),
            level: Level,
            category: Category,
            message: String,
            detail: [String: String] = [:]
        ) {
            self.id = id
            self.date = date
            self.level = level
            self.category = category
            self.message = message
            self.detail = detail
        }
    }

    @Published public private(set) var entries: [Entry] = []

    private let url: URL
    private let limit = 500
    private let queue = DispatchQueue(label: "com.voicetype.logstore", qos: .utility)

    public init() {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (support ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("VoiceType", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.url = dir.appendingPathComponent("log.jsonl")

        self.entries = Self.loadFromDisk(url: url, limit: limit)
    }

    // MARK: - Public API

    public func info(_ category: Category, _ message: String, detail: [String: String] = [:]) {
        append(Entry(level: .info, category: category, message: message, detail: detail))
    }

    public func warning(_ category: Category, _ message: String, detail: [String: String] = [:]) {
        append(Entry(level: .warning, category: category, message: message, detail: detail))
    }

    public func error(_ category: Category, _ message: String, detail: [String: String] = [:]) {
        append(Entry(level: .error, category: category, message: message, detail: detail))
    }

    public func clear() {
        entries = []
        queue.async { [url] in
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Render the current log as a plain-text dump suitable for clipboard /
    /// pasting into an issue.
    public func plainText() -> String {
        let formatter = ISO8601DateFormatter()
        return entries.reversed().map { e in
            var line = "[\(formatter.string(from: e.date))] [\(e.level.rawValue.uppercased())] [\(e.category.displayName)] \(e.message)"
            if !e.detail.isEmpty {
                let pairs = e.detail.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                line += " (\(pairs))"
            }
            return line
        }.joined(separator: "\n")
    }

    public var storagePath: URL { url }

    // MARK: - Internals

    private func append(_ entry: Entry) {
        // Newest first for the on-screen table; cap to `limit`.
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
        }
        queue.async { [url, entry] in
            guard let data = try? JSONEncoder().encode(entry) else { return }
            var line = data
            line.append(0x0A) // newline
            let handle: FileHandle
            if FileManager.default.fileExists(atPath: url.path) {
                guard let h = try? FileHandle(forWritingTo: url) else { return }
                handle = h
                _ = try? handle.seekToEnd()
            } else {
                FileManager.default.createFile(atPath: url.path, contents: nil)
                guard let h = try? FileHandle(forWritingTo: url) else { return }
                handle = h
            }
            try? handle.write(contentsOf: line)
            try? handle.close()
        }
    }

    private static func loadFromDisk(url: URL, limit: Int) -> [Entry] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        var out: [Entry] = []
        for slice in data.split(separator: 0x0A) where !slice.isEmpty {
            if let entry = try? decoder.decode(Entry.self, from: Data(slice)) {
                out.append(entry)
            }
        }
        // File grows append-only. Newest-first for UI; cap to limit.
        let trimmed = Array(out.suffix(limit).reversed())
        return trimmed
    }
}
