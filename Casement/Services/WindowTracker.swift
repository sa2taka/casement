import AppKit
import Combine
import CoreGraphics

@MainActor
final class WindowTracker: ObservableObject {
    @Published private(set) var windows: [WindowStableID: WindowRecord] = [:]
    @Published private(set) var snapshotVersion: Int = 0

    private nonisolated(unsafe) var workspaceObservers: [NSObjectProtocol] = []
    private nonisolated(unsafe) var pollTimer: Timer?
    private let ownBundleId = Bundle.main.bundleIdentifier ?? "com.casement.app"

    func start() {
        observeWorkspace()
        startPolling()
        refreshSnapshot()
    }

    func stop() {
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func refreshSnapshot() {
        let cgWindows = fetchCGWindows()
        let runningApps = NSWorkspace.shared.runningApplications
        let appsByPid = Dictionary(uniqueKeysWithValues: runningApps.map { ($0.processIdentifier, $0) })

        var updated: [WindowStableID: WindowRecord] = [:]

        for cgWindow in cgWindows {
            guard let record = buildWindowRecord(from: cgWindow, appsByPid: appsByPid) else { continue }
            if shouldExclude(record) { continue }

            if let existing = windows[record.stableId] {
                var merged = record
                merged.lastActivatedAt = existing.lastActivatedAt
                updated[record.stableId] = merged
            } else {
                updated[record.stableId] = record
            }
        }

        enrichWithAccessibility(&updated, appsByPid: appsByPid)

        windows = updated
        snapshotVersion += 1
    }

    // MARK: - CGWindowList

    private func fetchCGWindows() -> [[String: Any]] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }
        return list
    }

    private func buildWindowRecord(
        from info: [String: Any],
        appsByPid: [pid_t: NSRunningApplication]
    ) -> WindowRecord? {
        guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
              let layer = info[kCGWindowLayer as String] as? Int,
              layer == 0
        else { return nil }

        let app = appsByPid[pid]
        let bundleId = app?.bundleIdentifier ?? ""
        let appName = app?.localizedName ?? (info[kCGWindowOwnerName as String] as? String ?? "")

        guard !bundleId.isEmpty || !appName.isEmpty else { return nil }

        let title = info[kCGWindowName as String] as? String ?? ""
        let alpha = info[kCGWindowAlpha as String] as? Double ?? 1.0
        let windowNumber = info[kCGWindowNumber as String] as? CGWindowID

        let boundsDict = info[kCGWindowBounds as String] as? [String: Any]
        let bounds = boundsDict.flatMap { dict -> CGRect? in
            guard let x = dict["X"] as? CGFloat,
                  let y = dict["Y"] as? CGFloat,
                  let w = dict["Width"] as? CGFloat,
                  let h = dict["Height"] as? CGFloat
            else { return nil }
            return CGRect(x: x, y: y, width: w, height: h)
        } ?? .zero

        let isOnScreen = info[kCGWindowIsOnscreen as String] as? Bool ?? true

        let stableId = WindowStableID(
            pid: pid,
            axIdentifier: nil,
            titleFingerprint: WindowStableID.titleFingerprint(from: title),
            boundsFingerprint: WindowStableID.boundsFingerprint(from: bounds)
        )

        return WindowRecord(
            stableId: stableId,
            cgWindowId: windowNumber,
            pid: pid,
            bundleId: bundleId,
            appName: appName,
            title: title,
            normalizedTitle: TextNormalizer.normalize(title),
            bounds: bounds,
            layer: layer,
            alpha: alpha,
            isOnScreen: isOnScreen,
            isMinimized: false,
            isFocused: false,
            isFullscreen: false,
            isHiddenApp: app?.isHidden ?? false,
            displayId: displayForBounds(bounds),
            spaceHint: nil,
            lastSeenAt: Date(),
            lastActivatedAt: nil,
            role: nil,
            subrole: nil
        )
    }

    // MARK: - Accessibility enrichment

    private func enrichWithAccessibility(
        _ records: inout [WindowStableID: WindowRecord],
        appsByPid: [pid_t: NSRunningApplication]
    ) {
        let pidGroups = Dictionary(grouping: records.values, by: \.pid)

        for (pid, _) in pidGroups {
            let appElement = AXUIElementCreateApplication(pid)
            var axWindows: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                appElement, kAXWindowsAttribute as CFString, &axWindows
            )
            guard result == .success, let windowArray = axWindows as? [AXUIElement] else { continue }

            for axWindow in windowArray {
                let axTitle = axAttribute(axWindow, kAXTitleAttribute) as? String ?? ""
                let axRole = axAttribute(axWindow, kAXRoleAttribute) as? String
                let axSubrole = axAttribute(axWindow, kAXSubroleAttribute) as? String
                let isMinimized = axAttribute(axWindow, kAXMinimizedAttribute) as? Bool ?? false
                let isFocused = axAttribute(axWindow, kAXFocusedAttribute) as? Bool ?? false
                let isFullscreen = axAttribute(axWindow, "AXFullScreen") as? Bool ?? false

                let fingerprint = WindowStableID.titleFingerprint(from: axTitle)
                let matchKey = records.keys.first { key in
                    key.pid == pid && key.titleFingerprint == fingerprint
                }

                if let key = matchKey, var record = records[key] {
                    if !axTitle.isEmpty {
                        record.title = axTitle
                    }
                    record.normalizedTitle = TextNormalizer.normalize(record.title)
                    record.isMinimized = isMinimized
                    record.isFocused = isFocused
                    record.isFullscreen = isFullscreen
                    record.role = axRole
                    record.subrole = axSubrole

                    if isFocused {
                        record.lastActivatedAt = Date()
                    }
                    records[key] = record
                }
            }
        }
    }

    private func axAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return value
    }

    // MARK: - Filtering

    private func shouldExclude(_ record: WindowRecord) -> Bool {
        if record.bundleId == ownBundleId { return true }
        if record.alpha < 0.01 { return true }
        if record.bounds.width < 50 || record.bounds.height < 50 { return true }
        return false
    }

    // MARK: - Display resolution

    private func displayForBounds(_ bounds: CGRect) -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        var displayId: CGDirectDisplayID = 0
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let rect = CGRect(origin: center, size: CGSize(width: 1, height: 1))
        CGGetDisplaysWithRect(rect, 1, &displayId, &displayCount)
        return displayCount > 0 ? displayId : nil
    }

    // MARK: - Observation

    private func observeWorkspace() {
        let nc = NSWorkspace.shared.notificationCenter
        let events: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
        ]
        for event in events {
            let observer = nc.addObserver(forName: event, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshSnapshot()
                }
            }
            workspaceObservers.append(observer)
        }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshSnapshot()
            }
        }
    }

    deinit {
        pollTimer?.invalidate()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }
}
