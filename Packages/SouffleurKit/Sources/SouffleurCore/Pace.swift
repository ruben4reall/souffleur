import CoreGraphics
import Foundation

/// Reading pace: how long a script takes, how fast to roll it, how fast someone is reading.
public enum Pace {
    /// A comfortable pace for reading to a camera, in words per minute.
    public static let conversational: Double = 140

    public static func readingTime(words: Int, wordsPerMinute: Double) -> TimeInterval {
        guard words > 0, wordsPerMinute > 0 else { return 0 }
        return Double(words) / wordsPerMinute * 60
    }

    /// "1:05", or "1:02:05" past an hour.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600, minutes = total / 60 % 60, rest = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// The scrolling speed that shows `wordsPerMinute` when a line holds `wordsPerLine` words.
    public static func pointsPerSecond(wordsPerMinute: Double, wordsPerLine: Double, lineHeight: CGFloat) -> CGFloat {
        guard wordsPerLine > 0 else { return 0 }
        return CGFloat(wordsPerMinute / wordsPerLine) * lineHeight / 60
    }
}

/// The reader's pace over the last few seconds, from the place in the script over time.
public struct PaceMeter: Sendable {
    public let span: TimeInterval
    private var samples: [(time: Date, word: Int)] = []

    public init(span: TimeInterval = 10) {
        self.span = span
    }

    public mutating func record(wordIndex: Int, at time: Date) {
        samples.append((time, wordIndex))
        samples.removeAll { time.timeIntervalSince($0.time) > span }
    }

    public mutating func reset() { samples.removeAll() }

    /// Words per minute over the span, or nil until two samples at least two seconds apart exist.
    public var wordsPerMinute: Double? {
        guard let first = samples.first, let last = samples.last else { return nil }
        let elapsed = last.time.timeIntervalSince(first.time)
        guard elapsed >= 2 else { return nil }
        return Double(max(0, last.word - first.word)) / elapsed * 60
    }
}
