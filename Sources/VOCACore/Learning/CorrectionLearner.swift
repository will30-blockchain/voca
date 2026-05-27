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
    /// Polling task that watches the focused AX field for edits and fires
    /// `reviewPendingPaste()` as soon as the user stops typing — so the
    /// "added to dictionary" toast appears in real time, not on the
    /// *next* dictation. See `startEditWatch(snapshot:)`.
    private var watchTask: Task<Void, Never>?

    public init(dictionary: UserDictionary, memory: PersonalMemory, log: LogStore) {
        self.dictionary = dictionary
        self.memory = memory
        self.log = log
    }

    /// Called from the engine right after a successful paste. Captures the
    /// focused element + kicks off an edit-watcher Task that polls the AX
    /// value and fires `reviewPendingPaste()` as soon as the user stops
    /// editing — so the user gets immediate feedback. `reviewPendingPaste`
    /// is *also* still called on the next dictation as a safety net.
    public func recordPaste(_ text: String) {
        guard !text.isEmpty else { return }
        watchTask?.cancel()
        if let snap = AXTextReader.snapshotFocusedField() {
            pendingSnapshot = snap
            pendingPasteText = text
            log.info(.memory, "Captured paste for learning", detail: ["chars": "\(text.count)"])
            startEditWatch(snapshot: snap)
        } else {
            pendingSnapshot = nil
            log.info(.memory, "Could not snapshot focused field — skipping correction learning")
        }
    }

    /// Watches the focused element for edits and fires `reviewPendingPaste`
    /// when the user stops typing. Cheap polling — 1 Hz AX read for up to
    /// 60 s — is the simpler implementation choice over `AXObserver`
    /// notifications and is plenty for a feature that fires once per
    /// dictation. Cancels itself when:
    ///   - the user starts a new dictation (`recordPaste` cancels + restarts),
    ///   - `reviewPendingPaste` runs through any other path,
    ///   - 60 s elapse without detecting a stable edit, or
    ///   - the AX element becomes unreadable (window closed, focus changed
    ///     into a non-text field, etc.).
    private func startEditWatch(snapshot: AXTextReader.Snapshot) {
        let initial = snapshot.valueAtPaste
        watchTask = Task { [weak self] in
            // Settle delay — the paste may not have landed in the AX tree
            // for a frame or two, and polling immediately is just noise.
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Task.isCancelled { return }

            var lastValue = initial
            var stableCount = 0
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                guard let self else { return }

                guard let current = AXTextReader.currentValue(from: snapshot) else {
                    self.log.info(.memory, "Edit watcher: element no longer readable")
                    return
                }

                if current != lastValue {
                    lastValue = current
                    stableCount = 0
                } else {
                    stableCount += 1
                }

                // 3 consecutive identical polls (≈3 s with no typing) AND
                // the text actually differs from what we pasted — that's
                // our "user finished editing" signal.
                if stableCount >= 3 && current != initial {
                    self.log.info(.memory, "Edit watcher fired", detail: [
                        "chars_initial": "\(initial.count)",
                        "chars_current": "\(current.count)"
                    ])
                    self.reviewPendingPaste()
                    return
                }
            }
            self?.log.info(.memory, "Edit watcher timed out (no stable edit in 60 s)")
        }
    }

    /// Triggered either by the edit-watcher (~3 s after the user stops
    /// typing) or as a safety net at the start of the next dictation.
    /// Reads the current value of the focused element, diffs it, and adds
    /// any new proper-noun-like tokens to the dictionary.
    public func reviewPendingPaste() {
        watchTask?.cancel()
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
            dictionary.add(term, note: "auto-learned from edit", source: .autoLearned)
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

    /// Remove a specific auto-learned entry — also deletes the matching
    /// dictionary row so the term stops biasing future STT/LLM calls.
    public func remove(id: UUID) {
        guard let entry = recent.first(where: { $0.id == id }) else { return }
        if let dictEntry = dictionary.entries.first(where: {
            $0.term.caseInsensitiveCompare(entry.term) == .orderedSame
        }) {
            dictionary.remove(ids: [dictEntry.id])
        }
        recent.removeAll { $0.id == id }
        if latest?.id == id { latest = nil }
        log.info(.memory, "Removed auto-learned term", detail: ["term": entry.term])
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
