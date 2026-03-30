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
    @Published var results: [RankedWindow] = []
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

    var actions: [WindowAction] {
        WindowAction.allCases
    }

    func openPanel() {
        query = ""
        selectedIndex = 0
        showingActions = false
        actionIndex = 0
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

        // Validate app is still running before committing
        let app = NSRunningApplication(processIdentifier: selected.window.pid)
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
                try await focusEngine.focusWindow(selected.window)
                usageStore.recordSelection(
                    query: capturedQuery,
                    targetId: selected.window.id,
                    bundleId: selected.window.bundleId
                )
                usageStore.recordActivation(targetId: selected.window.id)
            } catch {
                openPanel()
                errorMessage = "Failed to switch window"
                dismissErrorAfterDelay()
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
            preferencesStore.addExclusion(selected.window.bundleId)
            showingActions = false
            rebuildIndex()
            updateResults()
        case .close:
            showingActions = false
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
        results = rankingEngine.rank(candidates: candidates, context: context, shortcuts: shortcuts)
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
