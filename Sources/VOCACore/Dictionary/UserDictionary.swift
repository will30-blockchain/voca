import Foundation

/// User-managed glossary of terms (names, acronyms, jargon) used to bias both
/// the STT prompt and the LLM refinement. Persisted to disk as JSON.
@MainActor
public final class UserDictionary: ObservableObject {
    public struct Entry: Codable, Sendable, Hashable, Identifiable {
        public var id: UUID
        public var term: String
        public var note: String

        public init(id: UUID = UUID(), term: String, note: String = "") {
            self.id = id
            self.term = term
            self.note = note
        }
    }

    @Published public private(set) var entries: [Entry]
    private let url: URL

    public init() {
        self.url = SupportDirectory.file("dictionary.json")

        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            self.entries = decoded
        } else {
            self.entries = []
        }
    }

    public func add(_ term: String, note: String = "") {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        if entries.contains(where: { $0.term.caseInsensitiveCompare(t) == .orderedSame }) { return }
        entries.append(Entry(term: t, note: note))
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

    /// Comma-joined list suitable for embedding in an STT bias prompt.
    public func biasPrompt() -> String? {
        guard !entries.isEmpty else { return nil }
        return entries.map { $0.term }.joined(separator: ", ")
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.memory.error("Failed to persist dictionary: \(String(describing: error), privacy: .public)")
        }
    }

    public var storagePath: URL { url }
}
