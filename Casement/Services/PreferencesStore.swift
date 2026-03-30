import AppKit
import Carbon
import Combine
import Foundation
import ServiceManagement

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
        if let special = specialKeyName { return special }
        if let character = Self.characterFromKeyCode(keyCode) { return character.uppercased() }
        return "Key\(keyCode)"
    }

    private var specialKeyName: String? {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "Esc"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return nil
        }
    }

    private static func characterFromKeyCode(_ keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let layoutData = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let keyLayout = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)

        let status = UCKeyTranslate(
            keyLayout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            4,
            &length,
            &characters
        )

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
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

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            try? newValue ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
        }
    }

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
