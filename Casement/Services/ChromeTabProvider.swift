import AppKit

final class ChromeTabProvider: TabProvider, @unchecked Sendable {
    let supportedBundleIds: Set<String> = ["com.google.Chrome", "com.google.Chrome.canary"]

    private var cache: [TabRecord] = []
    private var cacheTime: Date = .distantPast
    private let cacheTTL: TimeInterval = 30.0

    func enumerateTabs() async -> [TabRecord] {
        if Date().timeIntervalSince(cacheTime) < cacheTTL {
            return cache
        }

        let isRunning = await MainActor.run {
            NSWorkspace.shared.runningApplications.contains { supportedBundleIds.contains($0.bundleIdentifier ?? "") }
        }
        guard isRunning else { return [] }

        let tabs = await fetchTabs()
        cache = tabs
        cacheTime = Date()
        return tabs
    }

    func activateTab(_ tab: TabRecord) async {
        // Activate Chrome first (window order changes on activate), then
        // find the target window by stable ID and switch tab.
        let jxa = """
        (() => {
            const chrome = Application('Google Chrome');
            chrome.activate();
            delay(0.3);
            const wins = chrome.windows();
            for (let i = 0; i < wins.length; i++) {
                if (String(wins[i].id()) === '\(tab.windowId)') {
                    wins[i].activeTabIndex = \(tab.tabIndex);
                    wins[i].index = 1;
                    return 'ok';
                }
            }
            return 'window not found';
        })();
        """
        await runJXA(jxa)
    }

    private func fetchTabs() async -> [TabRecord] {
        let jxa = """
        (() => {
            const chrome = Application('Google Chrome');
            const results = [];
            chrome.windows().forEach((win) => {
                if (win.mode() === 'incognito') return;
                const winId = String(win.id());
                win.tabs().forEach((tab, ti) => {
                    results.push({winId: winId, t: ti+1, title: tab.title(), url: tab.url()});
                });
            });
            return JSON.stringify(results);
        })();
        """

        let output = await runJXA(jxa)

        guard let data = output.data(using: .utf8),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }

        return entries.compactMap { entry -> TabRecord? in
            guard let winId = entry["winId"] as? String,
                  let t = entry["t"] as? Int,
                  let title = entry["title"] as? String,
                  let url = entry["url"] as? String,
                  !title.isEmpty
            else { return nil }

            let domain = URL(string: url)?.host ?? url
            return TabRecord(
                id: "chrome-\(winId)-\(t)",
                kind: .chromeTab,
                appName: "Google Chrome",
                bundleId: "com.google.Chrome",
                title: title,
                subtitle: domain,
                windowId: winId,
                tabIndex: t
            )
        }
    }

    @discardableResult
    private func runJXA(_ script: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", "-e", script]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
            }
            do { try process.run() } catch { continuation.resume(returning: "") }
        }
    }
}
