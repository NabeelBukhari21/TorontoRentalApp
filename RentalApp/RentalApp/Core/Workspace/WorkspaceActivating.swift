//
//  WorkspaceActivating.swift
//  RentalApp (Purrperty)
//
//  Core — Points the app's data at the signed-in account's workspace.
//
//  `SessionViewModel` calls this on every state change, before the new
//  state renders, so the first screen an account sees already reads its
//  own data. On the real backend RLS does this per request and nothing
//  needs switching; the mock backend holds one world at a time.
//

import Foundation

@MainActor
protocol WorkspaceActivating: AnyObject {
    /// Called with the session the app is moving to, or nil when signing
    /// out.
    func activate(for session: AuthSession?)
}
