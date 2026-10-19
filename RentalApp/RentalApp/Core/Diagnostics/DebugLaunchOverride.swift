//
//  DebugLaunchOverride.swift
//  RentalApp (Purrperty)
//
//  Diagnostics — Start the app at a specific flow while developing it.
//
//  A restored session sends every launch straight to Home, which makes
//  iterating on onboarding or sign-in painful. Pass a launch argument and
//  the session coordinator starts there instead:
//
//      -PurrpertyStartAt onboarding     the onboarding pager
//      -PurrpertyStartAt login          the sign-in screen
//      -PurrpertyStartAt gettingStarted first property → notifications →
//                                       plan, using the stored session
//      -PurrpertyStartAt home           the main app, signing in as the
//                                       mock demo owner if no session is
//                                       stored (for screenshots and UI work)
//      -PurrpertyStartAt tenant         the tenant portal, signed in as the
//                                       mock demo tenant
//
//  The override is non-destructive: the stored session and onboarding flag
//  are left untouched, so removing the argument returns to normal launch.
//  It exists in DEBUG builds only — release builds can't be steered.
//
//  Set it in Xcode via the "RentalApp (Onboarding)" scheme, or
//  Product ▸ Scheme ▸ Edit Scheme… ▸ Run ▸ Arguments.
//

import Foundation

enum DebugLaunchOverride: String, CaseIterable, Sendable {
    case onboarding
    case login
    case gettingStarted
    case home
    case tenant

    /// Launch arguments of the form `-Key value` land in the
    /// `UserDefaults` argument domain, so no parsing is needed.
    static let argumentKey = "PurrpertyStartAt"

    /// The override for this launch, if any. Always `nil` outside DEBUG.
    static var current: DebugLaunchOverride? {
        #if DEBUG
        UserDefaults.standard.string(forKey: argumentKey).flatMap(DebugLaunchOverride.init(rawValue:))
        #else
        nil
        #endif
    }
}
