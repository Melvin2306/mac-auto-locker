import Foundation

/// Keeps a short rolling buffer of recently typed characters and reports when
/// the buffer ends with the trigger word.
///
/// The buffer lives only in memory, is capped to a small size, and is cleared
/// whenever the trigger fires or the typing context changes (cursor moves,
/// shortcuts, mouse clicks). Nothing typed is ever persisted.
public struct TriggerMatcher {
    public enum Input: Equatable {
        /// Characters produced by a key press.
        case text(String)
        /// The delete/backspace key.
        case backspace
        /// Something that invalidates the current typing context
        /// (arrow keys, mouse clicks, keyboard shortcuts, app switches...).
        case reset
    }

    public var trigger: String {
        didSet { reset() }
    }

    public var caseSensitive: Bool {
        didSet { reset() }
    }

    private var buffer: [Character] = []

    public init(trigger: String, caseSensitive: Bool = false) {
        self.trigger = trigger
        self.caseSensitive = caseSensitive
    }

    /// The trigger as it is compared: surrounding whitespace removed.
    public var normalizedTrigger: String {
        trigger.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var capacity: Int {
        max(64, normalizedTrigger.count * 2)
    }

    /// Feeds one input event. Returns `true` when the trigger word was just completed.
    public mutating func feed(_ input: Input) -> Bool {
        switch input {
        case .reset:
            reset()
            return false
        case .backspace:
            if !buffer.isEmpty { buffer.removeLast() }
            return false
        case .text(let string):
            if string.unicodeScalars.contains(where: Self.isFunctionKey) {
                reset()
                return false
            }
            buffer.append(contentsOf: string)
            if buffer.count > capacity {
                buffer.removeFirst(buffer.count - capacity)
            }
            if matches() {
                reset()
                return true
            }
            return false
        }
    }

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
    }

    private func matches() -> Bool {
        let target = normalizedTrigger
        guard !target.isEmpty, buffer.count >= target.count else { return false }
        let tail = String(buffer.suffix(target.count))
        if caseSensitive {
            return tail == target
        }
        return tail.compare(target, options: [.caseInsensitive]) == .orderedSame
    }

    /// AppKit reports arrow/function keys as characters in the private-use range U+F700–U+F8FF.
    private static func isFunctionKey(_ scalar: Unicode.Scalar) -> Bool {
        (0xF700...0xF8FF).contains(scalar.value)
    }
}
