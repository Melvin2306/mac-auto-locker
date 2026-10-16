import AppKit
import CoreGraphics
import WordLockCore

/// Listens to system-wide key presses with a listen-only event tap and feeds them to a
/// `TriggerMatcher`. Requires the Input Monitoring permission.
///
/// Keystrokes typed into password fields are never delivered here: macOS enables Secure Event
/// Input for those, which hides them from all event taps.
final class KeyMonitor {
    var onTrigger: (() -> Void)?

    private(set) var matcher: TriggerMatcher
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var appSwitchObserver: NSObjectProtocol?

    var isRunning: Bool { tap != nil }

    /// Counters shown in the menu to make problems diagnosable without logging what was typed.
    private(set) var keyEventsSeen = 0
    private(set) var lastTriggerDate: Date?

    init(trigger: String, caseSensitive: Bool) {
        matcher = TriggerMatcher(trigger: trigger, caseSensitive: caseSensitive)
    }

    func update(trigger: String, caseSensitive: Bool) {
        matcher.trigger = trigger
        matcher.caseSensitive = caseSensitive
    }

    static var hasPermission: Bool { CGPreflightListenEventAccess() }

    /// Shows the system prompt (first time only) and adds the app to the Input Monitoring list.
    static func requestPermission() {
        CGRequestListenEventAccess()
    }

    /// Returns false if the tap could not be created, which means permission is missing.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask: CGEventMask = [CGEventType.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
            .reduce(0) { $0 | (1 << $1.rawValue) }

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                Unmanaged<KeyMonitor>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
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
        log.info("Event tap started (input monitoring preflight: \(Self.hasPermission, privacy: .public))")

        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            _ = self?.matcher.feed(.reset)
        }
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
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            log.error("Event tap was disabled by the system (type \(type.rawValue, privacy: .public)); re-enabling")
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        case .keyDown:
            keyEventsSeen += 1
            if keyEventsSeen == 1 {
                log.info("First key event received")
            }
        default:
            // Mouse clicks can move the text cursor, so whatever was typed before no longer counts.
            _ = matcher.feed(.reset)
            return
        }

        // Ignore typing into WordLock's own windows (e.g. while setting the trigger word).
        if NSApp.isActive {
            _ = matcher.feed(.reset)
            return
        }

        if matcher.feed(Self.input(for: event)) {
            lastTriggerDate = Date()
            log.info("Trigger word matched")
            onTrigger?()
        }
    }

    private static func input(for event: CGEvent) -> TriggerMatcher.Input {
        if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl) {
            return .reset
        }

        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case 51: // delete (backspace)
            return .backspace
        case 53, 117, 115, 119, 116, 121, 123, 124, 125, 126: // esc, fwd delete, home, end, page up/down, arrows
            return .reset
        default:
            break
        }

        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return .text("") }
        return .text(String(utf16CodeUnits: buffer, count: length))
    }
}
