import AppKit
import Combine

enum WindowAction: String, CaseIterable, Identifiable {
    case excludeApp = "Exclude this app"
    case close = "Cancel"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .excludeApp: return "eye.slash"
        case .close: return "xmark"
        }
    }
}

@MainActor
final class SearchPanelViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SearchResultItem] = []
    @Published var selectedIndex: Int = 0
    @Published var isVisible: Bool = false
    @Published var showingActions: Bool = false
    @Published var actionIndex: Int = 0
    @Published var errorMessage: String?

    private let windowTracker: WindowTracker
    private let searchIndex = SearchIndex()
    private let rankingEngine = RankingEngine()
    private let focusEngine = FocusEngine()
    private let usageStore: UsageStore
    private let preferencesStore: PreferencesStore
    private let tabProviders: [any TabProvider]
    private var cachedTabs: [TabRecord] = []
    private var cancellables = Set<AnyCancellable>()

    init(
        windowTracker: WindowTracker,
        usageStore: UsageStore,
        preferencesStore: PreferencesStore,
        tabProviders: [any TabProvider] = [ChromeTabProvider(), CmuxTabProvider()]
    ) {
        self.windowTracker = windowTracker
        self.usageStore = usageStore
        self.preferencesStore = preferencesStore
        self.tabProviders = tabProviders

        $query
            .debounce(for: .milliseconds(16), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.updateResults() }
            .store(in: &cancellables)
    }

    var actions: [WindowAction] {
        WindowAction.allCases
    }

    func openPanel() {
        query = ""
        selectedIndex = 0
        showingActions = false
        actionIndex = 0
        errorMessage = nil
        isVisible = true
        windowTracker.refreshSnapshot()
        rebuildIndex()
        updateResults()
        Task { await refreshTabs() }
    }

    func closePanel() {
        isVisible = false
    }

    func togglePanel() {
        if isVisible { closePanel() } else { openPanel() }
    }

    func toggleActions() {
        guard !results.isEmpty else { return }
        showingActions.toggle()
        actionIndex = 0
    }

    func moveSelectionUp() {
        if showingActions {
            guard actionIndex > 0 else { return }
            actionIndex -= 1
        } else {
            guard selectedIndex > 0 else { return }
            selectedIndex -= 1
        }
    }

    func moveSelectionDown() {
        if showingActions {
            guard actionIndex < actions.count - 1 else { return }
            actionIndex += 1
        } else {
            guard selectedIndex < results.count - 1 else { return }
            selectedIndex += 1
        }
    }

    func commitSelection() {
        if showingActions {
            commitAction()
            return
        }
        guard selectedIndex >= 0, selectedIndex < results.count else {
            closePanel()
            return
        }

        let selected = results[selectedIndex]
        let capturedQuery = query

        switch selected {
        case .window(let ranked):
            commitWindow(ranked, query: capturedQuery)
        case .tab(let tab):
            commitTab(tab)
        }
    }

    private func commitWindow(_ ranked: RankedWindow, query: String) {
        let app = NSRunningApplication(processIdentifier: ranked.window.pid)
        if app == nil || app!.isTerminated {
            windowTracker.refreshSnapshot()
            rebuildIndex()
            updateResults()
            errorMessage = "Window no longer available"
            dismissErrorAfterDelay()
            return
        }

        closePanel()

        Task {
            do {
                try await focusEngine.focusWindow(ranked.window)
                usageStore.recordSelection(
                    query: query,
                    targetId: ranked.window.id,
                    bundleId: ranked.window.bundleId
                )
                usageStore.recordActivation(targetId: ranked.window.id)
            } catch {
                openPanel()
                errorMessage = "Failed to switch window"
                dismissErrorAfterDelay()
            }
        }
    }

    private func commitTab(_ tab: TabRecord) {
        closePanel()
        Task {
            for provider in tabProviders where provider.supportedBundleIds.contains(tab.bundleId) {
                await provider.activateTab(tab)
                break
            }
        }
    }

    private func commitAction() {
        let action = actions[actionIndex]
        guard selectedIndex >= 0, selectedIndex < results.count else {
            showingActions = false
            return
        }
        let selected = results[selectedIndex]

        switch action {
        case .excludeApp:
            preferencesStore.addExclusion(selected.bundleId)
            showingActions = false
            rebuildIndex()
            updateResults()
        case .close:
            showingActions = false
        }
    }

    private func refreshTabs() async {
        // Run all providers in parallel; update results as each completes
        cachedTabs = []
        await withTaskGroup(of: [TabRecord].self) { group in
            for provider in tabProviders {
                group.addTask { await provider.enumerateTabs() }
            }
            for await tabs in group {
                cachedTabs.append(contentsOf: tabs)
                updateResults()
            }
        }
    }

    private func rebuildIndex() {
        let prefs = preferencesStore.preferences
        let filtered = windowTracker.windows.values.filter { window in
            if preferencesStore.isExcluded(window.bundleId) { return false }
            if !prefs.includeMinimizedWindows && window.isMinimized { return false }
            if !prefs.includeUtilityWindows && window.subrole == "AXDialog" { return false }
            return true
        }
        searchIndex.rebuild(from: Array(filtered))
    }

    private func updateResults() {
        let candidates = searchIndex.search(query: query)
        let context = makeRankingContext()
        let shortcuts = usageStore.records(for: TextNormalizer.normalize(query))
        let rankedWindows = rankingEngine.rank(candidates: candidates, context: context, shortcuts: shortcuts)

        var items: [SearchResultItem] = rankedWindows.map { .window($0) }

        // Filter and score tabs
        let normalizedQuery = TextNormalizer.normalize(query)
        let matchingTabs = cachedTabs.filter { tab in
            if preferencesStore.isExcluded(tab.bundleId) { return false }
            if normalizedQuery.isEmpty { return true }
            let normalizedTitle = TextNormalizer.normalize(tab.title)
            let normalizedSubtitle = TextNormalizer.normalize(tab.subtitle)
            return normalizedTitle.contains(normalizedQuery)
                || normalizedSubtitle.contains(normalizedQuery)
                || TextNormalizer.isSubsequence(normalizedQuery, of: normalizedTitle)
        }
        items.append(contentsOf: matchingTabs.map { .tab($0) })

        results = items
        selectedIndex = 0
    }

    private func dismissErrorAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(2))
            errorMessage = nil
        }
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
