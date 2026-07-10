import XCTest
@testable import VOCACore

final class VOCACoreTests: XCTestCase {
    func testWAVHeaderHasRiffSignature() {
        let wav = WAVEncoder.encode(samples: [0, 0, 0, 0], sampleRate: 16_000)
        let header = wav.prefix(4)
        XCTAssertEqual(String(data: header, encoding: .ascii), "RIFF")
    }

    func testPersonalMemoryExtractsCapitalisedTokens() {
        let phrases = PersonalMemory.candidatePhrases(in: "I met Will at Anthropic in Tokyo.")
        XCTAssertTrue(phrases.contains("Will"))
        XCTAssertTrue(phrases.contains("Anthropic"))
        XCTAssertTrue(phrases.contains("Tokyo"))
    }

    func testMultipartBodyEmitsBoundaries() {
        var body = MultipartBody(boundary: "xyz")
        body.appendField("a", "1")
        let out = body.finalize()
        let str = String(data: out, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("--xyz"))
        XCTAssertTrue(str.contains("name=\"a\""))
        XCTAssertTrue(str.hasSuffix("--xyz--\r\n"))
    }

    func testRefinementPromptIncludesGlossary() {
        let prompt = RefinementPrompts.system(
            tone: "natural",
            glossary: ["Acme Corp", "MLX"],
            memoryPhrases: ["Tokyo"],
            personalFacts: "",
            detectedLanguage: "en"
        )
        XCTAssertTrue(prompt.contains("Acme Corp"))
        XCTAssertTrue(prompt.contains("MLX"))
        XCTAssertTrue(prompt.contains("Tokyo"))
    }

    // MARK: - Refinement prompt smart-formatting rules

    /// Regression: the LLM editor must be told to recognise the
    /// greeting + sign-off pattern and lay the output out as an email.
    func testRefinementPromptCoversEmailShape() {
        let prompt = RefinementPrompts.system(
            tone: "natural", glossary: [], memoryPhrases: [],
            personalFacts: "", detectedLanguage: nil
        )
        XCTAssertTrue(prompt.lowercased().contains("email"),
                      "Expected the prompt to explicitly mention email layout")
        XCTAssertTrue(prompt.contains("sign-off") || prompt.contains("敬上"),
                      "Expected a concrete sign-off cue (English or Chinese)")
    }

    /// Regression: the LLM editor must drop the spoken enumeration cue
    /// and render each item as a numbered list — even when only ONE cue
    /// appears (no preceding "Firstly"). User-reported case: an email
    /// containing only "Secondly" came back as flowing prose.
    func testRefinementPromptCoversEnumeratedLists() {
        let prompt = RefinementPrompts.system(
            tone: "natural", glossary: [], memoryPhrases: [],
            personalFacts: "", detectedLanguage: nil
        )
        XCTAssertTrue(prompt.contains("第一點") && prompt.contains("再來"),
                      "Expected Chinese enumeration cues including 再來")
        XCTAssertTrue(prompt.lowercased().contains("a single one is enough") ||
                      prompt.contains("single one is enough"),
                      "Single-cue triggering must be explicit in the prompt")
        XCTAssertTrue(prompt.contains("Secondly") && prompt.contains("scan back"),
                      "Expected the 'scan back for implied first item' instruction")
    }

    /// Regression: the email-shape rule must recognise a trailing
    /// "thank you" / "謝謝" as a sign-off and pull it onto its own line,
    /// not leave it glued to the last body sentence.
    func testRefinementPromptCoversTrailingThanksSignOff() {
        let prompt = RefinementPrompts.system(
            tone: "natural", glossary: [], memoryPhrases: [],
            personalFacts: "", detectedLanguage: nil
        )
        XCTAssertTrue(prompt.contains("thank you") && prompt.contains("謝謝"),
                      "Expected polite-thanks sign-off variants")
        XCTAssertTrue(prompt.contains("its own sign-off line") ||
                      prompt.contains("pulled out as its own sign-off line"),
                      "Prompt must instruct lifting trailing thanks onto its own line")
    }

    /// Regression: when the speaker corrects themselves (A→B), only B
    /// should survive in the output.
    func testRefinementPromptCoversSelfCorrection() {
        let prompt = RefinementPrompts.system(
            tone: "natural", glossary: [], memoryPhrases: [],
            personalFacts: "", detectedLanguage: nil
        )
        XCTAssertTrue(prompt.lowercased().contains("self-correction") ||
                      prompt.contains("不對") ||
                      prompt.contains("應該說"),
                      "Expected self-correction handling to be in the prompt")
        XCTAssertTrue(prompt.contains("scratch that") || prompt.contains("我講錯"),
                      "Expected a concrete self-correction marker")
    }

    /// Regression: filler-word filtering should cover both English and
    /// Chinese disfluencies.
    func testRefinementPromptCoversChineseFillers() {
        let prompt = RefinementPrompts.system(
            tone: "natural", glossary: [], memoryPhrases: [],
            personalFacts: "", detectedLanguage: nil
        )
        XCTAssertTrue(prompt.contains("那個") || prompt.contains("就是"),
                      "Expected Chinese filler-word examples")
    }

    // MARK: - UserDictionary.Entry source-field migration

    /// Pre-2026-05-28 dictionary entries had no `source` field. The decoder
    /// must still load them and infer the source from the note prefix.
    func testEntryDecoderInfersAutoLearnedFromLegacyNote() throws {
        let json = #"""
        {"id":"00000000-0000-0000-0000-000000000001","term":"Anthropic","note":"auto-learned from edit"}
        """#.data(using: .utf8)!
        let entry = try JSONDecoder().decode(UserDictionary.Entry.self, from: json)
        XCTAssertEqual(entry.term, "Anthropic")
        XCTAssertEqual(entry.source, .autoLearned)
    }

    func testEntryDecoderInfersManualWhenNoSourceAndNoAutoPrefix() throws {
        let json = #"""
        {"id":"00000000-0000-0000-0000-000000000002","term":"Acme","note":"my company"}
        """#.data(using: .utf8)!
        let entry = try JSONDecoder().decode(UserDictionary.Entry.self, from: json)
        XCTAssertEqual(entry.source, .manual)
    }

    /// A malformed `source` value (future case downgraded, hand-edited JSON)
    /// must NOT fail the entire load — fall back to note-prefix inference.
    func testEntryDecoderToleratesUnknownSourceValue() throws {
        let json = #"""
        {"id":"00000000-0000-0000-0000-000000000003","term":"Foo","note":"auto-learned from edit","source":"some_future_origin"}
        """#.data(using: .utf8)!
        let entry = try JSONDecoder().decode(UserDictionary.Entry.self, from: json)
        XCTAssertEqual(entry.source, .autoLearned, "Should fall back to note-prefix inference, not throw")
    }

    func testEntryDecoderReadsExplicitSource() throws {
        let json = #"""
        {"id":"00000000-0000-0000-0000-000000000004","term":"Bar","note":"","source":"auto_learned"}
        """#.data(using: .utf8)!
        let entry = try JSONDecoder().decode(UserDictionary.Entry.self, from: json)
        XCTAssertEqual(entry.source, .autoLearned)
    }

    // MARK: - TextNormalizer (Pangu CJK ⇄ Latin/digit spacing)

    func testPanguSpacesCJKAndLatinBothDirections() {
        XCTAssertEqual(TextNormalizer.panguSpace("我用VOCA"), "我用 VOCA")
        XCTAssertEqual(TextNormalizer.panguSpace("VOCA好用"), "VOCA 好用")
        XCTAssertEqual(TextNormalizer.panguSpace("VOCA好用很perfect"), "VOCA 好用很 perfect")
    }

    func testPanguSpacesCJKAndDigit() {
        XCTAssertEqual(TextNormalizer.panguSpace("2026年5月"), "2026 年 5 月")
        XCTAssertEqual(TextNormalizer.panguSpace("第3次"), "第 3 次")
    }

    func testPanguNoDoubleSpaceWhenAlreadySpaced() {
        XCTAssertEqual(TextNormalizer.panguSpace("我用 VOCA"), "我用 VOCA")
        XCTAssertEqual(TextNormalizer.panguSpace("VOCA 好用"), "VOCA 好用")
    }

    func testPanguPreservesCJKPunctuation() {
        // No space between Latin and CJK punctuation, no space between CJK
        // chars and CJK punctuation.
        XCTAssertEqual(TextNormalizer.panguSpace("我用VOCA。"), "我用 VOCA。")
        XCTAssertEqual(TextNormalizer.panguSpace("「VOCA」很好"), "「VOCA」很好")
    }

    func testPanguHandlesPureLatinAndPureCJKUnchanged() {
        XCTAssertEqual(TextNormalizer.panguSpace("Hello world"), "Hello world")
        XCTAssertEqual(TextNormalizer.panguSpace("中文句子"), "中文句子")
        XCTAssertEqual(TextNormalizer.panguSpace(""), "")
        XCTAssertEqual(TextNormalizer.panguSpace("A"), "A")
    }

    func testPanguHandlesKanaAndHangul() {
        // Hiragana / Katakana / Hangul all count as CJK for the spacer.
        XCTAssertEqual(TextNormalizer.panguSpace("僕はVOCAを使う"), "僕は VOCA を使う")
        XCTAssertEqual(TextNormalizer.panguSpace("이VOCA"), "이 VOCA")
    }

    /// Regression: the editor must NOT translate English words embedded
    /// in a Chinese utterance (or vice versa) — code-switching is
    /// preserved verbatim. Tests both the rule's presence AND the
    /// concrete forbidden-translation examples.
    func testRefinementPromptCoversCodeSwitching() {
        let prompt = RefinementPrompts.system(
            tone: "natural", glossary: [], memoryPhrases: [],
            personalFacts: "", detectedLanguage: nil
        )
        XCTAssertTrue(prompt.lowercased().contains("code-switching"),
                      "Expected an explicit code-switching rule")
        XCTAssertTrue(prompt.contains("deadline") && prompt.contains("sync"),
                      "Expected concrete CN+EN code-switch examples")
        // The explicit "update → update (NOT 更新)" example is the
        // strongest guard against the most-reported failure mode.
        XCTAssertTrue(prompt.contains("update") && prompt.contains("更新"),
                      "Expected the update→更新 forbidden-translation example")
        XCTAssertTrue(prompt.contains("forbidden") ||
                      prompt.contains("non-negotiable") ||
                      prompt.contains("MUST stay"),
                      "Expected emphatic no-translate phrasing")
    }

    /// The reinforcement message in the user prompt should also call out
    /// the no-translate rule so the model sees it twice (system + user).
    func testRefinementUserPromptReinforcesNoTranslate() {
        let userPrompt = RefinementPrompts.user(transcript: "我要 update 一下")
        XCTAssertTrue(userPrompt.contains("update") && userPrompt.contains("更新"),
                      "User-prompt reminder should show the update→更新 forbidden pair")
        XCTAssertTrue(userPrompt.contains("我要 update 一下"),
                      "User prompt must still embed the transcript verbatim")
    }

    /// Regression: the Chinese languageRule must clarify that the
    /// character-set requirement is character-set only — NOT a licence
    /// to translate English words into Chinese.
    func testChineseLanguageRulePreservesEnglish() {
        let traditional = RefinementPrompts.languageRule(for: "zh-Hant")
        XCTAssertTrue(traditional.contains("English") &&
                      (traditional.contains("stay in English") ||
                       traditional.contains("not translate")),
                      "zh-Hant rule must explicitly preserve English words")

        let simplified = RefinementPrompts.languageRule(for: "zh-Hans")
        XCTAssertTrue(simplified.contains("English") &&
                      (simplified.contains("stay in English") ||
                       simplified.contains("not translate")),
                      "zh-Hans rule must explicitly preserve English words")
    }

    // MARK: - CorrectionDiff CJK character-level learning

    /// Two-character Chinese word with ONE character changed. The
    /// previous word-level diff produced 0 overlap and learned nothing.
    /// The character-level supplement should now catch the corrected
    /// word.
    func testCorrectionDiffLearnsSingleCharEditInTwoCharCJKWord() {
        let report = CorrectionDiff.newCandidates(
            originalPaste: "我覺得資訊很重要",
            currentText: "我覺得資料很重要",
            existingDictionary: [],
            existingMemory: []
        )
        XCTAssertTrue(report.candidates.contains("資料"),
                      "Expected '資料' to be learned; got \(report.candidates)")
    }

    /// Both characters of a two-character word changed (polyphone /
    /// homophone confusion).
    func testCorrectionDiffLearnsTwoCharEditInCJKWord() {
        let report = CorrectionDiff.newCandidates(
            originalPaste: "我要去宜灣",
            currentText: "我要去台灣",
            existingDictionary: [],
            existingMemory: []
        )
        XCTAssertTrue(report.candidates.contains("台灣"),
                      "Expected '台灣' from two-char fix; got \(report.candidates)")
    }

    /// Proper noun (three-character person name) with one character
    /// wrong. Expansion should grab at least 「依文」, ideally 「陳依文」.
    func testCorrectionDiffLearnsCharChangeInProperNoun() {
        let report = CorrectionDiff.newCandidates(
            originalPaste: "我叫陳一文",
            currentText: "我叫陳依文",
            existingDictionary: [],
            existingMemory: []
        )
        XCTAssertTrue(
            report.candidates.contains("陳依文") || report.candidates.contains("依文"),
            "Expected '陳依文' or '依文' from name fix; got \(report.candidates)"
        )
    }

    /// Nothing changed — no candidates.
    func testCorrectionDiffSkipsWhenNothingChanged() {
        let report = CorrectionDiff.newCandidates(
            originalPaste: "你好世界",
            currentText: "你好世界",
            existingDictionary: [],
            existingMemory: []
        )
        XCTAssertEqual(report.candidates, [])
    }

    /// Already-known terms must not be re-added.
    func testCorrectionDiffSkipsTermsAlreadyInDictionary() {
        let report = CorrectionDiff.newCandidates(
            originalPaste: "我覺得資訊很重要",
            currentText: "我覺得資料很重要",
            existingDictionary: ["資料"],
            existingMemory: []
        )
        XCTAssertFalse(report.candidates.contains("資料"))
    }

    /// Wholesale rewrite (> 50% character change) must NOT spray random
    /// 6-char snippets into the dictionary.
    func testCorrectionDiffBailsOnWholesaleRewrite() {
        let report = CorrectionDiff.newCandidates(
            originalPaste: "你好",
            currentText: "完全不同的句子",
            existingDictionary: [],
            existingMemory: []
        )
        XCTAssertEqual(report.candidates, [],
                       "Wholesale rewrite should NOT produce candidates")
    }

    /// Typing a whole new sentence into the same field is NEW content, not a
    /// correction — even though LCS overlap stays high. Must learn nothing.
    func testCorrectionDiffIgnoresLargeExpansion() {
        let report = CorrectionDiff.newCandidates(
            originalPaste: "Hi",
            currentText: "Hi, I just met Anthropic and OpenAI and Deepgram at the conference in Tokyo today",
            existingDictionary: [],
            existingMemory: []
        )
        XCTAssertEqual(report.candidates, [],
                       "Large expansion is new content, not a correction")
    }

    /// A genuine localized correction inside similar-length text still works
    /// (guard must not be over-broad).
    func testCorrectionDiffStillLearnsLocalizedEditAfterGuard() {
        let report = CorrectionDiff.newCandidates(
            originalPaste: "我約了陳一文開會",
            currentText: "我約了陳依文開會",
            existingDictionary: [],
            existingMemory: []
        )
        XCTAssertTrue(report.candidates.contains("陳依文"))
    }

    // MARK: - CorrectionLearner.safeHint (privacy)

    /// Secret-shaped tokens in the context hint are redacted.
    func testSafeHintRedactsSecrets() {
        let hint = CorrectionLearner.safeHint(from: "my key is sk-abc123def456ghi789jkl")
        XCTAssertFalse(hint.contains("sk-abc123"))
        XCTAssertTrue(hint.contains("•••"))
    }

    /// Ordinary dictation text is preserved (just truncated).
    func testSafeHintKeepsOrdinaryText() {
        let hint = CorrectionLearner.safeHint(from: "meeting notes for the team")
        XCTAssertTrue(hint.hasPrefix("meeting notes"))
    }

    // MARK: - LearningMetrics (observability)

    func testLearningMetricsCaptureRate() {
        var m = LearningMetrics()
        XCTAssertEqual(m.captureRate, 0, "no attempts → 0, not NaN")
        m.captureAttempts = 4
        m.captureSuccesses = 1
        XCTAssertEqual(m.captureRate, 0.25, accuracy: 0.001)
    }

    func testLearningMetricsSummaryAndCodable() throws {
        var m = LearningMetrics()
        m.captureAttempts = 2
        m.captureSuccesses = 1
        m.termsPromoted = 3
        XCTAssertTrue(m.summary.contains("50%"))
        let restored = try JSONDecoder().decode(
            LearningMetrics.self, from: JSONEncoder().encode(m)
        )
        XCTAssertEqual(restored, m)
    }

    // MARK: - STTBias (glossary → provider bias)

    /// Priority order is manual → memory → auto-learned, and duplicates are
    /// collapsed case-insensitively keeping the highest-priority spelling.
    func testSTTBiasOrdersByConfidenceAndDedupes() {
        let terms = STTBias.orderedTerms(
            manualTerms: ["Anthropic", "MLX"],
            memoryPhrases: ["Tokyo", "anthropic"], // dup of manual, lower case
            autoLearnedTerms: ["資料", "mlx"]        // dup of manual
        )
        XCTAssertEqual(terms, ["Anthropic", "MLX", "Tokyo", "資料"])
    }

    /// The term list must be hard-capped so it can never blow the STT window.
    func testSTTBiasRespectsLimit() {
        let many = (0..<100).map { "Term\($0)" }
        let terms = STTBias.orderedTerms(
            manualTerms: many, memoryPhrases: [], autoLearnedTerms: [], limit: 10
        )
        XCTAssertEqual(terms.count, 10)
        XCTAssertEqual(terms.first, "Term0")
    }

    /// Whisper attends to the prompt tail, so the MOST important term (first
    /// in the ranked input) must appear LAST in the emitted prompt.
    func testWhisperPromptPlacesImportantTermLast() {
        let prompt = STTBias.whisperPrompt(terms: ["MostImportant", "Least"])
        let unwrapped = try! XCTUnwrap(prompt)
        let importantIdx = try! XCTUnwrap(unwrapped.range(of: "MostImportant")).lowerBound
        let leastIdx = try! XCTUnwrap(unwrapped.range(of: "Least")).lowerBound
        XCTAssertTrue(leastIdx < importantIdx,
                      "Least-important term should come before the most-important one")
        XCTAssertTrue(unwrapped.hasSuffix("MostImportant."))
    }

    /// Empty input biases nothing (nil, not an empty-label string).
    func testWhisperPromptNilWhenNoTerms() {
        XCTAssertNil(STTBias.whisperPrompt(terms: []))
        XCTAssertNil(STTBias.whisperPrompt(terms: ["   "]))
    }

    /// The prompt must stay within the character budget even with many terms.
    func testWhisperPromptRespectsCharBudget() {
        let many = (0..<200).map { "Term\($0)" }
        let prompt = try! XCTUnwrap(STTBias.whisperPrompt(terms: many, maxChars: 120))
        XCTAssertLessThanOrEqual(prompt.count, 120)
    }

    // MARK: - LearningGate (confidence gating)

    /// A candidate must be seen `threshold` times before it promotes; the
    /// first sighting is held.
    func testLearningGateHoldsUntilThreshold() {
        var gate = LearningGate(threshold: 2)
        XCTAssertFalse(gate.observe("資料"), "first sighting should be held")
        XCTAssertEqual(gate.pendingCount("資料"), 1)
        XCTAssertTrue(gate.observe("資料"), "second sighting should promote")
    }

    /// Promotion clears the pending count so a later re-learn starts fresh.
    func testLearningGateResetsAfterPromotion() {
        var gate = LearningGate(threshold: 2)
        _ = gate.observe("MLX")
        XCTAssertTrue(gate.observe("MLX"))
        XCTAssertEqual(gate.pendingCount("MLX"), 0, "count clears on promotion")
        XCTAssertFalse(gate.observe("MLX"), "next sighting starts a fresh count")
    }

    /// Counting is case-insensitive — "Anthropic" and "anthropic" are one term.
    func testLearningGateIsCaseInsensitive() {
        var gate = LearningGate(threshold: 2)
        XCTAssertFalse(gate.observe("Anthropic"))
        XCTAssertTrue(gate.observe("anthropic"))
    }

    /// forget() drops pending state so a rejected term isn't instantly
    /// re-promoted by a stray sighting.
    func testLearningGateForgetResetsCount() {
        var gate = LearningGate(threshold: 2)
        _ = gate.observe("Tokyo")
        gate.forget("tokyo")
        XCTAssertEqual(gate.pendingCount("Tokyo"), 0)
        XCTAssertFalse(gate.observe("Tokyo"), "after forget, needs threshold again")
    }

    /// A threshold of 1 promotes immediately (opt-out of gating).
    func testLearningGateThresholdOnePromotesImmediately() {
        var gate = LearningGate(threshold: 1)
        XCTAssertTrue(gate.observe("X"))
    }

    /// The gate round-trips through Codable so pending counts survive relaunch.
    func testLearningGateCodableRoundTrip() throws {
        var gate = LearningGate(threshold: 3)
        _ = gate.observe("foo")
        _ = gate.observe("foo")
        let data = try JSONEncoder().encode(gate)
        var restored = try JSONDecoder().decode(LearningGate.self, from: data)
        XCTAssertEqual(restored.pendingCount("foo"), 2)
        XCTAssertTrue(restored.observe("foo"), "restored count promotes on 3rd")
    }
}
