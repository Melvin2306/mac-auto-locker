import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let preferences = Preferences.shared
    private let monitor = KeyMonitor()

    private var statusItem: NSStatusItem?
    private var settings: SettingsWindowController?
    private var permissionTimer: Timer?
    private var lastTrigger = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != .current }
        if !others.isEmpty {
            log.notice("Another WordLock instance is already running; quitting")
            NSApp.terminate(nil)
            return
        }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        monitor.onTrigger = { [weak self] in self?.triggerFired() }
        applyPreferences()

        if !KeyMonitor.hasPermission {
            KeyMonitor.requestPermission()
        }
        if preferences.triggerWords.isEmpty || !KeyMonitor.hasPermission {
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    // MARK: - Monitoring

    private func applyPreferences() {
        monitor.configure(triggers: preferences.triggerWords, caseSensitive: preferences.caseSensitive)
        if preferences.isEnabled {
            startMonitoring()
        } else {
            stopPermissionTimer()
            monitor.stop()
        }
        refreshIcon()
    }

    private func startMonitoring() {
        if monitor.start() {
            stopPermissionTimer()
            settings?.refresh()
            refreshIcon()
            return
        }
        // Permission not granted yet. Check back occasionally so WordLock starts working as soon
        // as it is; the timer only exists until then.
        guard permissionTimer == nil else { return }
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in self?.startMonitoring() }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    private func stopPermissionTimer() {
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    private func triggerFired() {
        // Guard against double-firing from a flurry of events.
        guard Date().timeIntervalSince(lastTrigger) > 2 else { return }
        lastTrigger = Date()
        log.notice("Trigger fired (test mode: \(self.preferences.testMode, privacy: .public))")

        if preferences.testMode {
            NSSound(named: "Glass")?.play()
            flashIcon()
        } else {
            ScreenLocker.lock()
        }
    }

    // MARK: - Status item

    private enum State { case active, paused, needsPermission, needsWords }

    private var state: State {
        if !preferences.isEnabled { return .paused }
        if !monitor.isRunning { return .needsPermission }
        if !monitor.hasTriggers { return .needsWords }
        return .active
    }

    private func refreshIcon() {
        let (symbol, description): (String, String)
        switch state {
        case .active: (symbol, description) = ("lock.shield", "WordLock is active")
        case .paused: (symbol, description) = ("lock.open", "WordLock is paused")
        case .needsPermission, .needsWords: (symbol, description) = ("exclamationmark.lock", "WordLock needs setup")
        }
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        statusItem?.button?.toolTip = description
    }

    private func flashIcon() {
        statusItem?.button?.image = NSImage(systemSymbolName: "checkmark.seal.fill", accessibilityDescription: "Trigger detected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.refreshIcon() }
    }

    /// The menu is built only when opened, so nothing is kept up to date in the background.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let headline: String
        switch state {
        case .active: headline = preferences.testMode ? "Active, test mode (won't lock)" : "Active"
        case .paused: headline = "Paused"
        case .needsPermission: headline = "Needs Input Monitoring permission"
        case .needsWords: headline = "No trigger words set"
        }
        addInfo("WordLock: \(headline)", to: menu)

        let lastTrigger = monitor.lastTriggerDate.map {
            DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium)
        } ?? "never"
        addInfo("Keys seen: \(monitor.keyEventsSeen) · Last trigger: \(lastTrigger)", to: menu)
        if KeyMonitor.isSecureInputActive {
            addInfo("⚠️ Secure Input is on in another app, so typing is hidden", to: menu)
        }
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        toggle.state = preferences.isEnabled ? .on : .off
        toggle.target = self
        menu.addItem(toggle)

        let lockNow = NSMenuItem(title: "Lock Now", action: #selector(lockNow), keyEquivalent: "l")
        lockNow.target = self
        menu.addItem(lockNow)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Quit WordLock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func addInfo(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        preferences.isEnabled.toggle()
        applyPreferences()
        settings?.refresh()
    }

    @objc private func lockNow() {
        ScreenLocker.lock()
    }

    @objc private func showSettings() {
        if settings == nil {
            let controller = SettingsWindowController()
            controller.onChange = { [weak self] in self?.applyPreferences() }
            controller.onClose = { [weak self] in
                // Drop the window entirely; it is rebuilt on demand.
                DispatchQueue.main.async { self?.settings = nil }
            }
            settings = controller
        }
        settings?.refresh()
        NSApp.activate(ignoringOtherApps: true)
        settings?.showWindow(nil)
    }
}
