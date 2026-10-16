import Foundation

enum ScreenLocker {
    private typealias LockFunction = @convention(c) () -> Int32

    /// `SACLockScreenImmediate` is what the Apple menu's "Lock Screen" item uses. It is a private
    /// symbol, so it is looked up at runtime and we fall back to sleeping the display if it is gone.
    private static let lockFunction: LockFunction? = {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let handle = dlopen(path, RTLD_LAZY),
              let symbol = dlsym(handle, "SACLockScreenImmediate")
        else { return nil }
        return unsafeBitCast(symbol, to: LockFunction.self)
    }()

    static func lock() {
        if let lockFunction {
            let result = lockFunction()
            log.info("SACLockScreenImmediate returned \(result, privacy: .public)")
            if result == 0 { return }
        } else {
            log.error("SACLockScreenImmediate unavailable")
        }
        log.info("Falling back to pmset displaysleepnow")
        // Locks only if "Require password after screen saver begins or display is turned off"
        // is set to "Immediately" (the macOS default).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        try? process.run()
    }
}
