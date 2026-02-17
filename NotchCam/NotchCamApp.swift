import SwiftUI

@main
struct NotchCamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView(controller: appDelegate)
        }
    }
}
