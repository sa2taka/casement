import Foundation
import Testing
import CoreGraphics
@testable import Casement

@Suite("RankingEngine")
struct RankingEngineTests {
    let engine = RankingEngine()

    func context(query: String, currentApp: String? = nil) -> RankingContext {
        RankingContext(
            query: query,
            normalizedQuery: TextNormalizer.normalize(query),
            currentAppBundleId: currentApp,
            currentDisplayId: CGMainDisplayID(),
            currentSpaceHint: nil,
            now: Date()
        )
    }

    @Test("exact app name match ranks highest")
    func exactAppMatch() {
        let safari = TestFixtures.windowRecord(
            bundleId: "com.apple.Safari", appName: "Safari", title: "Apple"
        )
        let other = TestFixtures.windowRecord(
            pid: 2345, bundleId: "com.google.Chrome", appName: "Google Chrome",
            title: "Safari Tips"
        )
        let results = engine.rank(candidates: [other, safari], context: context(query: "Safari"))
        #expect(results.first?.window.appName == "Safari")
    }

    @Test("prefix app match scores higher than contains title match")
    func prefixOverContains() {
        let chrome = TestFixtures.windowRecord(
            pid: 2345, bundleId: "com.google.Chrome", appName: "Google Chrome",
            title: "Random Page"
        )
        let other = TestFixtures.windowRecord(
            pid: 3456, bundleId: "com.example.app", appName: "Other App",
            title: "Installing Google Chrome"
        )
        let results = engine.rank(candidates: [other, chrome], context: context(query: "google"))
        #expect(results.first?.window.appName == "Google Chrome")
    }

    @Test("MRU boosts recent windows")
    func mruBoost() {
        let recent = TestFixtures.windowRecord(
            bundleId: "com.apple.Safari", appName: "Safari", title: "Page A",
            lastActivatedAt: Date()
        )
        let old = TestFixtures.windowRecord(
            pid: 2345, bundleId: "com.apple.Safari", appName: "Safari", title: "Page B",
            lastActivatedAt: Date(timeIntervalSinceNow: -3600)
        )
        let results = engine.rank(candidates: [old, recent], context: context(query: "safari"))
        #expect(results.first?.window.title == "Page A")
    }

    @Test("minimized window gets penalty")
    func minimizedPenalty() {
        let normal = TestFixtures.windowRecord(
            bundleId: "com.apple.Safari", appName: "Safari", title: "Page A"
        )
        let minimized = TestFixtures.windowRecord(
            pid: 2345, bundleId: "com.apple.Safari", appName: "Safari", title: "Page B",
            isMinimized: true
        )
        let results = engine.rank(candidates: [minimized, normal], context: context(query: "safari"))
        #expect(results.first?.window.isMinimized == false)
    }

    @Test("empty query returns all windows ordered by MRU")
    func emptyQueryMRU() {
        let recent = TestFixtures.windowRecord(
            bundleId: "com.apple.Safari", appName: "Safari", title: "Recent",
            lastActivatedAt: Date()
        )
        let old = TestFixtures.windowRecord(
            pid: 2345, bundleId: "com.google.Chrome", appName: "Google Chrome", title: "Old",
            lastActivatedAt: Date(timeIntervalSinceNow: -3600)
        )
        let results = engine.rank(candidates: [old, recent], context: context(query: ""))
        #expect(results.first?.window.title == "Recent")
    }

    @Test("acronym match provides reasonable score")
    func acronymScore() {
        let vscode = TestFixtures.windowRecord(
            pid: 3456, bundleId: "com.microsoft.VSCode", appName: "Visual Studio Code",
            title: "main.swift"
        )
        let results = engine.rank(candidates: [vscode], context: context(query: "vsc"))
        #expect(!results.isEmpty)
        #expect(results.first?.matchReasons.contains(.acronymMatch) == true)
    }

    @Test("score includes match reasons")
    func matchReasons() {
        let safari = TestFixtures.windowRecord(
            bundleId: "com.apple.Safari", appName: "Safari", title: "Apple"
        )
        let results = engine.rank(candidates: [safari], context: context(query: "Safari"))
        #expect(results.first?.matchReasons.contains(.exactAppMatch) == true)
    }

    @Test("learned shortcut boosts matching window")
    func learnedShortcutBoost() {
        let safari = TestFixtures.windowRecord(
            bundleId: "com.apple.Safari", appName: "Safari", title: "Apple"
        )
        let chrome = TestFixtures.windowRecord(
            pid: 2345, bundleId: "com.google.Chrome", appName: "Google Chrome",
            title: "Apple Store"
        )

        let shortcutRecords = [
            QuerySelectionRecord(
                query: "apple",
                targetStableIdHash: chrome.id,
                bundleId: chrome.bundleId,
                useCount: 5,
                lastUsedAt: Date()
            )
        ]

        let results = engine.rank(
            candidates: [safari, chrome],
            context: context(query: "apple"),
            shortcuts: shortcutRecords
        )
        #expect(results.first?.window.appName == "Google Chrome")
        #expect(results.first?.matchReasons.contains(.learnedShortcut) == true)
    }
}
