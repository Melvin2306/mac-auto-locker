import CoreGraphics
import Foundation

enum ScreenLocker {
    private typealias LockFunction = @convention(c) () -> Int32

    /// `SACLockScreenImmediate` is what the Apple menu's "Lock Screen" item uses. It is a private
    /// symbol, so it is looked up at runtime, only on first use.
    private static let lockFunction: LockFunction? = {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate")
        else { return nil }
        return unsafeBitCast(symbol, to: LockFunction.self)
    }()

    static var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    static func lock() {
        if let lockFunction {
            let result = lockFunction()
            log.notice("SACLockScreenImmediate returned \(result, privacy: .public)")
        } else {
            log.error("SACLockScreenImmediate unavailable")
        }

        // Verify it worked; if not, sleep the display, which locks when "Require password after
        // screen saver begins or display is turned off" is "Immediately" (the macOS default).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            if isScreenLocked {
                log.notice("Screen is locked")
                return
            }
            log.error("Screen not locked after SACLockScreenImmediate; falling back to pmset displaysleepnow")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["displaysleepnow"]
            try? process.run()
        }
    }
}
