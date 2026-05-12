import XCTest
@testable import VoiceTypeCore

final class VoiceTypeCoreTests: XCTestCase {
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
}
