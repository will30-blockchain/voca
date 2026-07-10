import Foundation

/// User-managed glossary of terms (names, acronyms, jargon) used to bias both
/// the STT prompt and the LLM refinement. Persisted to disk as JSON.
@MainActor
public final class UserDictionary: ObservableObject {
    public enum Origin: String, Codable, Sendable, CaseIterable {
        case manual
        case autoLearned = "auto_learned"
    }

    public struct Entry: Codable, Sendable, Hashable, Identifiable {
        public var id: UUID
        public var term: String
        public var note: String
        public var source: Origin

        public init(id: UUID = UUID(), term: String, note: String = "", source: Origin = .manual) {
            self.id = id
            self.term = term
            self.note = note
            self.source = source
        }

        private enum CodingKeys: String, CodingKey {
            case id, term, note, source
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try c.decode(UUID.self, forKey: .id)
            self.term = try c.decode(String.self, forKey: .term)
            self.note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""

            // Source resolution falls back to note-prefix inference when:
            //  - the field is absent (legacy entries written before `source`
            //    existed), or
            //  - the field is *present but unparseable* (a future version
            //    added a new Origin case the user downgraded from, or the
            //    JSON was hand-edited). We never want a single bad value
            //    here to kill the whole dictionary load.
            let inferred: Origin = self.note.hasPrefix("auto-learned") ? .autoLearned : .manual
            let parsed = try? c.decodeIfPresent(Origin.self, forKey: .source)
            self.source = parsed.flatMap { $0 } ?? inferred
        }
    }

    @Published public private(set) var entries: [Entry]
    private let url: URL

    public init() {
        self.url = SupportDirectory.file("dictionary.json")

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

    public func add(_ term: String, note: String = "", source: Origin = .manual) {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if entries.contains(where: { $0.term.caseInsensitiveCompare(t) == .orderedSame }) { return }
        entries.append(Entry(term: t, note: note, source: source))
        save()
    }

    public func update(_ entry: Entry) {
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
            save()
        }
    }

    public func remove(ids: Set<UUID>) {
        entries.removeAll { ids.contains($0.id) }
        save()
    }

    public func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where index < entries.count {
            entries.remove(at: index)
        }
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try SupportDirectory.writeSecurely(data, to: url)
        } catch {
            AppLog.memory.error("Failed to persist dictionary: \(String(describing: error), privacy: .public)")
        }
    }

    public var storagePath: URL { url }
}
