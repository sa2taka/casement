import CoreGraphics
import Foundation
@testable import Casement

enum TestFixtures {
    static func windowRecord(
        pid: pid_t = 1234,
        bundleId: String = "com.apple.Safari",
        appName: String = "Safari",
        title: String = "Apple - Start",
        isMinimized: Bool = false,
        isFocused: Bool = false,
        lastActivatedAt: Date? = nil
    ) -> WindowRecord {
        let stableId = WindowStableID(
            pid: pid,
            axIdentifier: nil,
            titleFingerprint: WindowStableID.titleFingerprint(from: title),
            boundsFingerprint: "0,0,800,600",
            cgWindowId: nil
        )
        return WindowRecord(
            stableId: stableId,
            cgWindowId: nil,
            pid: pid,
            bundleId: bundleId,
            appName: appName,
            title: title,
            normalizedTitle: TextNormalizer.normalize(title),
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            layer: 0,
            alpha: 1.0,
            isOnScreen: true,
            isMinimized: isMinimized,
            isFocused: isFocused,
            isFullscreen: false,
            isHiddenApp: false,
            displayId: CGMainDisplayID(),
            spaceHint: nil,
            lastSeenAt: Date(),
            lastActivatedAt: lastActivatedAt,
            role: "AXWindow",
            subrole: "AXStandardWindow"
        )
    }
}
