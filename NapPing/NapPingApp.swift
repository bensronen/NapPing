import SwiftUI

@main
struct NapPingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView(controller: appDelegate)
        }
    }
}
