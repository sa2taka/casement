import Testing
import Foundation
@testable import Casement

@Suite("UsageStore")
struct UsageStoreTests {
    func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("casement-test-\(UUID().uuidString).json")
    }

    @Test("records query selection and retrieves it")
    func recordAndRetrieve() throws {
        let url = tempURL()
        let store = UsageStore(fileURL: url)
        store.recordSelection(query: "saf", targetId: "123", bundleId: "com.apple.Safari")

        let records = store.records(for: "saf")
        #expect(records.count == 1)
        #expect(records.first?.targetStableIdHash == "123")
        #expect(records.first?.useCount == 1)

        try? FileManager.default.removeItem(at: url)
    }

    @Test("increments use count on repeated selection")
    func incrementsCount() throws {
        let url = tempURL()
        let store = UsageStore(fileURL: url)
        store.recordSelection(query: "saf", targetId: "123", bundleId: "com.apple.Safari")
        store.recordSelection(query: "saf", targetId: "123", bundleId: "com.apple.Safari")

        let records = store.records(for: "saf")
        #expect(records.first?.useCount == 2)

        try? FileManager.default.removeItem(at: url)
    }

    @Test("persists across instances")
    func persistence() throws {
        let url = tempURL()
        let store1 = UsageStore(fileURL: url)
        store1.recordSelection(query: "term", targetId: "456", bundleId: "com.apple.Terminal")

        let store2 = UsageStore(fileURL: url)
        let records = store2.records(for: "term")
        #expect(records.count == 1)
        #expect(records.first?.targetStableIdHash == "456")

        try? FileManager.default.removeItem(at: url)
    }

    @Test("clearAll removes all records")
    func clearAll() throws {
        let url = tempURL()
        let store = UsageStore(fileURL: url)
        store.recordSelection(query: "saf", targetId: "123", bundleId: "com.apple.Safari")
        store.clearAll()

        let records = store.records(for: "saf")
        #expect(records.isEmpty)

        try? FileManager.default.removeItem(at: url)
    }

    @Test("MRU returns most recently activated window IDs")
    func mru() throws {
        let url = tempURL()
        let store = UsageStore(fileURL: url)
        store.recordActivation(targetId: "a")
        store.recordActivation(targetId: "b")
        store.recordActivation(targetId: "c")

        let mru = store.recentTargetIds(limit: 3)
        #expect(mru == ["c", "b", "a"])

        try? FileManager.default.removeItem(at: url)
    }
}
