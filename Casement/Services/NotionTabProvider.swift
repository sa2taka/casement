import AppKit

final class NotionTabProvider: TabProvider, @unchecked Sendable {
    let supportedBundleIds: Set<String> = ["notion.id"]

    private var cache: [TabRecord] = []
    private var cacheTime: Date = .distantPast
    private let cacheTTL: TimeInterval = 5.0
    private var urlByTabId: [String: String] = [:]

    func enumerateTabs() async -> [TabRecord] {
        if Date().timeIntervalSince(cacheTime) < cacheTTL {
            return cache
        }

        let isRunning = await MainActor.run {
            NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "notion.id" }
        }
        guard isRunning else { return [] }

        let tabs = readTabsFromStateFile()
        cache = tabs
        cacheTime = Date()
        return tabs
    }

    func activateTab(_ tab: TabRecord) async {
        guard let app = await MainActor.run(body: {
            NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == "notion.id" }
        }) else { return }

        await MainActor.run { _ = app.activate() }

        guard let httpsURL = urlByTabId[tab.id] else { return }
        let notionURL = httpsURL.replacingOccurrences(of: "https://", with: "notion://")
        guard let url = URL(string: notionURL) else { return }
        await MainActor.run {
            NSWorkspace.shared.open(url)
        }
    }

    private func readTabsFromStateFile() -> [TabRecord] {
        let stateFilePath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Notion/state.json")

        guard let data = try? Data(contentsOf: stateFilePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let history = json["history"] as? [String: Any],
              let restorationState = history["appRestorationState"] as? [String: Any],
              let windows = restorationState["windows"] as? [[String: Any]]
        else { return [] }

        var records: [TabRecord] = []
        var urls: [String: String] = [:]

        for (windowIndex, window) in windows.enumerated() {
            guard let tabs = window["tabs"] as? [[String: Any]] else { continue }

            for tab in tabs {
                guard let tabId = tab["tabId"] as? String,
                      let title = tab["title"] as? String,
                      let url = tab["url"] as? String,
                      let index = tab["index"] as? Int,
                      !title.isEmpty
                else { continue }

                let id = "notion-\(windowIndex)-\(tabId)"
                urls[id] = url

                records.append(TabRecord(
                    id: id,
                    kind: .notionTab,
                    appName: "Notion",
                    bundleId: "notion.id",
                    title: title,
                    subtitle: URL(string: url)?.host ?? "",
                    windowId: String(windowIndex),
                    tabIndex: index
                ))
            }
        }

        urlByTabId = urls
        return records
    }
}
