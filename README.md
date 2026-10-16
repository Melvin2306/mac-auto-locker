# WordLock

A tiny macOS menu bar app that locks your Mac the moment you type one of your trigger words, in any app.

Handy as a panic button. If someone walks up to your screen, type a trigger word and the Mac locks
right away.

## Install

```sh
./scripts/install.sh      # builds, copies to /Applications, launches
```

Or build the app and a DMG without installing:

```sh
./scripts/build.sh --dmg  # → build/WordLock.app, build/WordLock.dmg
```

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is not needed.

## First run

1. macOS asks for **Input Monitoring** permission. Allow it under
   *System Settings → Privacy & Security → Input Monitoring*. Without it the app can't see
   keystrokes. WordLock keeps checking and starts on its own once the permission is granted. If it
   doesn't, quit and reopen it.
2. The settings window opens. Type a trigger word and press Return to add it. Add as many as you like.
3. Optional: turn on **Test mode** to get a beep (and a ✓ in the menu bar) instead of a lock while
   you try it out.

The lock icon in the menu bar shows the status and has *Enabled*, *Lock Now*, *Settings…* and *Quit*.

## How it works

- A listen-only `CGEventTap` sees key presses system-wide (`Sources/WordLock/KeyMonitor.swift`).
- `TriggerMatcher` keeps the last few typed characters **in memory only** and checks whether
  they end with any trigger word (`Sources/WordLockCore/TriggerMatcher.swift`). The buffer is
  capped, never written anywhere, and cleared after each match and whenever the typing context
  changes: mouse clicks, arrow keys, ⌘/⌃ shortcuts, switching apps. Backspace is respected, so
  correcting a typo still counts.
- Password fields use macOS Secure Input, which hides keystrokes from every event tap, so a
  password is never matched or seen.
- Typing inside WordLock's own windows is ignored, so adding a word doesn't lock you out.
- After locking, WordLock checks that the screen really is locked. If it isn't, it falls back to
  `pmset displaysleepnow`.
- If another app has Secure Input on, the menu says so, because it hides all typing from WordLock.

## Resource use

- Plain AppKit: no SwiftUI or Combine, so the app sits at about 18 MB.
- Only key presses and left clicks are delivered to the app. Each keystroke is matched against a
  fixed-size buffer the length of the longest word, with no memory allocation.
- No polling once running. A low-frequency timer exists only while Input Monitoring is still missing.
- The settings window and the menu are built when opened and freed when closed.
- Locking calls `SACLockScreenImmediate`, the same call the Apple menu's *Lock Screen* makes.

## Development

```sh
swift test                 # matcher unit tests
swift build                # debug build of the executable
```

### Note on code signing

Builds are **ad-hoc signed** by default. macOS ties the Input Monitoring grant to the signature, so
each rebuild counts as a new app and needs the permission again (`install.sh` resets the stale
entry for you). To ship to other people, sign with a Developer ID and notarize:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build.sh --dmg
xcrun notarytool submit build/WordLock.dmg --keychain-profile <profile> --wait
xcrun stapler staple build/WordLock.dmg
```

Without that, people who download the DMG have to right-click → *Open* (or allow the app in
*Privacy & Security*) the first time.
