//
//  AuthSession.swift
//  RentalApp (Purrperty)
//
//  Core — Authentication vocabulary.
//
//  ─────────────────────────────────────────────────────────────────
//  WHY A SESSION IS A VALUE, NOT A BOOLEAN
//  ─────────────────────────────────────────────────────────────────
//  "Is the user signed in?" is never the real question. The app needs
//  to know *who*, in *which organization*, with *what role*, until
//  *when*, and whether they still owe a second factor. Modelling that
//  as one `Codable` value means session restoration is a decode, and
//  every permission check reads from one place.
//
//  Tokens live here but are persisted through `SessionStoring`, which
//  is Keychain-shaped on purpose — see `SessionStore`.
//

import Foundation

// MARK: - Role

/// Who someone is inside an organization.
///
/// Staff roles (owner, propertyManager) see the management app.
/// `tenant` and `vendor` are external counterparties who will get
/// their own restricted experiences — the enum carries that
/// distinction so routing never has to guess.
enum AppRole: String, Codable, Sendable, CaseIterable, Identifiable {
    case owner
    case propertyManager = "property_manager"
    case tenant
    case vendor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .owner: "Owner"
        case .propertyManager: "Property Manager"
        case .tenant: "Tenant"
        case .vendor: "Vendor"
        }
    }

    var subtitle: String {
        switch self {
        case .owner: "Full access to the portfolio, billing, and team"
        case .propertyManager: "Manage properties, tenants, and maintenance"
        case .tenant: "View your lease, pay rent, submit requests"
        case .vendor: "Receive work orders and book visits"
        }
    }

    var icon: String {
        switch self {
        case .owner: "crown.fill"
        case .propertyManager: DS.Icons.properties
        case .tenant: DS.Icons.tenant
        case .vendor: DS.Icons.vendor
        }
    }

    /// Staff roles use the full management app; the others get a
    /// restricted experience.
    var isStaff: Bool { self == .owner || self == .propertyManager }

    /// Roles that must belong to an organization before they can do
    /// anything — this is what makes org creation a required step.
    var requiresOrganization: Bool { isStaff }

    // MARK: Permissions

    var canManageBilling: Bool { self == .owner }
    var canManageTeam: Bool { self == .owner }
    var canManagePortfolio: Bool { isStaff }
    var canAssignVendors: Bool { isStaff }
    var canViewFinancials: Bool { isStaff }
    var canSubmitMaintenance: Bool { true }
}

// MARK: - Session

/// An authenticated session. Persisted verbatim and restored at launch.
struct AuthSession: Codable, Sendable, Equatable {

    // Identity
    let userID: String
    let email: String
    var fullName: String
    var role: AppRole

    /// Nil until the user creates or joins an organization. A staff
    /// session without one is what routes to org setup.
    var organizationID: String?
    var organizationName: String?

    // Credentials
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    // Security posture
    var mfaEnrolled: Bool
    var biometricEnabled: Bool

    let issuedAt: Date

    init(
        userID: String,
        email: String,
        fullName: String,
        role: AppRole,
        organizationID: String? = nil,
        organizationName: String? = nil,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        mfaEnrolled: Bool = false,
        biometricEnabled: Bool = false,
        issuedAt: Date = .now
    ) {
        self.userID = userID
        self.email = email
        self.fullName = fullName
        self.role = role
        self.organizationID = organizationID
        self.organizationName = organizationName
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.mfaEnrolled = mfaEnrolled
        self.biometricEnabled = biometricEnabled
        self.issuedAt = issuedAt
    }

    /// Whether the access token is still valid, with a small margin so
    /// a request never leaves with a token about to expire mid-flight.
    func isValid(asOf date: Date = .now, margin: TimeInterval = 60) -> Bool {
        expiresAt.timeIntervalSince(date) > margin
    }

    /// Staff who haven't set up an organization yet.
    var needsOrganization: Bool {
        role.requiresOrganization && organizationID == nil
    }

    var initials: String {
        fullName.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined().uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case fullName = "full_name"
        case role
        case organizationID = "organization_id"
        case organizationName = "organization_name"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case mfaEnrolled = "mfa_enrolled"
        case biometricEnabled = "biometric_enabled"
        case issuedAt = "issued_at"
    }
}

// MARK: - Multi-Factor

/// A second factor the server demands before issuing a session.
///
/// Present now so the sign-in flow already has a branch for it; the
/// mock service can raise one on demand, and a real provider slots in
/// without reshaping the flow.
struct MFAChallenge: Sendable, Equatable {

    enum Method: String, Codable, Sendable {
        case totp
        case sms
        case email

        var title: String {
            switch self {
            case .totp: "Authenticator app"
            case .sms: "Text message"
            case .email: "Email code"
            }
        }

        var instruction: String {
            switch self {
            case .totp: "Enter the 6-digit code from your authenticator app."
            case .sms: "We sent a 6-digit code to your phone."
            case .email: "We sent a 6-digit code to your email."
            }
        }
    }

    let challengeID: String
    let method: Method
    /// Masked destination, e.g. "•••• 4821".
    let hint: String?
    let expiresAt: Date
    let digitCount: Int

    /// Identity is the challenge ID: a resent code is a *different*
    /// challenge, and nothing else about it is worth comparing.
    static func == (lhs: MFAChallenge, rhs: MFAChallenge) -> Bool {
        lhs.challengeID == rhs.challengeID
    }

    init(
        challengeID: String,
        method: Method,
        hint: String? = nil,
        expiresAt: Date = .now.addingTimeInterval(300),
        digitCount: Int = 6
    ) {
        self.challengeID = challengeID
        self.method = method
        self.hint = hint
        self.expiresAt = expiresAt
        self.digitCount = digitCount
    }
}

// MARK: - Sign-In Outcome

/// What a credential submission produced. Sign-in is not a boolean —
/// it either completes or escalates to a second factor.
enum SignInOutcome: Sendable {
    case session(AuthSession)
    case mfaRequired(MFAChallenge)
}

// MARK: - Biometrics

/// Face ID / Touch ID readiness.
///
/// The service reports availability and stores the user's preference
/// now; the actual `LAContext` evaluation is a single call to add in
/// `BiometricService` when the capability is switched on.
enum BiometricKind: String, Codable, Sendable {
    case none
    case touchID = "touch_id"
    case faceID = "face_id"
    case opticID = "optic_id"

    var title: String {
        switch self {
        case .none: "Biometrics"
        case .touchID: "Touch ID"
        case .faceID: "Face ID"
        case .opticID: "Optic ID"
        }
    }

    var icon: String {
        switch self {
        case .none: "lock.fill"
        case .touchID: "touchid"
        case .faceID: "faceid"
        case .opticID: "opticid"
        }
    }

    var isAvailable: Bool { self != .none }
}

// MARK: - Auth State

/// The single state machine the root navigation observes.
///
/// Every launch path is one of these, which is why the root no longer
/// needs a hand-rolled phase enum: the session *is* the phase.
enum AuthState: Equatable {
    /// Checking persisted credentials. The splash screen's real job.
    case checking
    /// No session and onboarding not yet seen.
    case onboarding
    /// No session, onboarding done.
    case unauthenticated
    /// Credentials accepted, awaiting a second factor.
    case awaitingMFA(MFAChallenge)
    /// Signed in, but staff with no organization yet.
    case needsOrganization(AuthSession)
    /// Signed up on this device and not yet through "getting started":
    /// first property, notifications, plan. Staff only.
    case gettingStarted(AuthSession)
    /// Fully authenticated.
    case authenticated(AuthSession)

    var session: AuthSession? {
        switch self {
        case .needsOrganization(let session), .gettingStarted(let session), .authenticated(let session): session
        default: nil
        }
    }

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }
}
