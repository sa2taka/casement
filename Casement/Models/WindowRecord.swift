import AppKit
import CoreGraphics

struct WindowRecord: Identifiable, Sendable {
    let stableId: WindowStableID
    let cgWindowId: CGWindowID?
    let pid: pid_t
    let bundleId: String
    let appName: String

    var title: String
    var normalizedTitle: String

    var bounds: CGRect
    var layer: Int
    var alpha: Double

    var isOnScreen: Bool
    var isMinimized: Bool
    var isFocused: Bool
    var isFullscreen: Bool
    var isHiddenApp: Bool

    var displayId: CGDirectDisplayID?
    var spaceHint: String?

    var lastSeenAt: Date
    var lastActivatedAt: Date?

    var role: String?
    var subrole: String?

    var id: String { stableId.stringRepresentation }
}
