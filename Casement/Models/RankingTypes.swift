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

enum MatchReason: Sendable, CustomStringConvertible {
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

    var description: String {
        switch self {
        case .exactAppMatch: return "app"
        case .prefixAppMatch: return "app prefix"
        case .containsAppMatch: return "app match"
        case .exactTitleMatch: return "title"
        case .prefixTitleMatch: return "title prefix"
        case .containsTitleMatch: return "title match"
        case .acronymMatch: return "acronym"
        case .subsequenceMatch: return "fuzzy"
        case .recentUsage: return "recent"
        case .sameDisplay: return "display"
        case .sameSpace: return "space"
        case .learnedShortcut: return "learned"
        case .minimizedPenalty: return "minimized"
        case .hiddenAppPenalty: return "hidden"
        case .utilityPenalty: return "utility"
        }
    }
}
