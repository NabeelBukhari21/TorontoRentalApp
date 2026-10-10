//
//  FormValidation.swift
//  RentalApp (Purrperty)
//
//  Core — Form field validation.
//
//  ─────────────────────────────────────────────────────────────────
//  VALIDATE ON BLUR, NOT ON EVERY KEYSTROKE
//  ─────────────────────────────────────────────────────────────────
//  Showing "Enter a valid email" while someone is still typing the
//  first character is the single most common way a form feels hostile.
//  `Field` therefore tracks whether it has been *touched*, and only
//  surfaces an error once the user has left it — while still reporting
//  validity immediately so the submit button can enable itself.
//
//  The rules are values, so the same `.required` or `.range` reads the
//  same in every form and nothing gets re-implemented per screen.
//

import Foundation

// MARK: - Rule

struct ValidationRule<Value>: Sendable {

    let message: String
    private let test: @Sendable (Value) -> Bool

    init(_ message: String, test: @escaping @Sendable (Value) -> Bool) {
        self.message = message
        self.test = test
    }

    func validate(_ value: Value) -> String? {
        test(value) ? nil : message
    }
}

extension ValidationRule where Value == String {

    static func required(_ what: String = "This field") -> Self {
        .init("\(what) is required") {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    static func minLength(_ count: Int, _ what: String = "This field") -> Self {
        .init("\(what) must be at least \(count) characters") {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).count >= count
        }
    }

    static func maxLength(_ count: Int) -> Self {
        .init("Keep this under \(count) characters") { $0.count <= count }
    }

    static var email: Self {
        .init("Enter a valid email address") { value in
            value.isEmpty || value.range(
                of: #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#,
                options: .regularExpression
            ) != nil
        }
    }

    /// Canadian postal code, `A1A 1A1`. Optional-friendly: empty passes,
    /// because "not provided" is a separate concern from "malformed".
    static var postalCode: Self {
        .init("Enter a valid postal code") { value in
            value.isEmpty || value.uppercased().range(
                of: #"^[A-Z]\d[A-Z][ -]?\d[A-Z]\d$"#,
                options: .regularExpression
            ) != nil
        }
    }

    static var phone: Self {
        .init("Enter a valid phone number") { value in
            value.isEmpty || value.filter(\.isNumber).count >= 10
        }
    }

    /// A whole number within bounds, entered as text.
    static func integer(in range: ClosedRange<Int>, _ what: String = "Value") -> Self {
        .init("\(what) must be between \(range.lowerBound) and \(range.upperBound)") { value in
            guard let number = Int(value.trimmingCharacters(in: .whitespaces)) else {
                return value.isEmpty
            }
            return range.contains(number)
        }
    }

    static func currency(min: Decimal = 0, _ what: String = "Amount") -> Self {
        .init("\(what) must be \(min) or more") { value in
            guard !value.isEmpty else { return true }
            guard let number = Decimal(string: value.filter { $0.isNumber || $0 == "." }) else {
                return false
            }
            return number >= min
        }
    }
}

// MARK: - Field

/// One form field: its value, whether it has been visited, and its rules.
@MainActor
@Observable
final class Field {

    var value: String {
        didSet { if value != oldValue { hasChanged = true } }
    }

    /// True once the user has left the field. Gates error display.
    private(set) var isTouched = false
    private(set) var hasChanged = false

    private let rules: [ValidationRule<String>]

    init(_ initial: String = "", rules: [ValidationRule<String>] = []) {
        self.value = initial
        self.rules = rules
    }

    /// The first broken rule, regardless of whether it should be shown.
    var validationError: String? {
        for rule in rules {
            if let message = rule.validate(value) { return message }
        }
        return nil
    }

    /// What the field should actually display — nothing until touched.
    var displayedError: String? {
        isTouched ? validationError : nil
    }

    var isValid: Bool { validationError == nil }

    var trimmed: String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    var intValue: Int? { Int(trimmed) }
    var decimalValue: Decimal? { Decimal(string: trimmed.filter { $0.isNumber || $0 == "." }) }
    var optionalTrimmed: String? { trimmed.isEmpty ? nil : trimmed }

    func markTouched() { isTouched = true }

    /// Called on submit so every broken rule becomes visible at once.
    func revealErrors() { isTouched = true }

    func reset(to newValue: String = "") {
        value = newValue
        isTouched = false
        hasChanged = false
    }
}

// MARK: - Form

/// A group of fields with whole-form validity.
@MainActor
protocol ValidatedForm: AnyObject {
    var fields: [Field] { get }
}

extension ValidatedForm {

    var isValid: Bool { fields.allSatisfy(\.isValid) }

    /// True when the user has actually edited something. Used to decide
    /// whether closing the sheet needs a "discard changes?" prompt.
    var isDirty: Bool { fields.contains(where: \.hasChanged) }

    /// Reveals every error at once. Returns whether the form may submit.
    @discardableResult
    func validateAll() -> Bool {
        fields.forEach { $0.revealErrors() }
        return isValid
    }
}
