/// Detects when any of a set of trigger words has just been typed.
///
/// Recently typed characters live in a fixed-size ring buffer only as long as the longest trigger,
/// so matching a keystroke never allocates. The buffer is in memory only, never persisted, and is
/// cleared whenever a trigger fires or the typing context changes (cursor moves, shortcuts, clicks).
public struct TriggerMatcher {
    public private(set) var caseSensitive = false
    private var triggers: [[UInt32]] = []
    private var ring: [UInt32] = []
    private var head = 0 // next write position
    private var count = 0 // valid characters before `head`

    public init(triggers: [String] = [], caseSensitive: Bool = false) {
        configure(triggers: triggers, caseSensitive: caseSensitive)
    }

    /// Trimmed, non-empty, de-duplicated words, in their original order.
    public static func normalize(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words
            .map { $0.trimmingWhitespace() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public mutating func configure(triggers words: [String], caseSensitive: Bool) {
        self.caseSensitive = caseSensitive
        triggers = Self.normalize(words).map { $0.unicodeScalars.map { fold($0.value) } }
        ring = Array(repeating: 0, count: triggers.map(\.count).max() ?? 0)
        head = 0
        count = 0
    }

    public var isEmpty: Bool { triggers.isEmpty }

    /// Feeds one typed Unicode scalar. Returns `true` when it completes a trigger word.
    public mutating func feed(_ scalar: UInt32) -> Bool {
        guard !ring.isEmpty else { return false }
        // Control characters (return, tab, escape...) and AppKit's private-use function-key range
        // (arrows, home, end...) end the current run of typing.
        if scalar < 0x20 || scalar == 0x7F || (0xF700...0xF8FF).contains(scalar) {
            reset()
            return false
        }
        ring[head] = fold(scalar)
        head = head + 1 == ring.count ? 0 : head + 1
        if count < ring.count { count += 1 }

        for trigger in triggers where trigger.count <= count && endsWith(trigger) {
            reset()
            return true
        }
        return false
    }

    /// Convenience for feeding a whole string. Returns `true` if any trigger was completed.
    public mutating func feed(_ text: String) -> Bool {
        var fired = false
        for scalar in text.unicodeScalars where feed(scalar.value) {
            fired = true
        }
        return fired
    }

    public mutating func backspace() {
        guard count > 0 else { return }
        head = head == 0 ? ring.count - 1 : head - 1
        count -= 1
    }

    public mutating func reset() {
        count = 0
    }

    private func endsWith(_ trigger: [UInt32]) -> Bool {
        var index = head
        for scalar in trigger.reversed() {
            index = index == 0 ? ring.count - 1 : index - 1
            if ring[index] != scalar { return false }
        }
        return true
    }

    private func fold(_ value: UInt32) -> UInt32 {
        if caseSensitive { return value }
        if value >= 0x41 && value <= 0x5A { return value + 0x20 } // ASCII fast path
        if value < 0x80 { return value }
        guard let scalar = Unicode.Scalar(value) else { return value }
        let lower = scalar.properties.lowercaseMapping.unicodeScalars
        return lower.count == 1 ? lower.first!.value : value
    }
}

private extension String {
    func trimmingWhitespace() -> String {
        let scalars = unicodeScalars
        guard let start = scalars.firstIndex(where: { !$0.properties.isWhitespace }),
              let end = scalars.lastIndex(where: { !$0.properties.isWhitespace })
        else { return "" }
        return String(scalars[start...end])
    }
}
