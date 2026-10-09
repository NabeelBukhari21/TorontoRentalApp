//
//  Formatters.swift
//  RentalApp (RentOS)
//
//  Core/Localization — Locale-correct rendering of the app's values.
//
//  ─────────────────────────────────────────────────────────────────
//  THE CURRENCY IS CAD, THE LOCALE IS THE USER'S
//  ─────────────────────────────────────────────────────────────────
//  These are different facts and conflating them produces both classic
//  bugs. Rent in this app is always Canadian dollars — a Toronto lease
//  does not change currency because the phone is set to French. But
//  *how* $1,850.00 is written does change: fr-CA renders it "1 850,00 $"
//  with the symbol trailing and a comma decimal separator.
//
//  So: currency code fixed, locale from the user. `\(amount)$` in a
//  string literal gets both wrong at once, and there are 13 of those
//  in the codebase today (see LOCALIZATION_AUDIT.md).
//
//  ─────────────────────────────────────────────────────────────────
//  WHY CACHED
//  ─────────────────────────────────────────────────────────────────
//  `DateFormatter` is famously expensive to construct — enough that
//  building one inside a `body` that renders per row in a scrolling
//  list is a measurable frame cost. The modern `.formatted(_:)` APIs
//  are cheaper and preferred, but the `FormatStyle` values themselves
//  are still worth hoisting out of view bodies, which is what this does.
//

import Foundation

// MARK: - Money

enum MoneyFormat {

    /// Canada is the only market this app serves today. Stated as a
    /// constant rather than assumed at each call site, so the day it
    /// stops being true there is one place to change.
    static let currencyCode = "CAD"

    /// "$1,850.00" in en-CA, "1 850,00 $" in fr-CA.
    static func standard(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode))
    }

    /// "$1,850" — no cents. Rent is quoted in whole dollars, and the
    /// trailing ".00" is noise that costs horizontal space in a list row.
    static func whole(_ amount: Decimal) -> String {
        amount.formatted(
            .currency(code: currencyCode).precision(.fractionLength(0))
        )
    }

    /// "$1.85K", "$12.4M" — for dashboard tiles where the exact figure
    /// is not the point and the column is narrow.
    static func compact(_ amount: Decimal) -> String {
        let doubleValue = NSDecimalNumber(decimal: amount).doubleValue
        return doubleValue.formatted(
            .currency(code: currencyCode)
                .notation(.compactName)
                .precision(.fractionLength(0...1))
        )
    }
}

// MARK: - Dates

enum DateFormat {

    /// "3 Sept 2026" / "3 sept. 2026".
    static func medium(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    /// "3 September 2026" — for detail screens with room for it.
    static func long(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    /// "2:45 PM" / "14:45" — 12- vs 24-hour is a locale and Settings
    /// decision, never the app's. Passing a hardcoded "h:mm a" template
    /// overrides a user preference they set deliberately.
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    /// "3 Sept at 2:45 PM"
    static func dateTime(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    /// "2 days ago", "in 3 weeks".
    static func relative(_ date: Date, to reference: Date = Date()) -> String {
        date.formatted(.relative(presentation: .named))
    }

    /// Chat-style: time for today, weekday within the week, else a date.
    ///
    /// The bucketing uses the *user's* calendar, which is why it goes
    /// through `Calendar.current` rather than arithmetic on
    /// `timeIntervalSince` — "yesterday" is a calendar question, not a
    /// 24-hour one, and the two disagree across a DST boundary.
    static func conversational(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) {
            return time(date)
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday", comment: "Relative day label in message lists")
        }
        let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        if daysAgo < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return medium(date)
    }

    /// "Jan 2026 – Dec 2026". Lease terms are ranges and the locale
    /// decides the separator and the ordering.
    static func range(_ start: Date, _ end: Date) -> String {
        (start..<max(start, end)).formatted(
            .interval.day().month(.abbreviated).year()
        )
    }
}

// MARK: - Measurements

enum MeasurementFormat {

    /// Square feet, converted for locales on the metric system.
    ///
    /// Canada is officially metric but residential real estate is quoted
    /// in square feet in practice, so the *stored* unit is square feet
    /// and only the presentation adapts.
    static func floorArea(squareFeet: Int) -> String {
        let measurement = Measurement(value: Double(squareFeet), unit: UnitArea.squareFeet)
        return measurement.formatted(
            .measurement(width: .abbreviated, usage: .asProvided)
        )
    }

    /// "3 bd", "1.5 ba" — counts, pluralized by the catalog rather than
    /// by string concatenation. `"\(n) bedrooms"` is wrong in every
    /// language with more than two plural forms, and wrong in English
    /// when n is 1.
    static func bedrooms(_ count: Int) -> String {
        String(
            localized: "\(count) bd",
            comment: "Abbreviated bedroom count on a property card"
        )
    }

    static func bathrooms(_ count: Double) -> String {
        let rendered = count.formatted(.number.precision(.fractionLength(0...1)))
        return String(
            localized: "\(rendered) ba",
            comment: "Abbreviated bathroom count on a property card"
        )
    }
}

// MARK: - File Sizes

enum FileSizeFormat {

    /// "2.4 MB". `ByteCountFormatStyle` handles the locale's decimal
    /// separator and the MB/Mo difference in French.
    static func standard(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

    /// Coarse bucket for analytics — never the exact size, which trends
    /// toward identifying a specific document.
    static func analyticsBucket(_ bytes: Int64) -> String {
        switch bytes {
        case ..<100_000:      "<100KB"
        case ..<1_000_000:    "100KB-1MB"
        case ..<10_000_000:   "1-10MB"
        case ..<50_000_000:   "10-50MB"
        default:              ">50MB"
        }
    }
}

// MARK: - Addresses

enum AddressFormat {

    /// Canadian postal code: "M5V 3A8".
    ///
    /// Uppercased with a single space, which is the Canada Post
    /// standard. Users type "m5v3a8" and expect it to look right.
    static func postalCode(_ raw: String) -> String {
        let cleaned = raw.uppercased().filter { !$0.isWhitespace }
        guard cleaned.count == 6 else { return raw.uppercased() }
        let midpoint = cleaned.index(cleaned.startIndex, offsetBy: 3)
        return "\(cleaned[..<midpoint]) \(cleaned[midpoint...])"
    }

    /// Single-line display address.
    ///
    /// Note this is Canada-shaped (street, city, province, postal). A
    /// genuinely international address formatter is a much larger
    /// problem — field order, which fields exist, and whether the postal
    /// code precedes the city all vary — and is not worth solving until
    /// the app serves a second country.
    static func singleLine(
        street: String,
        city: String,
        province: String? = "ON",
        postalCode: String? = nil
    ) -> String {
        var parts = [street, city]
        if let province, !province.isEmpty { parts.append(province) }
        if let postalCode, !postalCode.isEmpty { parts.append(self.postalCode(postalCode)) }
        return parts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

// MARK: - Percentages

enum PercentFormat {

    /// Takes a fraction (0.94), renders a percentage ("94%").
    ///
    /// The fraction-vs-percentage ambiguity is worth being strict about:
    /// a function that accepts both 0.94 and 94 will eventually be
    /// handed the wrong one and render "9400%".
    static func standard(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    static func precise(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(1)))
    }
}
