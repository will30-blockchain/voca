import Foundation

/// Whisper is famous for hallucinating training-data outros on silent or
/// near-silent audio — "Thank you for watching", "謝謝觀看", "Bye-bye", etc.
///
/// Earlier versions of this filter were too aggressive (rejected any
/// transcript shorter than 4 characters, killing legitimate short answers
/// like "OK", "嗯", "好"). The new rule is conservative: only drop a
/// transcript when **both** conditions hold —
///   1. The audio peak was below the silence threshold, AND
///   2. The transcript exactly matches a known Whisper outro phrase.
///
/// In all other cases we trust the model: a quiet but real "OK" passes, a
/// loud accidental cough passes, a normal sentence passes.
public enum HallucinationFilter {
    /// Audio whose peak amplitude (0…1) is below this is treated as silence.
    /// Lowered from 0.012 → 0.004 because real speech on Macs with low input
    /// gain can peak below the old threshold. Now this only catches genuine
    /// silence (room tone, fan noise) rather than soft-spoken users.
    public static let silenceThreshold: Float = 0.004

    /// Exact phrases (case- and whitespace-insensitive) Whisper emits on
    /// silent / noise-only audio. Curated from Groq + OpenAI Whisper logs.
    private static let knownHallucinations: Set<String> = [
        // English outros
        "thank you", "thank you.", "thanks", "thanks.",
        "thank you for watching", "thank you for watching.",
        "thanks for watching", "thanks for watching.",
        "subscribe to the channel", "please subscribe",
        "bye", "bye.", "bye-bye", "bye bye", "goodbye", "good bye",
        "see you next time", "see you in the next video",
        "you", ".", "..", "...",

        // Chinese outros
        "謝謝", "谢谢", "謝謝觀看", "谢谢观看", "請訂閱", "请订阅",
        "感謝觀看", "感谢观看", "再見", "再见",

        // Japanese
        "ありがとうございました", "ご視聴ありがとうございました",
        "ご視聴ありがとうございます",

        // Korean
        "감사합니다", "시청해주셔서 감사합니다"
    ]

    /// Returns `.drop(reason:)` when the transcript should be discarded,
    /// `.keep` otherwise. `reason` is for logging only — the engine surfaces
    /// dropped takes silently (returns to idle without an error toast).
    public enum Decision: Equatable {
        case keep
        case drop(reason: String)
    }

    public static func decide(transcript: String, peakLevel: Float) -> Decision {
        let trimmed = transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if trimmed.isEmpty {
            return .drop(reason: "empty transcript")
        }

        // Genuine silence — drop regardless of what Whisper made up.
        if peakLevel < silenceThreshold {
            return .drop(reason: "audio silent (peak=\(peakLevel))")
        }

        // Audio had signal, but the text is a known Whisper outro — still a
        // hallucination, because real speech that loud almost never matches
        // these exact strings.
        if knownHallucinations.contains(trimmed) {
            return .drop(reason: "matched known hallucination: \(trimmed)")
        }

        return .keep
    }
}
