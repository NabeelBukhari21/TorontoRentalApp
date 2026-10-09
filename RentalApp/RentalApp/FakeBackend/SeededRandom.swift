//
//  SeededRandom.swift
//  RentalApp (RentOS)
//
//  Fake Backend — Deterministic randomness.
//
//  The generated dataset must be *identical on every launch*: a demo
//  where the same tenant has different rent each time is worse than
//  no demo. A fixed-seed xorshift generator gives varied-looking data
//  that is nonetheless perfectly reproducible.
//

import Foundation

/// Reproducible pseudo-random source (xorshift64*).
struct SeededRandom: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        // Avoid the zero state, which xorshift cannot escape.
        self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - Convenience

extension SeededRandom {

    /// Integer in a closed range.
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    /// Double in a closed range.
    mutating func double(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &self)
    }

    /// `true` with the given probability (0...1).
    mutating func chance(_ probability: Double) -> Bool {
        double(0...1) < probability
    }

    /// A uniformly chosen element. Callers guarantee non-empty pools.
    mutating func pick<T>(_ items: [T]) -> T {
        items[int(0...(items.count - 1))]
    }

    /// `count` distinct elements, or the whole pool if it is smaller.
    mutating func sample<T>(_ items: [T], count: Int) -> [T] {
        guard count < items.count else { return items.shuffled(using: &self) }
        return Array(items.shuffled(using: &self).prefix(count))
    }

    /// Weighted choice. Weights need not sum to one.
    mutating func weighted<T>(_ options: [(value: T, weight: Double)]) -> T {
        let total = options.reduce(0) { $0 + $1.weight }
        var roll = double(0...total)
        for option in options {
            roll -= option.weight
            if roll <= 0 { return option.value }
        }
        return options[options.count - 1].value
    }

    /// A deterministic UUID, so ids are stable across launches too.
    mutating func uuid() -> UUID {
        var bytes = [UInt8]()
        bytes.reserveCapacity(16)
        for _ in 0..<2 {
            withUnsafeBytes(of: next().littleEndian) { bytes.append(contentsOf: $0) }
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// A date offset from a reference by a random number of days.
    mutating func date(daysAgo range: ClosedRange<Int>, from reference: Date = .now) -> Date {
        let days = int(range)
        return Calendar.current.date(byAdding: .day, value: -days, to: reference) ?? reference
    }

    /// A date some days in the future.
    mutating func date(daysAhead range: ClosedRange<Int>, from reference: Date = .now) -> Date {
        let days = int(range)
        return Calendar.current.date(byAdding: .day, value: days, to: reference) ?? reference
    }
}

// MARK: - Relative Formatting

/// Shared date helpers so every generated string reads consistently.
enum FakeDateFormat {

    /// "26m ago", "3h ago", "2d ago", "1w ago".
    static func relative(_ date: Date, now: Date = .now) -> String {
        let seconds = max(now.timeIntervalSince(date), 0)
        switch seconds {
        case ..<60: return "Just now"
        case ..<3_600: return "\(Int(seconds / 60))m ago"
        case ..<86_400: return "\(Int(seconds / 3_600))h ago"
        case ..<604_800: return "\(Int(seconds / 86_400))d ago"
        case ..<2_592_000: return "\(Int(seconds / 604_800))w ago"
        default: return "\(Int(seconds / 2_592_000))mo ago"
        }
    }

    /// Compact form for message and notification lists: "18m", "3h", "2d".
    static func compact(_ date: Date, now: Date = .now) -> String {
        let seconds = max(now.timeIntervalSince(date), 0)
        switch seconds {
        case ..<3_600: return "\(max(Int(seconds / 60), 1))m"
        case ..<86_400: return "\(Int(seconds / 3_600))h"
        case ..<604_800: return "\(Int(seconds / 86_400))d"
        default: return monthDay(date)
        }
    }

    /// "Aug 2026"
    static func monthYear(_ date: Date) -> String {
        formatter(.init("MMM yyyy")).string(from: date)
    }

    /// "Jul 3"
    static func monthDay(_ date: Date) -> String {
        formatter(.init("MMM d")).string(from: date)
    }

    /// "Tue 4:12 PM"
    static func dayTime(_ date: Date) -> String {
        formatter(.init("EEE h:mm a")).string(from: date)
    }

    /// "9:41 AM"
    static func time(_ date: Date) -> String {
        formatter(.init("h:mm a")).string(from: date)
    }

    /// "Thu, 10:00 AM"
    static func dueLabel(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today, \(time(date))" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow, \(time(date))" }
        let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
        if days < 7 { return formatter(.init("EEE, h:mm a")).string(from: date) }
        return monthDay(date)
    }

    private struct Pattern: Hashable { let value: String; init(_ v: String) { value = v } }

    private static var cache: [Pattern: DateFormatter] = [:]

    private static func formatter(_ pattern: Pattern) -> DateFormatter {
        if let cached = cache[pattern] { return cached }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_CA")
        formatter.dateFormat = pattern.value
        cache[pattern] = formatter
        return formatter
    }
}
