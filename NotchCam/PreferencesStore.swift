import Foundation

final class PreferencesStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var showDockIcon: Bool {
        get { defaults.bool(forKey: Keys.showDockIcon) }
        set { defaults.set(newValue, forKey: Keys.showDockIcon) }
    }

    var cameraPreviewEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.cameraPreviewEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.cameraPreviewEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.cameraPreviewEnabled) }
    }

    var sleepDetectionEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.sleepDetectionEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.sleepDetectionEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.sleepDetectionEnabled) }
    }

    private enum Keys {
        static let showDockIcon = "com.notchcam.preferences.showDockIcon"
        static let cameraPreviewEnabled = "com.notchcam.preferences.cameraPreviewEnabled"
        static let sleepDetectionEnabled = "com.notchcam.preferences.sleepDetectionEnabled"
    }
}
