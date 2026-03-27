import Foundation

enum AcronymGenerator {
    private static let noiseWords: Set<String> = ["-", "–", "—", "|", "·"]

    static func generate(from text: String) -> String {
        guard !text.isEmpty else { return "" }

        let words = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && !noiseWords.contains($0) }

        guard !words.isEmpty else { return "" }

        let acronym = words.compactMap { $0.first }
            .map { String($0).lowercased() }
            .joined()

        return acronym
    }
}
