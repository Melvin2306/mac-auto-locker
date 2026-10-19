# WordLock

A tiny macOS menu bar app that locks your Mac the moment you type one of your trigger words, in any app.

Handy as a panic button. If someone walks up to your screen, type a trigger word and the Mac locks
right away.

Requires macOS 13 (Ventura) or later. Runs natively on Apple silicon and Intel.

## Download and install

1. Download **WordLock.dmg** from the
   [latest release](https://github.com/Melvin2306/mac-auto-locker/releases/latest).
2. Open the DMG and drag **WordLock** onto the **Applications** folder.
3. Open WordLock from *Applications*.

The release build is not notarized by Apple, so the first time you open it macOS says it can't
verify the developer. To open it anyway:

- **macOS 15 (Sequoia) and later:** click *Done*, then go to *System Settings → Privacy & Security*,
  scroll down to the message about WordLock and click **Open Anyway**. Confirm with your password.
- **macOS 13–14:** right-click (or Control-click) WordLock in *Applications*, choose **Open**, then
  click **Open** in the dialog.

You only have to do this once. If you'd rather not trust a downloaded build, see
[Build from source](#build-from-source).

## Set up

1. **Grant Input Monitoring.** On first launch macOS asks for *Input Monitoring* permission.
   Turn WordLock on under *System Settings → Privacy & Security → Input Monitoring* (the settings
   window has an *Open System Settings…* button that takes you there). Without it the app can't
   see keystrokes. WordLock keeps checking and starts on its own once the permission is granted. If
   it doesn't, quit and reopen it.
2. **Add trigger words.** The settings window opens on its own. Type a word into the field and press
   Return (or click *Add*). Add as many as you like, and remove one by selecting it and clicking
   *Remove*. Pick words you'd never type by accident.
3. **Try it in test mode.** Turn on *Test mode (beep instead of locking)*, then type a trigger word
   in any app. You hear a beep and see a ✓ in the menu bar instead of the Mac locking. Turn test
   mode off when you're happy.
4. **Optional:** turn on *Launch at login* so WordLock is always running.

For the lock to require a password, make sure *System Settings → Lock Screen → Require password
after screen saver begins or display is turned off* is set to *Immediately*.

## Use

Type any of your trigger words, in any app, and the Mac locks. You don't need to press Return or
type it in a text field.

- Backspace counts, so correcting a typo mid-word still triggers.
- Clicking, arrow keys, ⌘/⌃ shortcuts and switching apps reset what's been typed so far, so the word
  has to be typed in one go.
- *Case sensitive* in settings makes `Panic` and `panic` different words. It is off by default.

The lock icon in the menu bar shows the status:

| Icon | Meaning |
| --- | --- |
| Lock with shield | Active |
| Open lock | Paused (*Enabled* is off) |
| Lock with exclamation mark | Needs setup: Input Monitoring is missing or no trigger words are set |

Click it for the menu:

- **Enabled** (⌘E): pause or resume WordLock.
- **Lock Now** (⌘L): lock right away.
- **Settings…** (⌘,): manage trigger words and options.
- **Quit WordLock** (⌘Q).

The menu also shows how many key presses WordLock has seen and when it last triggered, which helps if
something isn't working.

### Troubleshooting

- **Nothing happens when I type a word.** Check the menu: if it says it needs Input Monitoring,
  grant the permission (see [Set up](#set-up)). If the menu says another app has *Secure Input* on,
  that app (often a password manager or a terminal with secure keyboard entry) is hiding all typing
  from WordLock until you close it or leave its password field.
- **The Mac didn't lock, the screen only went dark.** WordLock falls back to sleeping the display if
  the normal lock doesn't take. Set *Require password* to *Immediately* (see above) so that also locks.
- **It stopped working after an update.** macOS ties the Input Monitoring permission to the app's
  signature. Remove WordLock from the Input Monitoring list, add it again, and reopen the app.

### Uninstall

Quit WordLock from its menu, then move `/Applications/WordLock.app` to the Trash. To remove the
saved settings and the permission entry as well:

```sh
defaults delete dev.wordlock.WordLock
tccutil reset ListenEvent dev.wordlock.WordLock
```

## Privacy

WordLock never stores, logs or sends what you type. It makes no network connections.

- A listen-only `CGEventTap` sees key presses system-wide (`Sources/WordLock/KeyMonitor.swift`).
- `TriggerMatcher` keeps the last few typed characters **in memory only** and checks whether
  they end with any trigger word (`Sources/WordLockCore/TriggerMatcher.swift`). The buffer is
  capped at the length of the longest word, never written anywhere, and cleared after each match and
  whenever the typing context changes.
- Password fields use macOS Secure Input, which hides keystrokes from every event tap, so a
  password is never matched or seen.
- Typing inside WordLock's own windows is ignored, so adding a word doesn't lock you out.

## How it works

- Locking calls `SACLockScreenImmediate`, the same call the Apple menu's *Lock Screen* makes.
- After locking, WordLock checks that the screen really is locked. If it isn't, it falls back to
  `pmset displaysleepnow`.
- If another app has Secure Input on, the menu says so, because it hides all typing from WordLock.

### Resource use

- Plain AppKit: no SwiftUI or Combine, so the app sits at about 18 MB.
- Only key presses and left clicks are delivered to the app. Each keystroke is matched against a
  fixed-size buffer the length of the longest word, with no memory allocation.
- No polling once running. A low-frequency timer exists only while Input Monitoring is still missing.
- The settings window and the menu are built when opened and freed when closed.

## Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is not needed.

```sh
git clone https://github.com/Melvin2306/mac-auto-locker.git
cd mac-auto-locker
./scripts/install.sh      # builds, copies to /Applications, launches
```

Or build the app and a DMG without installing:

```sh
./scripts/build.sh --dmg  # → build/WordLock.app, build/WordLock.dmg
```

## Development

```sh
swift test                 # matcher unit tests
swift build                # debug build of the executable
```

### Note on code signing

Builds are **ad-hoc signed** by default. macOS ties the Input Monitoring grant to the signature, so
each rebuild counts as a new app and needs the permission again (`install.sh` resets the stale
entry for you). To ship a build that opens without the Gatekeeper warning, sign with a Developer ID
and notarize:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/build.sh --dmg
xcrun notarytool submit build/WordLock.dmg --keychain-profile <profile> --wait
xcrun stapler staple build/WordLock.dmg
```

### Releasing

Bump `VERSION`, build the DMG and attach it to a GitHub release:

```sh
./scripts/build.sh --dmg
gh release create "v$(cat VERSION)" build/WordLock.dmg --title "WordLock $(cat VERSION)"
```

## License

[MIT](LICENSE)
