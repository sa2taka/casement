import Foundation

enum SearchResultItem: Identifiable, Sendable {
    case window(RankedWindow)
    case tab(TabRecord)

    var id: String {
        switch self {
        case .window(let w): return "w-\(w.id)"
        case .tab(let t): return "t-\(t.id)"
        }
    }

    var title: String {
        switch self {
        case .window(let w): return w.window.title.isEmpty ? w.window.appName : w.window.title
        case .tab(let t): return t.title
        }
    }

    var appName: String {
        switch self {
        case .window(let w): return w.window.appName
        case .tab(let t): return t.appName
        }
    }

    var bundleId: String {
        switch self {
        case .window(let w): return w.window.bundleId
        case .tab(let t): return t.bundleId
        }
    }

    var subtitle: String? {
        switch self {
        case .window: return nil
        case .tab(let t): return t.subtitle
        }
    }

    var kind: SearchTargetKind {
        switch self {
        case .window: return .window
        case .tab(let t): return t.kind
        }
    }

    var score: Double {
        switch self {
        case .window(let w): return w.score
        case .tab: return 0
        }
    }
}
