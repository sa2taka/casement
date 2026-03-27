import AppKit
import Carbon
import Combine
import Foundation

struct HotkeyShortcut: Codable, Sendable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultShortcut = HotkeyShortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey)
    )

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName)
        return parts.joined()
    }

    private var keyName: String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_Escape: return "Esc"
        case kVK_ANSI_A...kVK_ANSI_Z:
            let letters = "AQZSWXDECFRVGTBYHUNIJMKOL.P"
            let index = Int(keyCode)
            if index < letters.count {
                return String(letters[letters.index(letters.startIndex, offsetBy: index)])
            }
            return "Key\(keyCode)"
        default: return "Key\(keyCode)"
        }
    }

    static func carbonModifiers(from nsFlags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if nsFlags.contains(.control) { carbon |= UInt32(controlKey) }
        if nsFlags.contains(.option) { carbon |= UInt32(optionKey) }
        if nsFlags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if nsFlags.contains(.command) { carbon |= UInt32(cmdKey) }
        return carbon
    }
}

struct AppPreferences: Codable, Sendable, Equatable {
    var hotkeyShortcut: HotkeyShortcut = .defaultShortcut
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
