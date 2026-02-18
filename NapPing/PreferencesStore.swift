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

    var pauseWhenAllEyesClosedEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.pauseWhenAllEyesClosedEnabled) == nil { return false }
            return defaults.bool(forKey: Keys.pauseWhenAllEyesClosedEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.pauseWhenAllEyesClosedEnabled) }
    }

    private enum Keys {
        static let showDockIcon = "com.napping.preferences.showDockIcon"
        static let cameraPreviewEnabled = "com.napping.preferences.cameraPreviewEnabled"
        static let sleepDetectionEnabled = "com.napping.preferences.sleepDetectionEnabled"
        static let pauseWhenAllEyesClosedEnabled = "com.napping.preferences.pauseWhenAllEyesClosedEnabled"
    }
}
