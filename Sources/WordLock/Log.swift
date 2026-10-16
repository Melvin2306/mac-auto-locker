import os

/// Diagnostics only. Never log typed characters or the trigger word.
/// View with: /usr/bin/log stream --predicate 'subsystem == "dev.wordlock.WordLock"'
let log = Logger(subsystem: "dev.wordlock.WordLock", category: "app")
