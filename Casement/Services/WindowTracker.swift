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
    private weak var preferencesStore: PreferencesStore?

    func configure(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
    }

    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true
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

        // Add AX-only windows (e.g. windows on other Spaces not reported by CG)
        addAXOnlyWindows(&updated, appsByPid: appsByPid)

        // Only keep windows confirmed as real windows by AX enrichment
        updated = updated.filter { _, record in
            isRealWindow(record)
        }

        windows = updated
        snapshotVersion += 1
    }

    // MARK: - CGWindowList

    private func fetchCGWindows() -> [[String: Any]] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements],
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
            // Skip non-GUI apps — AX queries to background services are slow/hang
            guard let app = appsByPid[pid],
                  app.activationPolicy == .regular
            else { continue }

            let appElement = AXUIElementCreateApplication(pid)
            var axWindows: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(
                appElement, kAXWindowsAttribute as CFString, &axWindows
            )
            guard result == .success, let windowArray = axWindows as? [AXUIElement] else { continue }

            var matchedKeys: Set<WindowStableID> = []

            for axWindow in windowArray {
                let axTitle = axAttribute(axWindow, kAXTitleAttribute) as? String ?? ""
                let axRole = axAttribute(axWindow, kAXRoleAttribute) as? String
                let axSubrole = axAttribute(axWindow, kAXSubroleAttribute) as? String
                let isMinimized = axAttribute(axWindow, kAXMinimizedAttribute) as? Bool ?? false
                let isFocused = axAttribute(axWindow, kAXFocusedAttribute) as? Bool ?? false
                let isFullscreen = axAttribute(axWindow, "AXFullScreen") as? Bool ?? false

                let matchKey = findMatchingKey(
                    for: axWindow,
                    axTitle: axTitle,
                    pid: pid,
                    in: records,
                    excluding: matchedKeys
                )

                if let key = matchKey, var record = records[key] {
                    matchedKeys.insert(key)
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

    /// Add windows discovered by AX that have no corresponding CG entry
    /// (e.g. windows on other Spaces that CGWindowList doesn't report).
    private func addAXOnlyWindows(
        _ records: inout [WindowStableID: WindowRecord],
        appsByPid: [pid_t: NSRunningApplication]
    ) {
        let existingPids = Set(records.values.map(\.pid))

        for app in appsByPid.values where app.activationPolicy == .regular {
            let pid = app.processIdentifier
            // Skip if we already have windows for this PID
            if existingPids.contains(pid) { continue }
            if app.bundleIdentifier == ownBundleId { continue }
            if let prefs = preferencesStore, prefs.isExcluded(app.bundleIdentifier ?? "") { continue }

            let appElement = AXUIElementCreateApplication(pid)
            var windowArray: [AXUIElement] = []
            var axWindows: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &axWindows) == .success,
               let ws = axWindows as? [AXUIElement], !ws.isEmpty {
                windowArray = ws
            } else {
                // Some apps (e.g. Cmux) return empty kAXWindows when inactive.
                // Fall back to kAXFocusedWindow.
                var focusedRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success {
                    windowArray = [focusedRef as! AXUIElement]
                }
            }
            guard !windowArray.isEmpty else { continue }

            for axWindow in windowArray {
                let title = axAttribute(axWindow, kAXTitleAttribute) as? String ?? ""
                let role = axAttribute(axWindow, kAXRoleAttribute) as? String
                let subrole = axAttribute(axWindow, kAXSubroleAttribute) as? String
                let isMinimized = axAttribute(axWindow, kAXMinimizedAttribute) as? Bool ?? false
                let isFocused = axAttribute(axWindow, kAXFocusedAttribute) as? Bool ?? false
                let isFullscreen = axAttribute(axWindow, "AXFullScreen") as? Bool ?? false

                let bounds = axWindowBounds(axWindow) ?? .zero
                let stableId = WindowStableID(
                    pid: pid,
                    axIdentifier: nil,
                    titleFingerprint: WindowStableID.titleFingerprint(from: title),
                    boundsFingerprint: WindowStableID.boundsFingerprint(from: bounds)
                )

                let record = WindowRecord(
                    stableId: stableId,
                    cgWindowId: nil,
                    pid: pid,
                    bundleId: app.bundleIdentifier ?? "",
                    appName: app.localizedName ?? "",
                    title: title,
                    normalizedTitle: TextNormalizer.normalize(title),
                    bounds: bounds,
                    layer: 0,
                    alpha: 1.0,
                    isOnScreen: false,
                    isMinimized: isMinimized,
                    isFocused: isFocused,
                    isFullscreen: isFullscreen,
                    isHiddenApp: app.isHidden,
                    displayId: nil,
                    spaceHint: nil,
                    lastSeenAt: Date(),
                    lastActivatedAt: windows[stableId]?.lastActivatedAt,
                    role: role,
                    subrole: subrole
                )

                if shouldExclude(record) { continue }
                records[stableId] = record
            }
        }
    }

    private func findMatchingKey(
        for axWindow: AXUIElement,
        axTitle: String,
        pid: pid_t,
        in records: [WindowStableID: WindowRecord],
        excluding matched: Set<WindowStableID>
    ) -> WindowStableID? {
        let pidKeys = records.keys.filter { $0.pid == pid && !matched.contains($0) }

        // Strategy 1: Match by title fingerprint (both non-empty)
        let titleFP = WindowStableID.titleFingerprint(from: axTitle)
        if !titleFP.isEmpty {
            if let key = pidKeys.first(where: { $0.titleFingerprint == titleFP }) {
                return key
            }
        }

        // Strategy 2: Match by bounds
        let axBounds = axWindowBounds(axWindow)
        if let axBounds {
            let axBoundsFP = WindowStableID.boundsFingerprint(from: axBounds)
            if let key = pidKeys.first(where: { $0.boundsFingerprint == axBoundsFP }) {
                return key
            }
        }

        // Strategy 3: Match remaining CG window with empty title to this AX window
        if let key = pidKeys.first(where: { $0.titleFingerprint.isEmpty }) {
            return key
        }

        return nil
    }

    private func axWindowBounds(_ element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)

        var position = CGPoint.zero
        var size = CGSize.zero

        guard let positionRef = positionRef as! AXValue?,
              let sizeRef = sizeRef as! AXValue?
        else { return nil }

        AXValueGetValue(positionRef, .cgPoint, &position)
        AXValueGetValue(sizeRef, .cgSize, &size)

        return CGRect(origin: position, size: size)
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
        if let prefs = preferencesStore, prefs.isExcluded(record.bundleId) { return true }
        return false
    }

    private func isRealWindow(_ record: WindowRecord) -> Bool {
        // Must have been enriched by AX (role is set)
        guard let role = record.role else { return false }
        // Only standard windows (not dialogs, floating panels, etc.)
        guard role == "AXWindow" else { return false }
        if let subrole = record.subrole,
           subrole != "AXStandardWindow" && subrole != "AXDialog" {
            return false
        }
        return true
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
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
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
