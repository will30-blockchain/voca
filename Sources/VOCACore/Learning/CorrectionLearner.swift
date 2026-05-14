import Foundation
import Combine

/// Watches the focused text field after a paste. On the next dictation,
/// re-reads that field, diffs against what we pasted, and auto-adds new
/// proper-noun-like tokens to the dictionary. Inspired by Typeless's
/// "I noticed you changed X — added it to your dictionary" loop.
@MainActor
public final class CorrectionLearner: ObservableObject {
    public struct LearnedTerm: Codable, Sendable, Identifiable, Equatable {
        public var id: UUID
        public var term: String
        public var learnedAt: Date
        public var contextHint: String
        public init(id: UUID = UUID(), term: String, learnedAt: Date = Date(), contextHint: String) {
            self.id = id
            self.term = term
            self.learnedAt = learnedAt
            self.contextHint = contextHint
        }
    }

    /// Most recent auto-learned term — toast UI watches this and shows a
    /// brief notification when it changes.
    @Published public private(set) var latest: LearnedTerm?
    @Published public private(set) var recent: [LearnedTerm] = []

    private let dictionary: UserDictionary
    private let memory: PersonalMemory
    private let log: LogStore

    private var pendingSnapshot: AXTextReader.Snapshot?
    private var pendingPasteText: String = ""

    public init(dictionary: UserDictionary, memory: PersonalMemory, log: LogStore) {
        self.dictionary = dictionary
        self.memory = memory
        self.log = log
    }

    /// Called from the engine right after a successful paste. Captures the
    /// focused element so we can re-read it on the next dictation cycle.
    public func recordPaste(_ text: String) {
        guard !text.isEmpty else { return }
        if let snap = AXTextReader.snapshotFocusedField() {
            pendingSnapshot = snap
            pendingPasteText = text
            log.info(.memory, "Captured paste for learning", detail: ["chars": "\(text.count)"])
        } else {
            pendingSnapshot = nil
            log.info(.memory, "Could not snapshot focused field — skipping correction learning")
        }
    }

    /// Triggered at the start of the next dictation (a strong signal the
    /// user is "done" with the previous text). Reads the current value of
    /// the focused element, diffs it, and adds any new proper-noun-like
    /// tokens to the dictionary.
    public func reviewPendingPaste() {
        guard let snap = pendingSnapshot else { return }
        let pasted = pendingPasteText
        pendingSnapshot = nil
        pendingPasteText = ""

        // Stale snapshots (>10 min) are unreliable; the user has likely moved on.
        let age = Date().timeIntervalSince(snap.capturedAt)
        guard age < 600 else {
            log.info(.memory, "Skipped correction review (too old)", detail: ["age_s": "\(Int(age))"])
            return
        }

        guard let current = AXTextReader.currentValue(from: snap) else {
            log.info(.memory, "Skipped correction review (could not re-read element)")
            return
        }

        if current == snap.valueAtPaste {
            // User didn't touch the field. Nothing to learn.
            return
        }

        let report = CorrectionDiff.newCandidates(
            originalPaste: pasted,
            currentText: current,
            existingDictionary: Set(dictionary.entries.map { $0.term }),
            existingMemory: Set(memory.topPhrases(limit: 60))
        )

        guard !report.candidates.isEmpty else {
            log.info(.memory, "Correction review: no new terms", detail: [
                "overlap": String(format: "%.2f", report.overlap)
            ])
            return
        }

        let contextHint = String(pasted.prefix(60))
        for term in report.candidates {
            dictionary.add(term, note: "auto-learned from edit")
            let entry = LearnedTerm(term: term, contextHint: contextHint)
            recent.insert(entry, at: 0)
            latest = entry
            log.info(.memory, "Auto-learned term", detail: [
                "term": term,
                "overlap": String(format: "%.2f", report.overlap)
            ])
        }
        recent = Array(recent.prefix(50))
    }

    /// User dismissed the toast / wants to undo the last auto-learn.
    public func undoLatest() {
        guard let term = latest else { return }
        if let entry = dictionary.entries.first(where: { $0.term == term.term }) {
            dictionary.remove(ids: [entry.id])
        }
        recent.removeAll { $0.id == term.id }
        latest = nil
        log.info(.memory, "Undid auto-learn", detail: ["term": term.term])
    }

    public func clearLatest() {
        latest = nil
    }
}
