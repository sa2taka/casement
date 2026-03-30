import AppKit
import CoreGraphics

enum FocusError: Error {
    case windowNotFound
    case appNotRunning
    case accessibilityDenied
    case axElementUnavailable
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

        let axWindow = try findAXWindow(for: record)

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
    }

    private func findAXWindow(for record: WindowRecord) throws -> AXUIElement {
        let appElement = AXUIElementCreateApplication(record.pid)

        // Some apps (e.g. Chrome, Cmux) return empty kAXWindows when not active.
        // Fall back to kAXFocusedWindow.
        var windows: [AXUIElement] = []
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let ws = windowsRef as? [AXUIElement], !ws.isEmpty {
            windows = ws
        } else {
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success {
                return focusedRef as! AXUIElement
            }
            throw FocusError.axElementUnavailable
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

        throw FocusError.windowNotFound
    }

    private func checkFocused(_ window: AXUIElement) -> Bool {
        var focusedRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXFocusedAttribute as CFString, &focusedRef)
        return focusedRef as? Bool ?? false
    }
}
