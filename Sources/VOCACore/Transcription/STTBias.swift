import Foundation

/// Pure helpers for turning the user's glossary + memory into the bias
/// signal handed to each STT provider. No I/O, no isolation — trivially
/// unit-testable.
///
/// Why this exists (from review of the previous approach):
///   - The old code pre-formatted ONE string — `"Glossary: a, b | c"` — and
///     shoved it into every provider's freeform `prompt`. That was wrong on
///     two providers:
///       • Deepgram comma-splits the prompt into `keywords`, so it ingested
///         the literal `"Glossary: a"` label and the `" | "` joiner as if
///         they were vocabulary terms.
///       • Apple Speech ignores freeform prompts entirely, so bias was a
///         no-op on-device.
///   - It was also UNCAPPED: `UserDictionary` joined every entry, so a large
///     glossary blew past Whisper's ~224-token prompt window. And because the
///     terms sat at the FRONT, Whisper (which attends to the prompt's tail)
///     kept an arbitrary slice of low-priority terms and dropped the rest.
///
/// The fix: providers receive a STRUCTURED, ranked, de-duplicated, capped
/// term list and format it themselves (see each provider). Whisper-family
/// providers additionally place the most important terms LAST.
public enum STTBias {
    /// Default ceiling on how many terms we bias with. Keeps the Whisper
    /// prompt inside its decoder window and Deepgram's keyword list sane.
    public static let defaultLimit = 48

    /// Merge the glossary sources into one ranked, de-duplicated, capped list
    /// — most useful term FIRST. Confidence order:
    ///   1. manual dictionary entries (user curated — highest trust)
    ///   2. memory phrases (already frequency-ranked, ≥ 2 uses)
    ///   3. auto-learned entries (often single-occurrence — least certain)
    /// De-duplication is case-insensitive; the highest-priority spelling of a
    /// term wins and later duplicates are dropped.
    public static func orderedTerms(
        manualTerms: [String],
        memoryPhrases: [String],
        autoLearnedTerms: [String],
        limit: Int = defaultLimit
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for term in manualTerms + memoryPhrases + autoLearnedTerms {
            guard result.count < limit else { break }
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(trimmed)
        }
        return result
    }

    /// Build the freeform prompt for Whisper-family providers (OpenAI, Groq).
    ///
    /// `terms` is most-important-first. Whisper only reliably attends to the
    /// TAIL of the prompt (~224-token decoder window), so we emit the terms
    /// important-LAST and bound the string by characters — for CJK one
    /// character is ≈ one BPE token, so a character budget is a safe proxy
    /// that avoids pulling in a tokenizer. Returns nil when there is nothing
    /// to bias with.
    public static func whisperPrompt(terms: [String], maxChars: Int = 224) -> String? {
        let cleaned = terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return nil }

        // A short natural lead-in (rather than a bare list) reduces the odds
        // of Whisper "prompt bleeding" the terms into the transcript.
        let lead = "Context — proper nouns and terms that may occur: "
        var kept: [String] = []
        var used = lead.count + 1 // + trailing "."
        for term in cleaned { // most-important first — keep the most important that fit
            let cost = term.count + 2 // ", "
            if used + cost > maxChars { break }
            kept.append(term)
            used += cost
        }
        guard !kept.isEmpty else { return nil }

        // Emit important-LAST for Whisper's tail-weighted attention.
        return lead + kept.reversed().joined(separator: ", ") + "."
    }
}
