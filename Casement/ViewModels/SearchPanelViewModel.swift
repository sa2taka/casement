import AppKit
import Combine

@MainActor
final class SearchPanelViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [RankedWindow] = []
    @Published var selectedIndex: Int = 0
    @Published var isVisible: Bool = false

    func openPanel() {
        query = ""
        results = []
        selectedIndex = 0
        isVisible = true
    }

    func closePanel() {
        isVisible = false
    }

    func togglePanel() {
        if isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    func moveSelectionUp() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveSelectionDown() {
        guard selectedIndex < results.count - 1 else { return }
        selectedIndex += 1
    }

    func commitSelection() {
        // Will be wired to FocusEngine later
        closePanel()
    }
}
