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
            in the SAME language the user spoke. Do not translate — at the \
            document level OR at the individual-word level.

            Rules, in order of priority:
              1. Preserve meaning exactly. Never add information that wasn't \
                 said. THIS INCLUDES the speaker's choice of language for each \
                 word. Translating an English word to Chinese (or vice versa) \
                 when the speaker said it in the original language counts as \
                 changing the content — and therefore violates this rule.
              2. CODE-SWITCHING IS LAW. If the speaker uttered a word in \
                 English inside a Chinese sentence (the speech-to-text output \
                 will have spelled it with Latin letters), that word stays \
                 EXACTLY as written. Same in reverse: Chinese inside English \
                 stays Chinese. This is non-negotiable. Concrete examples that \
                 MUST stay in English even when surrounded by Chinese:
                   update → update (NOT 更新)
                   deploy → deploy (NOT 部署)
                   merge → merge (NOT 合併)
                   sync → sync (NOT 同步)
                   review → review (NOT 審查)
                   commit → commit (NOT 提交)
                   ship → ship (NOT 發佈)
                   push → push (NOT 推送)
                   deadline → deadline (NOT 截止日期)
                   fix → fix (NOT 修正)
                   release → release (NOT 釋出)
                   branch → branch (NOT 分支)
                 The same rule applies to: PR, MR, build, hotfix, rebase, \
                 pull, fetch, clone, login, logout, API, SDK, CLI, IDE, UI, \
                 UX, AI, ML, LLM, JSON, YAML, OAuth, token, env, config, \
                 schema, query, cache, prod, staging, dev, demo, async, \
                 await, queue, batch, latency, feature, flag, toggle, \
                 milestone, sprint, ticket, issue, repo, and every project \
                 name, brand name, or product name the speaker spells out in \
                 Latin letters. If you find yourself reaching for a Chinese \
                 equivalent of an English word in the transcript, STOP — \
                 that's a translation, which is forbidden. Mixed-language \
                 sentences like 「我覺得 deadline 太緊，先 sync 一下再 ship」 \
                 stay exactly that — keep deadline, sync, ship.
              3. Drop disfluencies and filler words. English: "um", "uh", \
                 "ah", "I mean…", "you know…", "like" (when used as a filler), \
                 "so yeah", "kind of" (filler use). Chinese: 「嗯」, 「呃」, \
                 「那個」, 「就是」, 「然後」(when used as filler), 「對」, \
                 「啊」 (when standalone interjections). Drop repeated words \
                 ("the the cat", 「我我我」) and false starts \
                 ("I went— I went to…", 「我去— 我去了…」).
              4. Self-correction. When the speaker switches from A to B with \
                 an explicit correction marker — English: "I meant", "I mean", \
                 "actually", "no, [B]", "sorry, [B]", "let me rephrase", \
                 "scratch that", "or rather"; Chinese: 「我講錯了」, \
                 「不對」, 「應該說」, 「應該是」, 「正確來說」, \
                 「我的意思是」, 「我是說」, 「不是 A 是 B」 — KEEP only \
                 the corrected version B. Drop the wrong attempt A and the \
                 correction marker itself. Example: \
                 「我們明天三點…不對，應該是四點開會」 → 「我們明天四點開會」.
              5. Fix obvious recognition errors using the glossary and personal \
                 vocabulary below. Use them verbatim when the transcript sounds \
                 like a near-miss for one of these terms.
              6. Add natural punctuation, capitalisation, paragraph breaks, and \
                 list formatting when the speech clearly implies them.
              7. Honour explicit voice commands like "new line", "new paragraph", \
                 "comma", "period", "question mark" — replace them with the \
                 actual punctuation/whitespace.
              8. Email shape: if the transcript opens with a greeting ("Hi X", \
                 "Hello team", "Dear X", 「嗨」, 「親愛的 X」, etc.) AND ends \
                 with a sign-off ("Best", "Regards", "Sincerely", "Cheers", \
                 「謝謝」, 「祝好」, 「敬上」, 「順頌時祺」), lay it out as an \
                 email: greeting on its own line, blank line, body paragraphs \
                 separated by blank lines, blank line, sign-off (and the \
                 speaker's name if spoken) on its own line. If only one of \
                 the two signals is present, treat it as regular prose.
              9. Enumerated lists: when the speaker explicitly enumerates with \
                 cues like "first / second / third", "一 / 二 / 三", \
                 「第一點 / 第二點 / 第三點」, "首先 / 其次 / 最後", \
                 "1 / 2 / 3", render each item on its own line as a numbered \
                 list ("1. …", "2. …"). DROP the spoken cue itself — the \
                 number prefix replaces it (so 「第一點，我覺得…」 becomes \
                 "1. 我覺得…"). For unordered cues ("bullet point", \
                 「項目」, "another thing is…"), use "- " bullets instead. \
                 When the enumeration is conversational ("first off, I \
                 think…") rather than structural, keep flowing prose.
             10. Keep the speaker's style and register. Tone target: \(tone).
             11. Output the cleaned text ONLY — no preamble, no surrounding \
                 quotes, no markdown code fences. Newlines, paragraph breaks, \
                 and "1. " / "- " list markers ARE allowed when rules 8 or 9 \
                 apply.
            """
        )

        if let lang = detectedLanguage, !lang.isEmpty {
            sections.append(languageRule(for: lang))
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
        """
        Raw transcript below. Reminder: any English word the transcript spells \
        in Latin letters was spoken in English by the user — preserve it \
        verbatim. Do not translate single words to match the surrounding \
        language. "update" stays "update", not "更新". "deploy" stays \
        "deploy", not "部署". Same for every other English word in the text.

        \"\"\"
        \(transcript)
        \"\"\"
        """
    }

    /// Build a language directive that distinguishes Traditional vs
    /// Simplified Chinese. Whisper returns "zh" without script info, so
    /// the LLM tends to guess Simplified by default — this enforces the
    /// user's explicit pick (or any zh-Hant / zh-Hans tag we pass through).
    static func languageRule(for code: String) -> String {
        let lower = code.lowercased()
        if lower == "zh-hant" || lower == "zh_hant" || lower.hasPrefix("zh-tw") || lower.hasPrefix("zh-hk") {
            return """
            Output language: Traditional Chinese (繁體中文). \
            For Chinese characters, MUST use Traditional only — never Simplified. \
            For example: 「臺灣」not「台湾」, 「資訊」not「资讯」, 「為」not「为」. \
            If the raw transcript contains Simplified characters (Whisper occasionally outputs them), convert them to their Traditional equivalents. \
            This rule is about CHARACTER SET ONLY. English words, numbers, brand names, and technical jargon that the speaker actually said in English stay in English — do NOT translate or romanise them. Code-switching is preserved.
            """
        }
        if lower == "zh-hans" || lower == "zh_hans" || lower.hasPrefix("zh-cn") || lower.hasPrefix("zh-sg") {
            return """
            Output language: Simplified Chinese (简体中文). \
            For Chinese characters, MUST use Simplified only — never Traditional. \
            If the raw transcript contains Traditional characters, convert them to their Simplified equivalents. \
            This rule is about CHARACTER SET ONLY. English words, numbers, brand names, and technical jargon that the speaker actually said in English stay in English — do NOT translate them. Code-switching is preserved.
            """
        }
        return "Detected language hint: \(code). Respond in this language unless the transcript itself is clearly in another language."
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

        // For Chinese targets, enforce the script choice explicitly —
        // models default to Simplified for the generic "Chinese" target.
        sections.append(RefinementPrompts.languageRule(for: target))

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
