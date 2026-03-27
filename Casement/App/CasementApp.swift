import SwiftUI

@main
struct CasementApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            Text("Casement Preferences")
                .frame(width: 300, height: 200)
        }
    }
}
