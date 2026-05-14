import Foundation

/// Lightweight, file-backed personal memory. Stores:
///  - Recent transcript samples (capped) for adaptive style hints.
///  - Promoted phrases that the user has spoken often (frequency table).
///  - Free-form personal facts the user can edit.
@MainActor
public final class PersonalMemory: ObservableObject {
    public struct Snapshot: Codable, Sendable, Equatable {
        public var phraseCounts: [String: Int]
        public var recentSamples: [String]
        public var personalFacts: String
        public var totalDictations: Int

        public init(
            phraseCounts: [String: Int] = [:],
            recentSamples: [String] = [],
            personalFacts: String = "",
            totalDictations: Int = 0
        ) {
            self.phraseCounts = phraseCounts
            self.recentSamples = recentSamples
            self.personalFacts = personalFacts
            self.totalDictations = totalDictations
        }
    }

    @Published public private(set) var snapshot: Snapshot
    private let url: URL
    private let maxSamples = 30
    private let maxTrackedPhrases = 400

    public init() {
        self.url = SupportDirectory.file("memory.json")

        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            self.snapshot = decoded
        } else {
            self.snapshot = Snapshot()
        }
    }

    /// Top N high-frequency phrases (by raw count), for use as LLM context.
    public func topPhrases(limit: Int = 20) -> [String] {
        snapshot.phraseCounts
            .filter { $0.value >= 2 }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }

    public func setPersonalFacts(_ facts: String) {
        var s = snapshot
        s.personalFacts = facts
        snapshot = s
        save()
    }

    /// Ingest a finalised transcript: tally meaningful tokens, store a recent sample.
    public func ingest(transcript: String) {
        guard !transcript.isEmpty else { return }
        var s = snapshot

        s.totalDictations += 1

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            s.recentSamples.insert(trimmed, at: 0)
            if s.recentSamples.count > maxSamples {
                s.recentSamples = Array(s.recentSamples.prefix(maxSamples))
            }
        }

        for token in Self.candidatePhrases(in: trimmed) {
            s.phraseCounts[token, default: 0] += 1
        }
        if s.phraseCounts.count > maxTrackedPhrases {
            // Evict the lowest-count entries to keep the table bounded.
            let kept = s.phraseCounts.sorted { $0.value > $1.value }.prefix(maxTrackedPhrases)
            s.phraseCounts = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
        }

        snapshot = s
        save()
    }

    public func reset() {
        snapshot = Snapshot()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try SupportDirectory.writeSecurely(data, to: url)
        } catch {
            AppLog.memory.error("Failed to persist memory: \(String(describing: error), privacy: .public)")
        }
    }

    /// Heuristic: collect capitalised words and 2-3 word phrases that look like
    /// proper nouns / domain terms. Cheap, deterministic, language-agnostic for
    /// Latin scripts; CJK falls back to single tokens of length >= 2.
    public nonisolated static func candidatePhrases(in text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        var results: [String] = []

        let words = text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        // Capitalised single tokens (English-style proper nouns).
        for word in words where word.count >= 3 && word.first?.isUppercase == true {
            results.append(word)
        }

        // Capitalised bigrams.
        for i in 0..<max(0, words.count - 1) {
            let a = words[i], b = words[i + 1]
            if a.first?.isUppercase == true && b.first?.isUppercase == true && a.count + b.count >= 5 {
                results.append("\(a) \(b)")
            }
        }

        // CJK substrings of length 2..4 (very rough but useful as fallback).
        for run in cjkRuns(in: text) where run.count >= 2 && run.count <= 6 {
            results.append(run)
        }

        return results
    }

    private nonisolated static func cjkRuns(in text: String) -> [String] {
        var runs: [String] = []
        var current = ""
        for scalar in text.unicodeScalars {
            let v = scalar.value
            let isCJK = (0x4E00...0x9FFF).contains(v) || (0x3040...0x30FF).contains(v) || (0xAC00...0xD7AF).contains(v)
            if isCJK {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                runs.append(current); current = ""
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
    }

    public var storagePath: URL { url }
}
