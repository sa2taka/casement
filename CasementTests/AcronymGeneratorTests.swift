import Testing
@testable import Casement

@Suite("AcronymGenerator")
struct AcronymGeneratorTests {
    @Test("generates from multi-word app name")
    func multiWord() {
        #expect(AcronymGenerator.generate(from: "Visual Studio Code") == "vsc")
    }

    @Test("generates from two-word name")
    func twoWord() {
        #expect(AcronymGenerator.generate(from: "Google Chrome") == "gc")
    }

    @Test("single word returns first character")
    func singleWord() {
        #expect(AcronymGenerator.generate(from: "Safari") == "s")
    }

    @Test("handles empty string")
    func empty() {
        #expect(AcronymGenerator.generate(from: "") == "")
    }

    @Test("ignores noise words in titles")
    func titleWithNoise() {
        #expect(AcronymGenerator.generate(from: "GitHub - Pull Request") == "gpr")
    }

    @Test("handles mixed case")
    func mixedCase() {
        #expect(AcronymGenerator.generate(from: "IntelliJ IDEA") == "ii")
    }
}
