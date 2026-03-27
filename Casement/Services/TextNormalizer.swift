import Foundation

enum TextNormalizer {
    private static let noisePattern: NSRegularExpression = {
        try! NSRegularExpression(pattern: "[\\-—–|•·]", options: [])
    }()

    static func normalize(_ input: String) -> String {
        guard !input.isEmpty else { return "" }

        var result = input

        // Fullwidth -> halfwidth (ASCII range: FF01-FF5E -> 0021-007E)
        result = result.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? result

        // Diacritic folding
        result = result.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

        // Strip noise characters
        result = noisePattern.stringByReplacingMatches(
            in: result,
            range: NSRange(result.startIndex..., in: result),
            withTemplate: " "
        )

        // Compress whitespace and trim
        result = result.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        return result
    }

    static func tokenize(_ input: String) -> [String] {
        let normalized = normalize(input)
        guard !normalized.isEmpty else { return [] }
        return normalized.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
    }
}
