import AppKit
import Carbon.HIToolbox
import CoreGraphics
import WordLockCore

/// Listens to system-wide key presses with a listen-only event tap and feeds them to a
/// `TriggerMatcher`. Requires the Input Monitoring permission.
///
/// Keystrokes typed into password fields are never delivered here: macOS turns on Secure Event
/// Input for those, which hides them from all event taps.
final class KeyMonitor {
    var onTrigger: (() -> Void)?

    private var matcher = TriggerMatcher()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var appSwitchObserver: NSObjectProtocol?
    /// Reused for every key event so handling a keystroke doesn't allocate.
    private var utf16 = [UniChar](repeating: 0, count: 4)

    /// Counters shown in the menu to make problems diagnosable without logging what was typed.
    private(set) var keyEventsSeen = 0
    private(set) var lastTriggerDate: Date?

    var isRunning: Bool { tap != nil }
    var hasTriggers: Bool { !matcher.isEmpty }

    static var hasPermission: Bool { CGPreflightListenEventAccess() }

    /// True while some app has Secure Event Input on, which hides every keystroke from event taps.
    static var isSecureInputActive: Bool { IsSecureEventInputEnabled() }

    /// Shows the system prompt (first time only) and adds the app to the Input Monitoring list.
    static func requestPermission() {
        CGRequestListenEventAccess()
    }

    func configure(triggers: [String], caseSensitive: Bool) {
        matcher.configure(triggers: triggers, caseSensitive: caseSensitive)
    }

    /// Returns false if the tap could not be created, which means permission is missing.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        // Key presses, plus left clicks because a click usually moves the text cursor.
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log.error("Event tap creation failed (input monitoring preflight: \(Self.hasPermission, privacy: .public))")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source

        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.matcher.reset()
        }
        log.notice("Event tap started")
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appSwitchObserver)
        }
        tap = nil
        runLoopSource = nil
        appSwitchObserver = nil
        matcher.reset()
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            break
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            log.error("Event tap was disabled by the system (type \(type.rawValue, privacy: .public)); re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        default: // mouse click
            matcher.reset()
            return
        }

        keyEventsSeen += 1
        if keyEventsSeen == 1 { log.notice("First key event received") }

        // Ignore typing into WordLock's own windows (e.g. while adding a trigger word), and
        // shortcuts, whose characters were never typed into a document.
        if NSApp.isActive || !event.flags.isDisjoint(with: [.maskCommand, .maskControl]) {
            matcher.reset()
            return
        }

        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case Int64(kVK_Delete):
            matcher.backspace()
            return
        case Int64(kVK_ForwardDelete), Int64(kVK_Escape), Int64(kVK_Home), Int64(kVK_End),
             Int64(kVK_PageUp), Int64(kVK_PageDown), Int64(kVK_LeftArrow), Int64(kVK_RightArrow),
             Int64(kVK_UpArrow), Int64(kVK_DownArrow):
            matcher.reset()
            return
        default:
            break
        }

        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: utf16.count, actualStringLength: &length, unicodeString: &utf16)

        var index = 0
        while index < length {
            var scalar = UInt32(utf16[index])
            if UTF16.isLeadSurrogate(utf16[index]), index + 1 < length, UTF16.isTrailSurrogate(utf16[index + 1]) {
                scalar = 0x10000 + ((scalar - 0xD800) << 10) + (UInt32(utf16[index + 1]) - 0xDC00)
                index += 1
            }
            index += 1
            if matcher.feed(scalar) {
                lastTriggerDate = Date()
                log.notice("Trigger word matched")
                onTrigger?()
            }
        }
    }
}
