import Testing
@testable import WordLockCore

private func type(_ text: String, into matcher: inout TriggerMatcher) -> Bool {
    var fired = false
    for character in text {
        if matcher.feed(.text(String(character))) { fired = true }
    }
    return fired
}

@Test func firesWhenTriggerIsTyped() {
    var matcher = TriggerMatcher(trigger: "pineapple")
    #expect(type("I like pineapple", into: &matcher))
}

@Test func doesNotFireOnPartialWord() {
    var matcher = TriggerMatcher(trigger: "pineapple")
    #expect(!type("pineappl", into: &matcher))
}

@Test func isCaseInsensitiveByDefault() {
    var matcher = TriggerMatcher(trigger: "Pineapple")
    #expect(type("PINEAPPLE", into: &matcher))
}

@Test func respectsCaseSensitivity() {
    var matcher = TriggerMatcher(trigger: "Pineapple", caseSensitive: true)
    #expect(!type("pineapple", into: &matcher))
    #expect(type("Pineapple", into: &matcher))
}

@Test func backspaceRemovesCharacters() {
    var matcher = TriggerMatcher(trigger: "lockme")
    _ = type("lockmz", into: &matcher)
    _ = matcher.feed(.backspace)
    #expect(type("e", into: &matcher))
}

@Test func resetBreaksTheSequence() {
    var matcher = TriggerMatcher(trigger: "lockme")
    _ = type("lock", into: &matcher)
    _ = matcher.feed(.reset)
    #expect(!type("me", into: &matcher))
}

@Test func arrowKeysResetTheBuffer() {
    var matcher = TriggerMatcher(trigger: "lockme")
    _ = type("lock", into: &matcher)
    _ = matcher.feed(.text("\u{F702}")) // left arrow
    #expect(!type("me", into: &matcher))
}

@Test func firesOnlyOncePerCompletion() {
    var matcher = TriggerMatcher(trigger: "abc")
    #expect(type("abc", into: &matcher))
    #expect(!type("bc", into: &matcher))
    #expect(type("abc", into: &matcher))
}

@Test func emptyOrWhitespaceTriggerNeverFires() {
    var matcher = TriggerMatcher(trigger: "   ")
    #expect(!type("   anything   ", into: &matcher))
}

@Test func triggerIsTrimmed() {
    var matcher = TriggerMatcher(trigger: " lockme ")
    #expect(type("lockme", into: &matcher))
}

@Test func longInputDoesNotGrowUnbounded() {
    var matcher = TriggerMatcher(trigger: "lockme")
    _ = type(String(repeating: "x", count: 10_000), into: &matcher)
    #expect(type("lockme", into: &matcher))
}

@Test func changingTriggerClearsBuffer() {
    var matcher = TriggerMatcher(trigger: "abc")
    _ = type("ab", into: &matcher)
    matcher.trigger = "abcd"
    #expect(!type("cd", into: &matcher))
}
