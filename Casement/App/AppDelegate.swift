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
    private var cancellables = Set<AnyCancellable>()
    private var localMonitor: Any?

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
        hotkeyManager.register { [weak self] in
            self?.searchPanelViewModel.togglePanel()
        }
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
    }

    private func hidePanel() {
        removeKeyMonitor()
        panelWindow?.orderOut(nil)
    }

    private func installKeyMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch Int(event.keyCode) {
            case 53: self.searchPanelViewModel.closePanel(); return nil
            case 125: self.searchPanelViewModel.moveSelectionDown(); return nil
            case 126: self.searchPanelViewModel.moveSelectionUp(); return nil
            case 36: self.searchPanelViewModel.commitSelection(); return nil
            default: return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
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
        menu.addItem(NSMenuItem(title: "About Casement", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Casement", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
