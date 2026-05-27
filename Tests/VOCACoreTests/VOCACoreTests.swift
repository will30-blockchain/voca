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
}
