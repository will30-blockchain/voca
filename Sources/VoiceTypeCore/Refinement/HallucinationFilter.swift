import Foundation

/// Whisper is famous for hallucinating common training-data outros on silent
/// or near-silent audio — "Thank you for watching", "Subscribe to the
/// channel", "Bye bye", etc. We reject these when paired with an audio
/// signal that was effectively silent.
public enum HallucinationFilter {
    /// Audio whose peak amplitude is below this threshold is considered silent.
    /// 16-bit PCM scaled to 0…1, so 0.012 ≈ -38 dBFS, a quiet room.
    public static let silenceThreshold: Float = 0.012

    private static let knownPhrases: Set<String> = [
        "thank you", "thanks for watching", "thank you for watching",
        "thanks", "thank you.", "thank you for watching.",
        "thanks for watching.", "subscribe to the channel",
        "please subscribe", "bye", "bye-bye", "bye bye", "bye.",
        "see you next time", "see you in the next video", "good bye",
        "you", ".", " ",
        "謝謝", "謝謝觀看", "請訂閱",
        "ありがとうございました", "ご視聴ありがとうございました",
        "감사합니다",
    ]

    /// Returns true if `text` looks like a hallucinated outro fragment.
    public static func looksHallucinated(_ text: String) -> Bool {
        let normalised = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’"))
            .lowercased()
        if normalised.isEmpty { return true }
        if normalised.count <= 3 { return true }
        return knownPhrases.contains(normalised)
    }

    /// Combined check: if the audio was silent AND the transcript matches a
    /// known hallucination, drop it.
    public static func shouldDrop(transcript: String, peakLevel: Float) -> Bool {
        if peakLevel < silenceThreshold { return true }
        // Even with some signal, a 2-word transcript that's a known outro is
        // almost always wrong on short clips.
        if looksHallucinated(transcript) { return true }
        return false
    }
}
