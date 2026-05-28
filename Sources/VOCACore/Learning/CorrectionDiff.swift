import Foundation
import NaturalLanguage

/// Pure logic for "what did the user change after we pasted?" — used by
/// CorrectionLearner to extract proper-noun-like edits and add them to
/// the dictionary. No I/O, no isolation; trivially testable.
public enum CorrectionDiff {
    public struct Report: Sendable, Equatable {
        public let candidates: [String]
        public let overlap: Double
        public init(candidates: [String], overlap: Double) {
            self.candidates = candidates
            self.overlap = overlap
        }
    }

    /// Finds proper-noun-like tokens present in `currentText` but not in
    /// `originalPaste`. Returns an empty list when:
    ///   - the LCS overlap is too low (the user likely focused a different
    ///     field, so a diff would be garbage), or
    ///   - the candidate list explodes past `maxAdds` (defensive cap), or
    ///   - the user simply didn't edit.
    ///
    /// Runs TWO diff passes:
    ///   - Word-level LCS: catches whole-token edits well, especially for
    ///     space-separated languages like English.
    ///   - CJK character-level diff: required because Chinese text
    ///     tokenises as one giant CJK run — any single-character edit
    ///     would make the entire token "different" at the word level and
    ///     we'd never learn from it. This pass identifies edited character
    ///     spans and expands them outward to capture the surrounding word.
    public static func newCandidates(
        originalPaste: String,
        currentText: String,
        existingDictionary: Set<String>,
        existingMemory: Set<String> = [],
        maxAdds: Int = 8
    ) -> Report {
        let original = tokenize(originalPaste)
        let current = tokenize(currentText)

        guard !original.isEmpty else { return Report(candidates: [], overlap: 0) }
        guard !current.isEmpty else { return Report(candidates: [], overlap: 0) }

        let (lcsLen, added) = lcsDiff(original, current)
        let overlap = Double(lcsLen) / Double(original.count)

        let dictLowercased = Set(existingDictionary.map { $0.lowercased() })
        let memLowercased = Set(existingMemory.map { $0.lowercased() })

        var seen = Set<String>()
        var result: [String] = []

        // Pass 1: word-level. Below 0.4 overlap the word diff is unreliable
        // (likely a different field) — but CJK char-level still runs, since
        // a Chinese edit naturally produces 0 word overlap.
        if overlap >= 0.4 {
            for token in added {
                guard result.count < maxAdds else { break }
                let key = token.lowercased()
                if seen.contains(key) { continue }
                guard isCandidateTerm(token, existingDict: dictLowercased, existingMemory: memLowercased) else { continue }
                seen.insert(key)
                result.append(token)
            }
        }

        // Pass 2: CJK character-level supplement. Catches edits like:
        //   「資訊」→「資料」    (one char changed in a 2-char word)
        //   「宜灣」→「台灣」    (both chars changed)
        //   「陳一文」→「陳依文」 (one char changed in a 3-char proper noun)
        if result.count < maxAdds {
            let extras = cjkCharacterLevelCandidates(
                original: originalPaste,
                current: currentText,
                existingDict: dictLowercased,
                existingMemory: memLowercased,
                maxAdds: maxAdds - result.count
            )
            for term in extras {
                if result.count >= maxAdds { break }
                let key = term.lowercased()
                if seen.contains(key) { continue }
                seen.insert(key)
                result.append(term)
            }
        }

        // If we'd add a *ton* of things, the diff is suspect — drop everything.
        if result.count >= maxAdds {
            return Report(candidates: [], overlap: overlap)
        }
        return Report(candidates: result, overlap: overlap)
    }

    // MARK: - CJK character-level diff

    /// Identifies CJK words in `current` that contain at least one edited
    /// character relative to `original`. Required because Chinese /
    /// Japanese / Korean don't use spaces, so a small word edit looks
    /// like a giant token replacement to the word-level LCS pass.
    ///
    /// Two-pass strategy:
    ///   1. PRIMARY — character-level LCS finds changed positions;
    ///      `NLTokenizer` (with dominant-language hint) segments
    ///      `current` into proper words; any 2+ char pure-CJK word that
    ///      overlaps the changed set is a candidate. Catches the common
    ///      case "X X 資訊 X X" → "X X 資料 X X" → learn 「資料」.
    ///   2. FALLBACK — if NLTokenizer over-segments (it often splits
    ///      proper nouns into single chars), expand each changed CJK
    ///      position outward by one char on each side. Tight cap of
    ///      3 chars total per window keeps noise low while still
    ///      capturing 2-3 char names like 「陳依文」 or 「依文」.
    ///
    /// Conservative guards on both passes:
    ///   - Bails on inputs > 2,000 chars (DP would get expensive and a
    ///     paste that long was probably a doc dump, not a dictation).
    ///   - Bails when more than 50% of `current` characters differ —
    ///     that's a rewrite, not a correction.
    ///   - Words mixing CJK with Latin are skipped (the word-level pass
    ///     handles Latin).
    static func cjkCharacterLevelCandidates(
        original: String,
        current: String,
        existingDict: Set<String>,
        existingMemory: Set<String>,
        maxAdds: Int
    ) -> [String] {
        let orig = Array(original)
        let curr = Array(current)
        guard !orig.isEmpty, !curr.isEmpty else { return [] }
        guard orig.count <= 2_000, curr.count <= 2_000 else { return [] }

        let changedIdxs = changedPositionsInCurrent(orig: orig, curr: curr)
        guard !changedIdxs.isEmpty else { return [] }

        let changeRatio = Double(changedIdxs.count) / Double(curr.count)
        guard changeRatio < 0.5 else { return [] }

        let changedSet = Set(changedIdxs)

        // PRIMARY pass: NLTokenizer word-aligned candidates.
        let tokenizer = NLTokenizer(unit: .word)
        if let lang = NLLanguageRecognizer.dominantLanguage(for: current) {
            tokenizer.setLanguage(lang)
        }
        tokenizer.string = current

        var seen = Set<String>()
        var candidates: [String] = []
        tokenizer.enumerateTokens(in: current.startIndex..<current.endIndex) { range, _ in
            if candidates.count >= maxAdds { return false }

            let word = String(current[range])
            guard word.count >= 2 else { return true }
            guard word.allSatisfy({ isCJKChar($0) }) else { return true }

            let lower = word.lowercased()
            if existingDict.contains(lower) { return true }
            if existingMemory.contains(lower) { return true }
            if seen.contains(lower) { return true }

            // Char-position range of this NLTokenizer word in `current`.
            let startIdx = current.distance(from: current.startIndex, to: range.lowerBound)
            let endIdx = current.distance(from: current.startIndex, to: range.upperBound)
            let overlapsChange = (startIdx..<endIdx).contains(where: { changedSet.contains($0) })
            guard overlapsChange else { return true }

            seen.insert(lower)
            candidates.append(word)
            return true
        }

        if !candidates.isEmpty { return candidates }

        // FALLBACK pass: NLTokenizer over-segmented (often happens with
        // proper nouns like person names). Expand around each changed
        // CJK position to capture a 2-3 char window.
        var spansSeen = Set<Range<Int>>()
        for idx in changedIdxs {
            if candidates.count >= maxAdds { break }
            guard idx < curr.count, isCJKChar(curr[idx]) else { continue }

            var start = idx
            var end = idx + 1
            if start > 0, isCJKChar(curr[start - 1]) { start -= 1 }
            if end < curr.count, isCJKChar(curr[end]) { end += 1 }

            // Need at least 2 CJK chars; if only the centre is CJK and
            // both neighbours are non-CJK, skip.
            guard (end - start) >= 2 else { continue }

            let range = start..<end
            if spansSeen.contains(range) { continue }
            spansSeen.insert(range)

            let word = String(curr[start..<end])
            let lower = word.lowercased()
            if existingDict.contains(lower) || existingMemory.contains(lower) { continue }
            if seen.contains(lower) { continue }
            seen.insert(lower)
            candidates.append(word)
        }
        return candidates
    }

    /// Standard LCS-DP backtrack, returning the indices in `curr` that
    /// are NOT part of the longest common subsequence (i.e. the positions
    /// the user inserted or substituted).
    static func changedPositionsInCurrent(orig: [Character], curr: [Character]) -> [Int] {
        let m = orig.count
        let n = curr.count
        if m == 0 { return Array(0..<n) }
        if n == 0 { return [] }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if orig[i - 1] == curr[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        var i = m, j = n
        var matched = Set<Int>()
        while i > 0, j > 0 {
            if orig[i - 1] == curr[j - 1] {
                matched.insert(j - 1)
                i -= 1; j -= 1
            } else if dp[i - 1][j] >= dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }

        var result: [Int] = []
        result.reserveCapacity(n - matched.count)
        for k in 0..<n where !matched.contains(k) {
            result.append(k)
        }
        return result
    }

    private static func isCJKChar(_ c: Character) -> Bool {
        for scalar in c.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v) ||
               (0x3040...0x30FF).contains(v) ||
               (0xAC00...0xD7AF).contains(v) {
                return true
            }
        }
        return false
    }

    // MARK: - Tokenisation

    static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for scalar in text.unicodeScalars {
            if isWordScalar(scalar) {
                current.unicodeScalars.append(scalar)
            } else {
                if !current.isEmpty { tokens.append(current); current.removeAll() }
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func isWordScalar(_ s: Unicode.Scalar) -> Bool {
        // Letters, numbers, and word-internal punctuation (apostrophe, hyphen,
        // underscore). CJK scalars are letters per Unicode.
        if let charScalar = Character(s).unicodeScalars.first,
           Character(charScalar).isLetter || Character(charScalar).isNumber {
            return true
        }
        switch s.value {
        case 0x27, 0x2D, 0x5F: return true // ' - _
        default: return false
        }
    }

    // MARK: - LCS diff

    /// Returns (LCS length, tokens added in `b` relative to `a`). Case-insensitive
    /// comparison so "Claude" matches "claude" in the original.
    static func lcsDiff(_ a: [String], _ b: [String]) -> (lcsLength: Int, adds: [String]) {
        let m = a.count, n = b.count
        if m == 0 { return (0, b) }
        if n == 0 { return (0, []) }

        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if a[i - 1].caseInsensitiveCompare(b[j - 1]) == .orderedSame {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }

        var i = m, j = n
        var adds: [String] = []
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && a[i - 1].caseInsensitiveCompare(b[j - 1]) == .orderedSame {
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j]) {
                adds.append(b[j - 1])
                j -= 1
            } else {
                i -= 1
            }
        }
        return (dp[m][n], adds.reversed())
    }

    // MARK: - Filter

    private static let stopwords: Set<String> = [
        "the", "and", "but", "for", "with", "this", "that", "have", "from",
        "they", "will", "would", "could", "should", "their", "there", "what",
        "when", "where", "your", "yours", "mine", "ours", "his", "hers",
        "its", "into", "than", "then", "them", "these", "those", "some",
        "such", "also", "about", "after", "before", "because", "while"
    ]

    static func isCandidateTerm(_ token: String, existingDict: Set<String>, existingMemory: Set<String>) -> Bool {
        // SECURITY: even if the upstream AXTextReader missed a secure field
        // (custom NSView-backed input, etc.), the entropy + length guards
        // below refuse to learn anything that looks like a credential. A
        // proper noun is always <= 32 characters and never has the
        // structural properties of an API key / JWT / base64 blob.
        guard token.count >= 3, token.count <= 32 else { return false }
        let lower = token.lowercased()
        if existingDict.contains(lower) || existingMemory.contains(lower) { return false }
        if stopwords.contains(lower) { return false }
        if looksLikeSecret(token) { return false }

        if containsCJK(token) { return true }

        // Acronym: 2+ letters all uppercase (or with digits) — MLX, NASA, GPT4.
        let letters = token.filter { $0.isLetter }
        if letters.count >= 2 && letters.allSatisfy({ $0.isUppercase }) {
            return true
        }

        // Mixed-case internal: contains an uppercase letter past index 0
        // (Anthropic, MyApp, OpenAI). This excludes sentence-start words.
        if token.dropFirst().contains(where: { $0.isUppercase }) {
            return true
        }

        return false
    }

    /// Refuse to learn anything that looks like a credential. Real proper
    /// nouns score under 3.5 bits/char in Shannon entropy and don't start
    /// with provider-specific token prefixes; secrets routinely score above
    /// 4.5 bits/char and have telltale shapes.
    static func looksLikeSecret(_ token: String) -> Bool {
        let prefixes = [
            "sk-", "sk_", "gsk_", "AKIA", "ya29.", "ghp_", "github_pat_",
            "xoxb-", "xoxp-", "AIza", "AIzaSy", "ASIA", "ASIA-", "ATATT3"
        ]
        for prefix in prefixes where token.hasPrefix(prefix) { return true }

        // JWT-shaped: 3 base64url segments separated by '.'
        let segments = token.split(separator: ".")
        if segments.count == 3,
           segments.allSatisfy({ $0.count >= 4 && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" } }) {
            return true
        }

        // Anything ≥16 chars consisting entirely of base64/hex/url-safe
        // characters is almost certainly a token.
        if token.count >= 16 {
            let urlSafe = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_+/=")
            if token.unicodeScalars.allSatisfy({ urlSafe.contains($0) }) {
                return true
            }
        }

        // Entropy heuristic for medium length tokens (10..15 chars).
        if token.count >= 10, shannonEntropy(token) > 4.0 {
            return true
        }
        return false
    }

    private static func shannonEntropy(_ s: String) -> Double {
        guard !s.isEmpty else { return 0 }
        var counts: [Character: Int] = [:]
        for ch in s { counts[ch, default: 0] += 1 }
        let n = Double(s.count)
        var h = 0.0
        for c in counts.values {
            let p = Double(c) / n
            h -= p * (log(p) / log(2.0))
        }
        return h
    }

    private static func containsCJK(_ token: String) -> Bool {
        for scalar in token.unicodeScalars {
            let v = scalar.value
            if (0x4E00...0x9FFF).contains(v) ||
               (0x3040...0x30FF).contains(v) ||
               (0xAC00...0xD7AF).contains(v) {
                return true
            }
        }
        return false
    }
}
