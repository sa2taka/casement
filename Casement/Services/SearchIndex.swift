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
        if entry.normalizedAppName.hasPrefix(query) { return true }
        if entry.normalizedAppName.contains(query) { return true }
        if entry.normalizedTitle.hasPrefix(query) { return true }
        if entry.normalizedTitle.contains(query) { return true }
        if entry.appTokens.contains(where: { $0.hasPrefix(query) }) { return true }
        if entry.titleTokens.contains(where: { $0.hasPrefix(query) }) { return true }
        if entry.acronym.hasPrefix(query) { return true }
        if isSubsequence(query, of: entry.normalizedAppName) { return true }
        if isSubsequence(query, of: entry.normalizedTitle) { return true }
        return false
    }

    private func isSubsequence(_ query: String, of target: String) -> Bool {
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex
        while queryIndex < query.endIndex && targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                queryIndex = query.index(after: queryIndex)
            }
            targetIndex = target.index(after: targetIndex)
        }
        return queryIndex == query.endIndex
    }
}
