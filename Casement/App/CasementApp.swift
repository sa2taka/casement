import SwiftUI

@main
struct CasementApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView(
                preferencesStore: appDelegate.preferencesStore,
                usageStore: appDelegate.usageStore
            )
        }
    }
}
