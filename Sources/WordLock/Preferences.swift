import Foundation
import ServiceManagement

/// User-facing settings, persisted in UserDefaults.
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let triggerWord = "triggerWord"
        static let caseSensitive = "caseSensitive"
        static let isEnabled = "isEnabled"
        static let testMode = "testMode"
    }

    private let defaults = UserDefaults.standard

    @Published var triggerWord: String {
        didSet { defaults.set(triggerWord, forKey: Key.triggerWord) }
    }

    @Published var caseSensitive: Bool {
        didSet { defaults.set(caseSensitive, forKey: Key.caseSensitive) }
    }

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    /// When on, typing the trigger plays a sound and flashes the menu bar icon instead of locking.
    @Published var testMode: Bool {
        didSet { defaults.set(testMode, forKey: Key.testMode) }
    }

    @Published private(set) var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    private init() {
        defaults.register(defaults: [
            Key.triggerWord: "",
            Key.caseSensitive: false,
            Key.isEnabled: true,
            Key.testMode: false,
        ])
        triggerWord = defaults.string(forKey: Key.triggerWord) ?? ""
        caseSensitive = defaults.bool(forKey: Key.caseSensitive)
        isEnabled = defaults.bool(forKey: Key.isEnabled)
        testMode = defaults.bool(forKey: Key.testMode)
    }

    var hasTrigger: Bool {
        !triggerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        defer { launchAtLogin = SMAppService.mainApp.status == .enabled }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
