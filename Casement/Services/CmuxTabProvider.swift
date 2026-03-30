import AppKit
import ApplicationServices

final class CmuxTabProvider: TabProvider, @unchecked Sendable {
    let supportedBundleIds: Set<String> = ["com.cmuxterm.app"]

    func enumerateTabs() async -> [TabRecord] {
        await MainActor.run { enumerateTabsSync() }
    }

    func activateTab(_ tab: TabRecord) async {
        await MainActor.run { activateTabSync(tab) }
    }

    private func enumerateTabsSync() -> [TabRecord] {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.cmuxterm.app" })
        else { return [] }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else { return [] }

        var tabs: [TabRecord] = []

        for (wi, window) in windows.enumerated() {
            let workspaces = findWorkspaceElements(in: window)
            for (ti, ws) in workspaces.enumerated() {
                var descRef: CFTypeRef?
                AXUIElementCopyAttributeValue(ws, kAXDescriptionAttribute as CFString, &descRef)
                guard let desc = descRef as? String else { continue }

                // desc format: "name、ワークスペース N中M"
                let name = desc.components(separatedBy: "、ワークスペース").first?
                    .trimmingCharacters(in: .whitespaces) ?? desc

                tabs.append(TabRecord(
                    id: "cmux-\(wi)-\(ti)",
                    kind: .terminalTab,
                    appName: "cmux",
                    bundleId: "com.cmuxterm.app",
                    title: name,
                    subtitle: "workspace \(ti + 1)",
                    windowIndex: wi,
                    tabIndex: ti
                ))
            }
        }

        return tabs
    }

    private func activateTabSync(_ tab: TabRecord) {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == "com.cmuxterm.app" })
        else { return }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement],
              tab.windowIndex < windows.count
        else { return }

        let window = windows[tab.windowIndex]
        let workspaces = findWorkspaceElements(in: window)
        guard tab.tabIndex < workspaces.count else { return }

        AXUIElementPerformAction(workspaces[tab.tabIndex], kAXPressAction as CFString)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        app.activate()
    }

    // Cmux workspaces: AXWindow > AXGroup > AXScrollArea > AXOpaqueProviderGroup > AXOpaqueProviderList > children
    private func findWorkspaceElements(in element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
        guard depth < 5 else { return [] }

        var subroleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
        let subrole = subroleRef as? String ?? ""

        if subrole == "AXOpaqueProviderList" {
            var childrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                  let children = childrenRef as? [AXUIElement]
            else { return [] }
            return children
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement]
        else { return [] }

        // Only recurse into structural containers, not text areas or buttons
        return children.filter { child in
            var r: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &r)
            let role = r as? String ?? ""
            return role == "AXGroup" || role == "AXScrollArea" || role == "AXOpaqueProviderGroup"
        }.flatMap { findWorkspaceElements(in: $0, depth: depth + 1) }
    }
}
