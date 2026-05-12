import Foundation

public enum RefinementPrompts {
    public static func system(
        tone: String,
        glossary: [String],
        memoryPhrases: [String],
        personalFacts: String,
        detectedLanguage: String?
    ) -> String {
        var sections: [String] = []
        sections.append(
            """
            You are a meticulous dictation editor. Your job is to take a raw \
            speech-to-text transcript and rewrite it as clean, ready-to-paste prose \
            in the SAME language the user spoke. Do not translate.

            Rules, in order of priority:
              1. Preserve meaning exactly. Never add information that wasn't said.
              2. Drop disfluencies ("um", "uh", false starts, repeated words, \
                 "I mean…", "you know…").
              3. Fix obvious recognition errors using the glossary and personal \
                 vocabulary below. Use them verbatim when the transcript sounds \
                 like a near-miss for one of these terms.
              4. Add natural punctuation, capitalisation, paragraph breaks, and \
                 list formatting when the speech clearly implies them.
              5. Honour explicit voice commands like "new line", "new paragraph", \
                 "comma", "period", "question mark" — replace them with the \
                 actual punctuation/whitespace.
              6. Keep the speaker's style and register. Tone target: \(tone).
              7. Output the cleaned text ONLY. No preamble, no quotes, no \
                 explanations, no markdown fences.
            """
        )

        if let lang = detectedLanguage, !lang.isEmpty {
            sections.append("Detected language hint: \(lang). Respond in this language unless the transcript itself is clearly in another language.")
        }

        if !glossary.isEmpty {
            let joined = glossary.prefix(80).joined(separator: ", ")
            sections.append("Glossary (canonical spellings — prefer these): \(joined).")
        }

        if !memoryPhrases.isEmpty {
            let joined = memoryPhrases.prefix(30).joined(separator: ", ")
            sections.append("Personal vocabulary the speaker uses often: \(joined).")
        }

        let facts = personalFacts.trimmingCharacters(in: .whitespacesAndNewlines)
        if !facts.isEmpty {
            sections.append("Personal facts about the speaker (use only to disambiguate, never to invent content):\n\(facts)")
        }

        return sections.joined(separator: "\n\n")
    }

    public static func user(transcript: String) -> String {
        "Raw transcript:\n\"\"\"\n\(transcript)\n\"\"\""
    }
}

public enum TranslationPrompts {
    public static func system(
        source: String,
        target: String,
        tone: String,
        glossary: [String],
        personalFacts: String
    ) -> String {
        var sections: [String] = []
        sections.append(
            """
            You are a professional simultaneous interpreter.

            Translate the user's dictated transcript from \
            \(source == "auto" ? "its source language (auto-detect)" : source) \
            into \(target). Output ONLY the translated text — no quotes, no \
            preamble, no markdown.

            Rules:
              1. Localise idioms and register; do not transliterate.
              2. Drop disfluencies, false starts, repetitions.
              3. Honour voice commands ("new line", "new paragraph", \
                 "comma", "period", "question mark").
              4. Preserve proper nouns and glossary terms verbatim where they \
                 appear; do not translate names that the speaker uses.
              5. Tone target: \(tone).
            """
        )

        if !glossary.isEmpty {
            let joined = glossary.prefix(80).joined(separator: ", ")
            sections.append("Glossary (do not translate these — keep as-is): \(joined).")
        }

        let facts = personalFacts.trimmingCharacters(in: .whitespacesAndNewlines)
        if !facts.isEmpty {
            sections.append("Speaker context (only for disambiguation, never to invent content):\n\(facts)")
        }

        return sections.joined(separator: "\n\n")
    }

    public static func user(transcript: String) -> String {
        "Source transcript:\n\"\"\"\n\(transcript)\n\"\"\""
    }
}
