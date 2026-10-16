import Foundation
import ServiceManagement
import WordLockCore

/// User-facing settings, persisted in UserDefaults.
final class Preferences {
    static let shared = Preferences()

    private enum Key {
        static let triggerWords = "triggerWords"
        static let legacyTriggerWord = "triggerWord"
        static let caseSensitive = "caseSensitive"
        static let isEnabled = "isEnabled"
        static let testMode = "testMode"
    }

    private let defaults = UserDefaults.standard

    private init() {
        defaults.register(defaults: [Key.isEnabled: true])
        // Migrate the single word stored by version 0.1.
        if let legacy = defaults.string(forKey: Key.legacyTriggerWord) {
            if defaults.stringArray(forKey: Key.triggerWords) == nil {
                triggerWords = [legacy]
            }
            defaults.removeObject(forKey: Key.legacyTriggerWord)
        }
    }

    var triggerWords: [String] {
        get { defaults.stringArray(forKey: Key.triggerWords) ?? [] }
        set { defaults.set(TriggerMatcher.normalize(newValue), forKey: Key.triggerWords) }
    }

    var caseSensitive: Bool {
        get { defaults.bool(forKey: Key.caseSensitive) }
        set { defaults.set(newValue, forKey: Key.caseSensitive) }
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.isEnabled) }
        set { defaults.set(newValue, forKey: Key.isEnabled) }
    }

    /// When on, typing a trigger plays a sound and flashes the menu bar icon instead of locking.
    var testMode: Bool {
        get { defaults.bool(forKey: Key.testMode) }
        set { defaults.set(newValue, forKey: Key.testMode) }
    }

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
