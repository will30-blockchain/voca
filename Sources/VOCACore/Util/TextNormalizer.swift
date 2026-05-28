import Foundation

/// Post-LLM text cleanups that don't belong in the LLM prompt — pure,
/// deterministic, locally enforceable.
public enum TextNormalizer {

    /// Inserts a half-width space between CJK characters and Latin letters
    /// or ASCII digits. Sometimes called "Pangu spacing" after `pangu.js`.
    /// Handles both directions and stays a no-op when a space already sits
    /// between the boundary.
    ///
    /// Examples:
    ///   "我用VOCA" → "我用 VOCA"
    ///   "VOCA好用" → "VOCA 好用"
    ///   "2026年5月" → "2026 年 5 月"
    ///   "我用 VOCA" → "我用 VOCA"   (no double-space)
    ///   "我用VOCA。" → "我用 VOCA。" (full-width punctuation untouched)
    ///
    /// CJK range covers Han ideographs, Hiragana, Katakana, and Hangul —
    /// the same set the dictionary's CJK heuristics use, so this stays
    /// consistent with the rest of the engine's CJK handling.
    public static func panguSpace(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let scalars = Array(text.unicodeScalars)
        guard scalars.count >= 2 else { return text }

        var out = String.UnicodeScalarView()
        out.reserveCapacity(scalars.count + 8)
        out.append(scalars[0])

        for i in 1..<scalars.count {
            let prev = scalars[i - 1]
            let curr = scalars[i]
            if needsSpace(between: prev, and: curr) {
                out.append(Unicode.Scalar(0x20))
            }
            out.append(curr)
        }
        return String(out)
    }

    private static func needsSpace(between prev: Unicode.Scalar, and curr: Unicode.Scalar) -> Bool {
        let prevCJK = isCJK(prev)
        let currCJK = isCJK(curr)
        let prevLat = isLatinOrDigit(prev)
        let currLat = isLatinOrDigit(curr)
        return (prevCJK && currLat) || (prevLat && currCJK)
    }

    /// Han ideographs + Japanese kana + Hangul syllables. Intentionally
    /// excludes CJK punctuation (e.g. 。「」，！？) so we don't insert a
    /// space inside Chinese-style sentence boundaries.
    private static func isCJK(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (0x4E00...0x9FFF).contains(v) ||   // CJK Unified Ideographs
               (0x3040...0x30FF).contains(v) ||   // Hiragana + Katakana
               (0xAC00...0xD7AF).contains(v)      // Hangul Syllables
    }

    /// ASCII letters and digits. Symbols (#@/etc.) are deliberately
    /// out-of-scope — pangu.js spaces around them too, but those rules
    /// are noisier in practice and easy to get wrong without context.
    private static func isLatinOrDigit(_ s: Unicode.Scalar) -> Bool {
        let v = s.value
        return (0x30...0x39).contains(v) ||   // 0–9
               (0x41...0x5A).contains(v) ||   // A–Z
               (0x61...0x7A).contains(v)      // a–z
    }
}
