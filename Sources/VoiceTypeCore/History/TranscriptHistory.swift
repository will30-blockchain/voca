import Foundation
import Combine

/// Rolling history of the last N dictations, persisted to disk so it survives
/// relaunches. Backs the Dashboard recent-activity list.
@MainActor
public final class TranscriptHistory: ObservableObject {
    public struct Entry: Codable, Sendable, Hashable, Identifiable {
        public var id: UUID
        public var date: Date
        public var mode: String       // "transcribe" | "translate"
        public var text: String
        public init(id: UUID = UUID(), date: Date = Date(), mode: String, text: String) {
            self.id = id
            self.date = date
            self.mode = mode
            self.text = text
        }
    }

    @Published public private(set) var entries: [Entry]

    private let url: URL
    private let limit = 50

    public init() {
        let fm = FileManager.default
        let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = (support ?? URL(fileURLWithPath: NSTemporaryDirectory())).appendingPathComponent("VoiceType", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        self.url = dir.appendingPathComponent("history.json")
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            self.entries = decoded
        } else {
            self.entries = []
        }
    }

    public func append(mode: DictationMode, text: String) {
        let modeString = mode == .translate ? "translate" : "transcribe"
        let entry = Entry(mode: modeString, text: text)
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
        }
        save()
    }

    public func clear() {
        entries = []
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.engine.error("Failed to persist history: \(String(describing: error), privacy: .public)")
        }
    }

    public var storagePath: URL { url }
}
