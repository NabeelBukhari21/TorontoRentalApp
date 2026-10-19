//
//  ShortcutContext.swift
//  RentalApp (Purrperty)
//
//  Intents — What a Siri or Shortcuts action runs against: the app's
//  container, and the signed-in person's permissions.
//
//  Intents run without the app's UI, sometimes without the app having
//  launched this session, so they read the stored session directly rather
//  than going through `SessionViewModel`.
//

import AppIntents
import Foundation

enum ShortcutError: Error, CustomLocalizedStringResourceConvertible {
    case signedOut
    case notStaff
    case nothingOwing
    case failed(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .signedOut: "Open Purrperty and sign in first."
        case .notStaff: "That's only for owners and property managers."
        case .nothingOwing: "Nobody owes rent right now."
        case .failed(let message): "\(message)"
        }
    }
}

@MainActor
enum ShortcutContext {

    static var container: AppContainer { .shared }

    /// The signed-in owner or manager. Rent and maintenance across the
    /// portfolio are staff information, so tenants and vendors are refused.
    @discardableResult
    static func requireStaff() throws -> AuthSession {
        guard let session = container.sessionStore.load() else { throw ShortcutError.signedOut }
        guard session.role.isStaff else { throw ShortcutError.notStaff }
        return session
    }
}
