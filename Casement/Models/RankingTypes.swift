import CoreGraphics
import Foundation

struct RankingContext: Sendable {
    let query: String
    let normalizedQuery: String
    let currentAppBundleId: String?
    let currentDisplayId: CGDirectDisplayID?
    let currentSpaceHint: String?
    let now: Date
}

struct RankedWindow: Identifiable, Sendable {
    let window: WindowRecord
    let score: Double
    let matchReasons: [MatchReason]

    var id: String { window.id }
}

enum MatchReason: Sendable {
    case exactAppMatch
    case prefixAppMatch
    case containsAppMatch
    case exactTitleMatch
    case prefixTitleMatch
    case containsTitleMatch
    case acronymMatch
    case subsequenceMatch
    case recentUsage
    case sameDisplay
    case sameSpace
    case learnedShortcut
    case minimizedPenalty
    case hiddenAppPenalty
    case utilityPenalty
}
