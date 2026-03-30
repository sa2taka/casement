import Foundation
import Testing
@testable import Casement

@MainActor
@Suite("SearchPanelViewModel")
struct SearchPanelViewModelTests {
    @Test("when panel opens without accessibility permission, should set denied state once")
    func openPanelWithDeniedPermission() {
        let viewModel = makeViewModel(permissionDenied: true)

        viewModel.openPanel()

        #expect(viewModel.isVisible)
        #expect(viewModel.permissionDenied)
        #expect(viewModel.results.isEmpty)
    }

    @Test("when panel closes, should reset denied state")
    func closePanelResetsDeniedPermission() {
        let viewModel = makeViewModel(permissionDenied: true)
        viewModel.openPanel()

        viewModel.closePanel()

        #expect(!viewModel.isVisible)
        #expect(!viewModel.permissionDenied)
    }

    @Test("togglePanel opens with denied, then closes and resets")
    func togglePanelWithDeniedPermission() {
        let viewModel = makeViewModel(permissionDenied: true)

        viewModel.togglePanel()
        #expect(viewModel.isVisible)
        #expect(viewModel.permissionDenied)

        viewModel.togglePanel()
        #expect(!viewModel.isVisible)
        #expect(!viewModel.permissionDenied)
    }

    @Test("when panel reopens with granted permission, should clear stale denied state")
    func openPanelClearsStaleDeniedPermission() {
        let state = MutablePermissionState(denied: true)
        let viewModel = makeViewModel(permissionDeniedProvider: { state.denied })
        viewModel.openPanel()
        state.denied = false

        viewModel.openPanel()

        #expect(!viewModel.permissionDenied)
    }

    private func makeViewModel(
        permissionDenied: Bool
    ) -> SearchPanelViewModel {
        makeViewModel(permissionDeniedProvider: { permissionDenied })
    }

    private func makeViewModel(
        permissionDeniedProvider: @escaping @MainActor () -> Bool
    ) -> SearchPanelViewModel {
        SearchPanelViewModel(
            windowTracker: WindowTracker(),
            usageStore: UsageStore(fileURL: tempURL()),
            preferencesStore: PreferencesStore(),
            tabProviders: [EmptyTabProvider()],
            permissionDeniedProvider: permissionDeniedProvider
        )
    }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("casement-search-panel-\(UUID().uuidString).json")
    }
}

@MainActor
private final class MutablePermissionState {
    var denied: Bool
    init(denied: Bool) { self.denied = denied }
}

private struct EmptyTabProvider: TabProvider {
    let supportedBundleIds: Set<String> = []

    func enumerateTabs() async -> [TabRecord] {
        []
    }

    func activateTab(_ tab: TabRecord) async {}
}
