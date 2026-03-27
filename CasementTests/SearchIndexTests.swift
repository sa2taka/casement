import Testing
@testable import Casement

@Suite("SearchIndex")
struct SearchIndexTests {
    let safari = TestFixtures.windowRecord(
        bundleId: "com.apple.Safari", appName: "Safari", title: "Apple - Start"
    )
    let chrome1 = TestFixtures.windowRecord(
        pid: 2345, bundleId: "com.google.Chrome", appName: "Google Chrome",
        title: "GitHub - Pull Requests"
    )
    let chrome2 = TestFixtures.windowRecord(
        pid: 2345, bundleId: "com.google.Chrome", appName: "Google Chrome",
        title: "Stack Overflow - Swift"
    )
    let vscode = TestFixtures.windowRecord(
        pid: 3456, bundleId: "com.microsoft.VSCode", appName: "Visual Studio Code",
        title: "main.swift — Casement"
    )
    let terminal = TestFixtures.windowRecord(
        pid: 4567, bundleId: "com.apple.Terminal", appName: "Terminal",
        title: "bash — 80x24"
    )

    func makeIndex() -> SearchIndex {
        let index = SearchIndex()
        index.rebuild(from: [safari, chrome1, chrome2, vscode, terminal])
        return index
    }

    @Test("empty query returns all windows")
    func emptyQuery() {
        let index = makeIndex()
        let candidates = index.search(query: "")
        #expect(candidates.count == 5)
    }

    @Test("prefix match on app name")
    func prefixAppName() {
        let index = makeIndex()
        let candidates = index.search(query: "saf")
        #expect(candidates.contains { $0.appName == "Safari" })
    }

    @Test("prefix match on title")
    func prefixTitle() {
        let index = makeIndex()
        let candidates = index.search(query: "github")
        #expect(candidates.contains { $0.title == "GitHub - Pull Requests" })
    }

    @Test("acronym match")
    func acronymMatch() {
        let index = makeIndex()
        let candidates = index.search(query: "vsc")
        #expect(candidates.contains { $0.appName == "Visual Studio Code" })
    }

    @Test("acronym match for Google Chrome")
    func acronymChrome() {
        let index = makeIndex()
        let candidates = index.search(query: "gc")
        #expect(candidates.contains { $0.appName == "Google Chrome" })
    }

    @Test("subsequence match")
    func subsequenceMatch() {
        let index = makeIndex()
        let candidates = index.search(query: "sfri")
        #expect(candidates.contains { $0.appName == "Safari" })
    }

    @Test("no match returns empty")
    func noMatch() {
        let index = makeIndex()
        let candidates = index.search(query: "zzzznotfound")
        #expect(candidates.isEmpty)
    }

    @Test("contains match on title")
    func containsTitle() {
        let index = makeIndex()
        let candidates = index.search(query: "swift")
        #expect(candidates.contains { $0.title.contains("Swift") })
    }
}
