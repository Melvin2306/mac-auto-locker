import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let preferences = Preferences.shared
    private let status = MonitorStatus()
    private lazy var monitor = KeyMonitor(trigger: preferences.triggerWord, caseSensitive: preferences.caseSensitive)

    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var retryTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastTrigger = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        monitor.onTrigger = { [weak self] in self?.triggerFired() }

        Publishers.CombineLatest(preferences.$triggerWord, preferences.$caseSensitive)
            .sink { [weak self] word, caseSensitive in
                self?.monitor.update(trigger: word, caseSensitive: caseSensitive)
                self?.refreshIcon()
            }
            .store(in: &cancellables)

        preferences.$isEnabled
            .sink { [weak self] _ in DispatchQueue.main.async { self?.applyEnabledState() } }
            .store(in: &cancellables)

        if !KeyMonitor.hasPermission {
            KeyMonitor.requestPermission()
        }
        if !preferences.hasTrigger || !KeyMonitor.hasPermission {
            showSettings()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    // MARK: - Monitoring

    private func applyEnabledState() {
        if preferences.isEnabled {
            startMonitoring()
        } else {
            retryTimer?.invalidate()
            retryTimer = nil
            monitor.stop()
            status.isListening = false
        }
        refreshIcon()
    }

    private func startMonitoring() {
        status.hasPermission = KeyMonitor.hasPermission
        if monitor.start() {
            status.isListening = true
            status.hasPermission = true
            retryTimer?.invalidate()
            retryTimer = nil
            refreshIcon()
            return
        }
        // Permission not granted yet; keep checking so the app starts working as soon as it is.
        status.isListening = false
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, self.preferences.isEnabled else { return }
            self.startMonitoring()
        }
    }

    private func triggerFired() {
        // Guard against double-firing from key repeat or a flurry of events.
        guard Date().timeIntervalSince(lastTrigger) > 2 else { return }
        lastTrigger = Date()

        if preferences.testMode {
            NSSound(named: "Glass")?.play()
            flashIcon()
        } else {
            ScreenLocker.lock()
        }
    }

    // MARK: - Status item

    private func refreshIcon() {
        guard let button = statusItem?.button else { return }
        let symbol: String
        let description: String
        switch currentState {
        case .active:
            symbol = "lock.shield"
            description = "WordLock is active"
        case .paused:
            symbol = "lock.open"
            description = "WordLock is paused"
        case .needsSetup:
            symbol = "exclamationmark.lock"
            description = "WordLock needs setup"
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        button.toolTip = description
    }

    private func flashIcon() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "checkmark.seal.fill", accessibilityDescription: "Trigger detected")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.refreshIcon() }
    }

    private enum State { case active, paused, needsSetup }

    private var currentState: State {
        if !preferences.isEnabled { return .paused }
        if !preferences.hasTrigger || !status.isListening { return .needsSetup }
        return .active
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let headline: String
        switch currentState {
        case .active:
            headline = preferences.testMode ? "Active — test mode (won't lock)" : "Active"
        case .paused:
            headline = "Paused"
        case .needsSetup:
            if !status.isListening {
                headline = "Needs Input Monitoring permission"
            } else {
                headline = "No trigger word set"
            }
        }
        let header = NSMenuItem(title: "WordLock: \(headline)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "e")
        toggle.state = preferences.isEnabled ? .on : .off
        toggle.target = self
        menu.addItem(toggle)

        let lockNow = NSMenuItem(title: "Lock Now", action: #selector(lockNow), keyEquivalent: "l")
        lockNow.target = self
        menu.addItem(lockNow)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(NSMenuItem(title: "Quit WordLock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        preferences.isEnabled.toggle()
    }

    @objc private func lockNow() {
        ScreenLocker.lock()
    }

    @objc private func showSettings() {
        status.hasPermission = KeyMonitor.hasPermission
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(
                rootView: SettingsView(preferences: preferences, status: status, form: SettingsFormState())
            ))
            window.title = "WordLock Settings"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
