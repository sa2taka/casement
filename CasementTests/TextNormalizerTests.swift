import Testing
@testable import Casement

@Suite("TextNormalizer")
struct TextNormalizerTests {
    @Test("lowercases input")
    func lowercases() {
        #expect(TextNormalizer.normalize("Hello World") == "hello world")
    }

    @Test("compresses whitespace")
    func compressesWhitespace() {
        #expect(TextNormalizer.normalize("hello   world") == "hello world")
    }

    @Test("trims leading and trailing whitespace")
    func trims() {
        #expect(TextNormalizer.normalize("  hello  ") == "hello")
    }

    @Test("folds diacritics")
    func foldsDiacritics() {
        #expect(TextNormalizer.normalize("café résumé") == "cafe resume")
    }

    @Test("normalizes fullwidth to halfwidth")
    func fullwidthToHalfwidth() {
        #expect(TextNormalizer.normalize("Ｈｅｌｌｏ") == "hello")
    }

    @Test("strips common noise characters")
    func stripsNoise() {
        #expect(TextNormalizer.normalize("hello — world | test") == "hello world test")
    }

    @Test("handles empty string")
    func empty() {
        #expect(TextNormalizer.normalize("") == "")
    }

    @Test("tokenizes into words")
    func tokenizes() {
        let tokens = TextNormalizer.tokenize("Visual Studio Code - main.swift")
        #expect(tokens == ["visual", "studio", "code", "main.swift"])
    }
}
