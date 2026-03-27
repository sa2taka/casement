import AppKit
import Combine

@MainActor
final class SearchPanelViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [RankedWindow] = []
    @Published var selectedIndex: Int = 0
    @Published var isVisible: Bool = false

    private let windowTracker: WindowTracker
    private let searchIndex = SearchIndex()
    private let rankingEngine = RankingEngine()
    private let focusEngine = FocusEngine()
    private let usageStore: UsageStore
    private let preferencesStore: PreferencesStore
    private var cancellables = Set<AnyCancellable>()

    init(
        windowTracker: WindowTracker,
        usageStore: UsageStore,
        preferencesStore: PreferencesStore
    ) {
        self.windowTracker = windowTracker
        self.usageStore = usageStore
        self.preferencesStore = preferencesStore

        $query
            .debounce(for: .milliseconds(16), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.updateResults() }
            .store(in: &cancellables)
    }

    func openPanel() {
        query = ""
        selectedIndex = 0
        isVisible = true
        windowTracker.refreshSnapshot()
        rebuildIndex()
        updateResults()
    }

    func closePanel() {
        isVisible = false
    }

    func togglePanel() {
        if isVisible { closePanel() } else { openPanel() }
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
        guard selectedIndex >= 0, selectedIndex < results.count else {
            closePanel()
            return
        }

        let selected = results[selectedIndex]
        let capturedQuery = query
        closePanel()

        Task {
            do {
                try await focusEngine.focusWindow(selected.window)
                usageStore.recordSelection(
                    query: capturedQuery,
                    targetId: selected.window.id,
                    bundleId: selected.window.bundleId
                )
                usageStore.recordActivation(targetId: selected.window.id)
            } catch {
                openPanel()
            }
        }
    }

    private func rebuildIndex() {
        let prefs = preferencesStore.preferences
        let filtered = windowTracker.windows.values.filter { window in
            if preferencesStore.isExcluded(window.bundleId) { return false }
            if !prefs.includeMinimizedWindows && window.isMinimized { return false }
            return true
        }
        searchIndex.rebuild(from: Array(filtered))
    }

    private func updateResults() {
        let candidates = searchIndex.search(query: query)
        let context = makeRankingContext()
        let shortcuts = usageStore.records(for: TextNormalizer.normalize(query))
        results = rankingEngine.rank(candidates: candidates, context: context, shortcuts: shortcuts)
        selectedIndex = 0
    }

    private func makeRankingContext() -> RankingContext {
        let frontApp = NSWorkspace.shared.frontmostApplication
        return RankingContext(
            query: query,
            normalizedQuery: TextNormalizer.normalize(query),
            currentAppBundleId: frontApp?.bundleIdentifier,
            currentDisplayId: CGMainDisplayID(),
            currentSpaceHint: nil,
            now: Date()
        )
    }
}
