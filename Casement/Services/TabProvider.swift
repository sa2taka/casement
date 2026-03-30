import AppKit

struct TabRecord: Sendable {
    let id: String
    let kind: SearchTargetKind
    let appName: String
    let bundleId: String
    let title: String
    let subtitle: String
    let windowId: String
    let tabIndex: Int
}

protocol TabProvider: Sendable {
    var supportedBundleIds: Set<String> { get }
    func enumerateTabs() async -> [TabRecord]
    func activateTab(_ tab: TabRecord) async
}
