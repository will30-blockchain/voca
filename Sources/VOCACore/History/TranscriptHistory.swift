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
        self.url = SupportDirectory.file("history.json")
        if let data = try? Data(contentsOf: url) {

            if let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
                self.entries = decoded

            } else {
                CorruptFile.quarantine(url)
                self.entries = []

            }

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
            try SupportDirectory.writeSecurely(data, to: url)
        } catch {
            AppLog.engine.error("Failed to persist history: \(String(describing: error), privacy: .public)")
        }
    }

    public var storagePath: URL { url }
}
