import Combine
import Foundation

struct AppPreferences: Codable, Sendable {
    var includeMinimizedWindows: Bool = true
    var includeUtilityWindows: Bool = false
    var excludedBundleIds: Set<String> = []
}

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var preferences: AppPreferences

    private let key = "com.casement.preferences"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = AppPreferences()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func addExclusion(_ bundleId: String) {
        preferences.excludedBundleIds.insert(bundleId)
        save()
    }

    func removeExclusion(_ bundleId: String) {
        preferences.excludedBundleIds.remove(bundleId)
        save()
    }

    func isExcluded(_ bundleId: String) -> Bool {
        preferences.excludedBundleIds.contains(bundleId)
    }
}
