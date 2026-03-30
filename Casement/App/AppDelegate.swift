import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    let permissionManager = PermissionManager()
    private let hotkeyManager = HotkeyManager()
    let windowTracker = WindowTracker()
    let preferencesStore = PreferencesStore()
    let usageStore = UsageStore()
    private(set) lazy var searchPanelViewModel = SearchPanelViewModel(
        windowTracker: windowTracker,
        usageStore: usageStore,
        preferencesStore: preferencesStore
    )
    private var panelWindow: SearchPanelWindow?
    private var preferencesWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var localMonitor: Any?
    private var globalMouseMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        windowTracker.configure(preferencesStore: preferencesStore)
        permissionManager.checkAccessibility()
        if permissionManager.state != .granted {
            permissionManager.requestAccessibilityIfNeeded()
        }
        startTrackerIfPermitted()
        setupHotkey()
        observePanel()
    }

    private func startTrackerIfPermitted() {
        if permissionManager.state == .granted {
            windowTracker.start()
        }
        permissionManager.$state
            .removeDuplicates()
            .sink { [weak self] state in
                if state == .granted {
                    self?.windowTracker.start()
                }
            }
            .store(in: &cancellables)
    }

    private func setupHotkey() {
        hotkeyManager.register(shortcut: preferencesStore.preferences.hotkeyShortcut) { [weak self] in
            guard let self else { return }
            guard self.permissionManager.state == .granted else { return }
            self.searchPanelViewModel.togglePanel()
        }
        preferencesStore.$preferences
            .map(\.hotkeyShortcut)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] shortcut in
                self?.hotkeyManager.updateHotkey(shortcut)
            }
            .store(in: &cancellables)
    }

    private func observePanel() {
        searchPanelViewModel.$isVisible
            .removeDuplicates()
            .sink { [weak self] visible in
                guard let self else { return }
                if visible { self.showPanel() } else { self.hidePanel() }
            }
            .store(in: &cancellables)
    }

    private func showPanel() {
        if panelWindow == nil {
            panelWindow = SearchPanelWindow(viewModel: searchPanelViewModel)
        }
        panelWindow?.centerOnScreen()
        panelWindow?.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        installGlobalMouseMonitor()
    }

    private func hidePanel() {
        removeKeyMonitor()
        removeGlobalMouseMonitor()
        panelWindow?.orderOut(nil)
    }

    private func installKeyMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let keyCode = Int(event.keyCode)
            let ctrl = event.modifierFlags.contains(.control)

            switch (keyCode, ctrl) {
            case (53, _):  // Esc
                if self.searchPanelViewModel.showingActions {
                    self.searchPanelViewModel.showingActions = false
                } else {
                    self.searchPanelViewModel.closePanel()
                }
                return nil
            case (125, _), (45, true):  // ↓ or Ctrl+N
                self.searchPanelViewModel.moveSelectionDown(); return nil
            case (126, _), (35, true):  // ↑ or Ctrl+P
                self.searchPanelViewModel.moveSelectionUp(); return nil
            case (36, _):  // Enter
                self.searchPanelViewModel.commitSelection(); return nil
            case (48, _):  // Tab
                self.searchPanelViewModel.toggleActions(); return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func installGlobalMouseMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panelWindow else { return }
            let screenPoint = event.locationInWindow
            if !panel.frame.contains(screenPoint) {
                self.searchPanelViewModel.closePanel()
            }
        }
    }

    private func removeGlobalMouseMonitor() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.3.group",
                accessibilityDescription: "Casement"
            )
        }
        let menu = NSMenu()
        let searchItem = NSMenuItem(title: "Search Windows (\(preferencesStore.preferences.hotkeyShortcut.displayString))", action: #selector(toggleSearch), keyEquivalent: "")
        menu.addItem(searchItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About Casement", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Casement", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func openPreferences() {
        if let existing = preferencesWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Casement Preferences"
        window.contentView = NSHostingView(
            rootView: PreferencesView(
                preferencesStore: preferencesStore,
                usageStore: usageStore
            )
        )
        window.center()
        window.isReleasedWhenClosed = false
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func toggleSearch() {
        guard permissionManager.state == .granted else { return }
        searchPanelViewModel.togglePanel()
    }
}
