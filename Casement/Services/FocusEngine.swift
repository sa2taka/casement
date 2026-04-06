import AppKit
import CoreGraphics

enum FocusError: Error {
    case windowNotFound
    case appNotRunning
    case accessibilityDenied
    case unminimizeFailed
    case focusFailed
}

@MainActor
final class FocusEngine {
    func focusWindow(_ record: WindowRecord) async throws {
        let app = NSRunningApplication(processIdentifier: record.pid)
        guard let app, !app.isTerminated else {
            throw FocusError.appNotRunning
        }

        let activated = app.activate()
        if !activated {
            try await Task.sleep(for: .milliseconds(100))
            guard app.activate() else {
                throw FocusError.focusFailed
            }
        }

        // When the title was filled from the Window menu (stableId has no
        // title fingerprint), use the Window menu to focus directly — it is
        // more reliable than kAXWindows for Electron apps (Cursor, VSCode).
        let titleFromMenu = record.stableId.titleFingerprint.isEmpty && !record.title.isEmpty
        let appElement = AXUIElementCreateApplication(record.pid)

        if titleFromMenu, pressWindowMenuItem(for: appElement, title: record.title) {
            try await Task.sleep(for: .milliseconds(200))
            return
        }

        if let axWindow = findAXWindow(for: record) {
            if record.isMinimized {
                let result = AXUIElementSetAttributeValue(
                    axWindow,
                    kAXMinimizedAttribute as CFString,
                    kCFBooleanFalse
                )
                if result != .success {
                    throw FocusError.unminimizeFailed
                }
                try await Task.sleep(for: .milliseconds(100))
            }

            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)

            try await Task.sleep(for: .milliseconds(100))
            let focused = checkFocused(axWindow)
            if !focused {
                app.activate()
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                try await Task.sleep(for: .milliseconds(100))
            }
        } else if !titleFromMenu {
            // Last resort: try Window menu even if we didn't detect it as menu-titled
            guard pressWindowMenuItem(for: appElement, title: record.title) else {
                throw FocusError.windowNotFound
            }
            try await Task.sleep(for: .milliseconds(200))
        } else {
            throw FocusError.windowNotFound
        }
    }

    private func findAXWindow(for record: WindowRecord) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(record.pid)

        var windows: [AXUIElement] = []
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let ws = windowsRef as? [AXUIElement], !ws.isEmpty {
            windows = ws
        } else {
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success {
                let element = focusedRef as! AXUIElement
                var roleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
                let role = roleRef as? String
                if role == nil || role == "AXWindow" {
                    windows = [element]
                }
            }
            if windows.isEmpty { return nil }
        }

        let targetFingerprint = record.stableId.titleFingerprint

        for window in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""
            let fingerprint = WindowStableID.titleFingerprint(from: title)
            if fingerprint == targetFingerprint {
                return window
            }
        }

        // Fallback: bounds matching
        for window in windows {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
            var pos = CGPoint.zero
            var size = CGSize.zero
            if let p = posRef as! AXValue? { AXValueGetValue(p, .cgPoint, &pos) }
            if let s = sizeRef as! AXValue? { AXValueGetValue(s, .cgSize, &size) }
            let bounds = CGRect(origin: pos, size: size)
            if WindowStableID.boundsFingerprint(from: bounds) == record.stableId.boundsFingerprint {
                return window
            }
        }

        if windows.count == 1, let window = windows.first {
            return window
        }

        return nil
    }

    /// Activate a window by pressing its entry in the app's Window menu.
    private func pressWindowMenuItem(for appElement: AXUIElement, title: String) -> Bool {
        guard !title.isEmpty else { return false }

        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef
        else { return false }

        var childrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &childrenRef)
        guard let menus = childrenRef as? [AXUIElement] else { return false }

        for menu in menus {
            var menuTitleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(menu, kAXTitleAttribute as CFString, &menuTitleRef)
            let menuTitle = menuTitleRef as? String ?? ""
            guard menuTitle == "Window" || menuTitle == "ウィンドウ" || menuTitle == "ウインドウ" else { continue }

            var subMenusRef: CFTypeRef?
            AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &subMenusRef)
            guard let subMenus = subMenusRef as? [AXUIElement], let firstSub = subMenus.first else { return false }

            var itemsRef: CFTypeRef?
            AXUIElementCopyAttributeValue(firstSub, kAXChildrenAttribute as CFString, &itemsRef)
            guard let items = itemsRef as? [AXUIElement] else { return false }

            for item in items {
                var itemTitleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &itemTitleRef)
                if (itemTitleRef as? String) == title {
                    return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
                }
            }
        }
        return false
    }

    private func checkFocused(_ window: AXUIElement) -> Bool {
        var focusedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXFocusedAttribute as CFString, &focusedRef)
        return focusedRef as? Bool ?? false
    }
}
