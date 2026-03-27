import Foundation

final class RankingEngine {
    func rank(
        candidates: [WindowRecord],
        context: RankingContext,
        shortcuts: [QuerySelectionRecord] = []
    ) -> [RankedWindow] {
        let shortcutMap = Dictionary(
            shortcuts.map { ($0.targetStableIdHash, $0) },
            uniquingKeysWith: { a, b in a.useCount >= b.useCount ? a : b }
        )
        return candidates
            .map { score($0, context: context, shortcutMap: shortcutMap) }
            .sorted { $0.score > $1.score }
    }

    private func score(
        _ window: WindowRecord,
        context: RankingContext,
        shortcutMap: [String: QuerySelectionRecord]
    ) -> RankedWindow {
        var totalScore: Double = 0
        var reasons: [MatchReason] = []

        let query = context.normalizedQuery

        if !query.isEmpty {
            let (textScore, textReasons) = textualScore(window: window, query: query)
            totalScore += textScore
            reasons.append(contentsOf: textReasons)
        }

        let (mruScore, mruReason) = usageScore(window: window, now: context.now)
        totalScore += mruScore
        if let reason = mruReason { reasons.append(reason) }

        let (ctxScore, ctxReasons) = contextScore(window: window, context: context)
        totalScore += ctxScore
        reasons.append(contentsOf: ctxReasons)

        let (penalty, penaltyReasons) = penaltyScore(window: window)
        totalScore += penalty
        reasons.append(contentsOf: penaltyReasons)

        if let shortcut = shortcutMap[window.id] {
            let bonus = min(Double(shortcut.useCount) * 10, 50)
            totalScore += bonus
            reasons.append(.learnedShortcut)
        }

        return RankedWindow(window: window, score: totalScore, matchReasons: reasons)
    }

    private func textualScore(window: WindowRecord, query: String) -> (Double, [MatchReason]) {
        var score: Double = 0
        var reasons: [MatchReason] = []

        let normalizedApp = TextNormalizer.normalize(window.appName)
        let normalizedTitle = TextNormalizer.normalize(window.title)
        let acronym = AcronymGenerator.generate(from: window.appName)

        if normalizedApp == query {
            score += 100; reasons.append(.exactAppMatch)
        } else if normalizedApp.hasPrefix(query) {
            score += 70; reasons.append(.prefixAppMatch)
        } else if normalizedApp.contains(query) {
            score += 40; reasons.append(.containsAppMatch)
        }

        if normalizedTitle == query {
            score += 90; reasons.append(.exactTitleMatch)
        } else if normalizedTitle.hasPrefix(query) {
            score += 60; reasons.append(.prefixTitleMatch)
        } else if normalizedTitle.contains(query) {
            score += 35; reasons.append(.containsTitleMatch)
        }

        if !acronym.isEmpty && acronym.hasPrefix(query) {
            score += 50; reasons.append(.acronymMatch)
        }

        if reasons.isEmpty {
            if TextNormalizer.isSubsequence(query, of: normalizedApp) || TextNormalizer.isSubsequence(query, of: normalizedTitle) {
                let ratio = Double(query.count) / Double(max(normalizedApp.count, normalizedTitle.count, 1))
                score += 20 + ratio * 25
                reasons.append(.subsequenceMatch)
            }
        }

        return (score, reasons)
    }

    private func usageScore(window: WindowRecord, now: Date) -> (Double, MatchReason?) {
        guard let lastActivated = window.lastActivatedAt else { return (0, nil) }
        let elapsed = now.timeIntervalSince(lastActivated)
        let bonus = 30 * exp(-elapsed / 300)
        return bonus > 0.5 ? (bonus, .recentUsage) : (0, nil)
    }

    private func contextScore(window: WindowRecord, context: RankingContext) -> (Double, [MatchReason]) {
        var score: Double = 0
        var reasons: [MatchReason] = []
        if let currentDisplay = context.currentDisplayId, window.displayId == currentDisplay {
            score += 8; reasons.append(.sameDisplay)
        }
        if let currentSpace = context.currentSpaceHint, window.spaceHint == currentSpace {
            score += 10; reasons.append(.sameSpace)
        }
        return (score, reasons)
    }

    private func penaltyScore(window: WindowRecord) -> (Double, [MatchReason]) {
        var score: Double = 0
        var reasons: [MatchReason] = []
        if window.isMinimized { score -= 8; reasons.append(.minimizedPenalty) }
        if window.isHiddenApp { score -= 5; reasons.append(.hiddenAppPenalty) }
        if window.subrole == "AXFloatingWindow" || window.subrole == "AXSystemDialog" {
            score -= 20; reasons.append(.utilityPenalty)
        }
        return (score, reasons)
    }

}
