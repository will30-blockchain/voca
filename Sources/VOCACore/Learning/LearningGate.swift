import Foundation

/// Pure confidence-gating logic for auto-learn. A single in-place edit is a
/// weak, noisy signal — the user might be fixing their own typo, editing
/// unrelated text, or the app might have reflowed the paste. Persisting on
/// the FIRST sighting permanently pollutes the glossary (and, for CJK, learns
/// common words on any correction). So we require a candidate to be seen
/// `threshold` times across separate dictations before it graduates to the
/// dictionary.
///
/// No I/O — trivially unit-testable. `CorrectionGate` wraps it with disk
/// persistence.
public struct LearningGate: Codable, Sendable, Equatable {
    public static let defaultThreshold = 2

    /// Upper bound on the pending-counts map. One-off edits that never recur
    /// would otherwise accumulate forever. When exceeded we drop the
    /// least-committed (count == 1) entries, which dominate the map.
    static let maxEntries = 2_000

    /// Pending observation counts, keyed by lowercased term.
    public private(set) var counts: [String: Int]
    public let threshold: Int

    public init(threshold: Int = defaultThreshold, counts: [String: Int] = [:]) {
        self.threshold = max(1, threshold)
        self.counts = counts
    }

    /// Record one observation of `term`. Returns `true` when the term has now
    /// been seen `threshold` times and should be PROMOTED (persisted to the
    /// dictionary). On promotion the pending count is cleared so a later
    /// re-learn starts fresh.
    public mutating func observe(_ term: String) -> Bool {
        let key = term.lowercased()
        let next = (counts[key] ?? 0) + 1
        if next >= threshold {
            counts[key] = nil
            return true
        }
        counts[key] = next
        pruneIfNeeded(keeping: key)
        return false
    }

    /// Keep the map bounded: once over `maxEntries`, evict single-sighting
    /// entries (never the one we just touched). They are the least valuable
    /// and by far the most numerous.
    private mutating func pruneIfNeeded(keeping key: String) {
        guard counts.count > Self.maxEntries else { return }
        for (k, v) in counts where v <= 1 && k != key {
            counts[k] = nil
            if counts.count <= Self.maxEntries { break }
        }
    }

    /// Current pending count for a term (0 if none). For diagnostics/UI.
    public func pendingCount(_ term: String) -> Int {
        counts[term.lowercased()] ?? 0
    }

    /// Drop pending state for a term — e.g. the user removed the learned
    /// entry, so a stray future sighting shouldn't instantly re-promote it.
    public mutating func forget(_ term: String) {
        counts[term.lowercased()] = nil
    }
}

/// Thin disk-persistence wrapper around `LearningGate`, mirroring the
/// `UserDictionary` storage pattern. Kept separate from the pure gate so the
/// decision logic stays testable without touching the filesystem.
@MainActor
public final class CorrectionGate {
    private var gate: LearningGate
    private let url: URL

    // nonisolated so it can serve as a default argument for
    // CorrectionLearner.init (only initializes stored properties).
    public nonisolated init(threshold: Int = LearningGate.defaultThreshold) {
        self.url = SupportDirectory.file("learn_gate.json")
        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode(LearningGate.self, from: data) {
                // Preserve persisted counts but honour the current threshold.
                self.gate = LearningGate(threshold: threshold, counts: decoded.counts)
            } else {
                CorruptFile.quarantine(url)
                self.gate = LearningGate(threshold: threshold)
            }
        } else {
            self.gate = LearningGate(threshold: threshold)
        }
    }

    /// The number of sightings a term needs before it promotes.
    public var threshold: Int { gate.threshold }

    /// See `LearningGate.observe`. Persists the updated counts.
    public func observe(_ term: String) -> Bool {
        let promote = gate.observe(term)
        save()
        return promote
    }

    public func forget(_ term: String) {
        gate.forget(term)
        save()
    }

    public func pendingCount(_ term: String) -> Int { gate.pendingCount(term) }

    private func save() {
        guard let data = try? JSONEncoder().encode(gate) else { return }
        try? SupportDirectory.writeSecurely(data, to: url)
    }
}
