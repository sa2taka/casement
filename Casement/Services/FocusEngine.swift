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
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
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
