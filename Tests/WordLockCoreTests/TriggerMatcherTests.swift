import Testing
@testable import WordLockCore

/// Feeds text one character at a time, like a keyboard would.
private func type(_ text: String, into matcher: inout TriggerMatcher) -> Bool {
    var fired = false
    for character in text where matcher.feed(String(character)) {
        fired = true
    }
    return fired
}

@Test func firesWhenTriggerIsTyped() {
    var matcher = TriggerMatcher(triggers: ["pineapple"])
    #expect(type("I like pineapple", into: &matcher))
}

@Test func doesNotFireOnPartialWord() {
    var matcher = TriggerMatcher(triggers: ["pineapple"])
    #expect(!type("pineappl", into: &matcher))
}

@Test func supportsMultipleTriggers() {
    var matcher = TriggerMatcher(triggers: ["sushi", "pineapple", "go"])
    #expect(type("i want sushi", into: &matcher))
    #expect(type("pineapple", into: &matcher))
    #expect(type("lets go", into: &matcher))
    #expect(!type("pizza", into: &matcher))
}

@Test func shortTriggerMatchesInsideLongerBuffer() {
    var matcher = TriggerMatcher(triggers: ["averyveryverylongword", "hi"])
    #expect(type("xxxxxxxxxxxxxxxxxxxxxxxxxxxxhi", into: &matcher))
}

@Test func isCaseInsensitiveByDefault() {
    var matcher = TriggerMatcher(triggers: ["Pineapple"])
    #expect(type("PINEAPPLE", into: &matcher))
}

@Test func foldsNonASCIICase() {
    var matcher = TriggerMatcher(triggers: ["Äpfel"])
    #expect(type("äPFEL", into: &matcher))
}

@Test func respectsCaseSensitivity() {
    var matcher = TriggerMatcher(triggers: ["Pineapple"], caseSensitive: true)
    #expect(!type("pineapple", into: &matcher))
    #expect(type("Pineapple", into: &matcher))
}

@Test func backspaceRemovesCharacters() {
    var matcher = TriggerMatcher(triggers: ["lockme"])
    _ = type("lockmz", into: &matcher)
    matcher.backspace()
    #expect(type("e", into: &matcher))
}

@Test func resetBreaksTheSequence() {
    var matcher = TriggerMatcher(triggers: ["lockme"])
    _ = type("lock", into: &matcher)
    matcher.reset()
    #expect(!type("me", into: &matcher))
}

@Test func arrowKeysAndReturnResetTheBuffer() {
    var matcher = TriggerMatcher(triggers: ["lockme"])
    _ = type("lock", into: &matcher)
    _ = matcher.feed(0xF702) // left arrow
    #expect(!type("me", into: &matcher))
    _ = type("lock", into: &matcher)
    _ = matcher.feed(0x0D) // return
    #expect(!type("me", into: &matcher))
}

@Test func firesOnlyOncePerCompletion() {
    var matcher = TriggerMatcher(triggers: ["abc"])
    #expect(type("abc", into: &matcher))
    #expect(!type("bc", into: &matcher))
    #expect(type("abc", into: &matcher))
}

@Test func emptyAndWhitespaceTriggersAreIgnored() {
    var matcher = TriggerMatcher(triggers: ["   ", ""])
    #expect(matcher.isEmpty)
    #expect(!type("   anything   ", into: &matcher))
}

@Test func triggersAreTrimmedAndDeduplicated() {
    #expect(TriggerMatcher.normalize([" sushi ", "sushi", "", "taco"]) == ["sushi", "taco"])
    var matcher = TriggerMatcher(triggers: [" lockme "])
    #expect(type("lockme", into: &matcher))
}

@Test func triggerMayContainSpaces() {
    var matcher = TriggerMatcher(triggers: ["lock it"])
    #expect(type("please lock it", into: &matcher))
}

@Test func longInputWrapsTheRingBuffer() {
    var matcher = TriggerMatcher(triggers: ["lockme"])
    _ = type(String(repeating: "x", count: 10_003), into: &matcher)
    #expect(type("lockme", into: &matcher))
}

@Test func reconfiguringClearsBuffer() {
    var matcher = TriggerMatcher(triggers: ["abc"])
    _ = type("ab", into: &matcher)
    matcher.configure(triggers: ["abcd"], caseSensitive: false)
    #expect(!type("cd", into: &matcher))
}
