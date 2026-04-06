import Foundation

enum SearchTargetKind: String, Sendable {
    case window
    case chromeTab
    case terminalTab
    case notionTab
}

protocol SearchTarget: Sendable {
    var id: String { get }
    var kind: SearchTargetKind { get }
    var title: String { get }
    var appName: String { get }
    var normalizedTitle: String { get }
    var lastActivatedAt: Date? { get }
}

extension WindowRecord: SearchTarget {
    var kind: SearchTargetKind { .window }
}
