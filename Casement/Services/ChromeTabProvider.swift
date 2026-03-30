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

        let tabs = await runJXA()
        cache = tabs
        cacheTime = Date()
        return tabs
    }

    func activateTab(_ tab: TabRecord) async {
        // Use JXA instead of AppleScript — more reliable with window indexing
        let jxa = """
        (() => {
            const chrome = Application('Google Chrome');
            const wins = chrome.windows();
            if (\(tab.windowIndex - 1) < wins.length) {
                wins[\(tab.windowIndex - 1)].activeTabIndex = \(tab.tabIndex);
                wins[\(tab.windowIndex - 1)].index = 1;
            }
            chrome.activate();
            return 'ok';
        })();
        """
        await runJXAScript(jxa)
    }

    private func runJXA() async -> [TabRecord] {
        let jxa = """
        (() => {
            const chrome = Application('Google Chrome');
            const results = [];
            chrome.windows().forEach((win, wi) => {
                if (win.mode() === 'incognito') return;
                win.tabs().forEach((tab, ti) => {
                    results.push({w: wi+1, t: ti+1, title: tab.title(), url: tab.url()});
                });
            });
            return JSON.stringify(results);
        })();
        """

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", "-e", jxa]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard let jsonData = output.data(using: .utf8),
                      let entries = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
                else {
                    continuation.resume(returning: [])
                    return
                }

                let tabs = entries.compactMap { entry -> TabRecord? in
                    guard let w = entry["w"] as? Int,
                          let t = entry["t"] as? Int,
                          let title = entry["title"] as? String,
                          let url = entry["url"] as? String
                    else { return nil }

                    let domain = URL(string: url)?.host ?? url
                    return TabRecord(
                        id: "chrome-\(w)-\(t)",
                        kind: .chromeTab,
                        appName: "Google Chrome",
                        bundleId: "com.google.Chrome",
                        title: title,
                        subtitle: domain,
                        windowIndex: w,
                        tabIndex: t
                    )
                }
                continuation.resume(returning: tabs)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: [])
            }
        }
    }

    @discardableResult
    private func runJXAScript(_ script: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-l", "JavaScript", "-e", script]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try process.run() } catch { continuation.resume(returning: "") }
        }
    }
}
