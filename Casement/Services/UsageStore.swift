import Foundation

struct QuerySelectionRecord: Codable, Sendable {
    let query: String
    let targetStableIdHash: String
    let bundleId: String
    var useCount: Int
    var lastUsedAt: Date
}

struct ActivationRecord: Codable, Sendable {
    let targetId: String
    let activatedAt: Date
}

struct UsageData: Codable {
    var selections: [QuerySelectionRecord] = []
    var activations: [ActivationRecord] = []
}

final class UsageStore {
    private var data: UsageData
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? UsageStore.defaultFileURL()
        self.data = UsageStore.load(from: self.fileURL)
    }

    static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Casement", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("usage.json")
    }

    func recordSelection(query: String, targetId: String, bundleId: String) {
        if let index = data.selections.firstIndex(where: {
            $0.query == query && $0.targetStableIdHash == targetId
        }) {
            data.selections[index].useCount += 1
            data.selections[index].lastUsedAt = Date()
        } else {
            data.selections.append(QuerySelectionRecord(
                query: query, targetStableIdHash: targetId, bundleId: bundleId,
                useCount: 1, lastUsedAt: Date()
            ))
        }
        save()
    }

    func records(for query: String) -> [QuerySelectionRecord] {
        data.selections.filter { $0.query == query }
    }

    func recordActivation(targetId: String) {
        data.activations.append(ActivationRecord(targetId: targetId, activatedAt: Date()))
        if data.activations.count > 200 {
            data.activations = Array(data.activations.suffix(200))
        }
        save()
    }

    func recentTargetIds(limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for record in data.activations.reversed() {
            if seen.insert(record.targetId).inserted {
                result.append(record.targetId)
            }
            if result.count >= limit { break }
        }
        return result
    }

    func clearAll() {
        data = UsageData()
        save()
    }

    private static func load(from url: URL) -> UsageData {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(UsageData.self, from: data)
        else { return UsageData() }
        return decoded
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        try? encoded.write(to: fileURL, options: .atomic)
    }
}
