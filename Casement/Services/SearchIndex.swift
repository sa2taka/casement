import Foundation

struct IndexedWindow: Sendable {
    let stableId: WindowStableID
    let appName: String
    let normalizedAppName: String
    let title: String
    let normalizedTitle: String
    let acronym: String
    let appTokens: [String]
    let titleTokens: [String]
    let original: WindowRecord
}

final class SearchIndex {
    private var entries: [IndexedWindow] = []

    func rebuild(from windows: [WindowRecord]) {
        entries = windows.map { window in
            IndexedWindow(
                stableId: window.stableId,
                appName: window.appName,
                normalizedAppName: TextNormalizer.normalize(window.appName),
                title: window.title,
                normalizedTitle: TextNormalizer.normalize(window.title),
                acronym: AcronymGenerator.generate(from: window.appName),
                appTokens: TextNormalizer.tokenize(window.appName),
                titleTokens: TextNormalizer.tokenize(window.title),
                original: window
            )
        }
    }

    func search(query: String) -> [WindowRecord] {
        guard !query.isEmpty else {
            return entries.map(\.original)
        }

        let normalizedQuery = TextNormalizer.normalize(query)
        guard !normalizedQuery.isEmpty else {
            return entries.map(\.original)
        }

        return entries
            .filter { matches($0, query: normalizedQuery) }
            .map(\.original)
    }

    private func matches(_ entry: IndexedWindow, query: String) -> Bool {
        if matchesSingleToken(entry, query: query) { return true }

        // Multi-token: split query into words, require ALL to match somewhere
        let tokens = query.components(separatedBy: " ").filter { !$0.isEmpty }
        guard tokens.count > 1 else { return false }

        return tokens.allSatisfy { token in
            matchesSingleToken(entry, query: token)
        }
    }

    private func matchesSingleToken(_ entry: IndexedWindow, query: String) -> Bool {
        if entry.normalizedAppName.hasPrefix(query) { return true }
        if entry.normalizedAppName.contains(query) { return true }
        if entry.normalizedTitle.hasPrefix(query) { return true }
        if entry.normalizedTitle.contains(query) { return true }
        if entry.appTokens.contains(where: { $0.hasPrefix(query) }) { return true }
        if entry.titleTokens.contains(where: { $0.hasPrefix(query) }) { return true }
        if entry.acronym.hasPrefix(query) { return true }
        if TextNormalizer.isSubsequence(query, of: entry.normalizedAppName) { return true }
        if TextNormalizer.isSubsequence(query, of: entry.normalizedTitle) { return true }
        return false
    }
}
