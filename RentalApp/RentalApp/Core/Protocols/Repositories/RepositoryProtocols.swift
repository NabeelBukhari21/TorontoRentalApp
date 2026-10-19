//
//  RepositoryProtocols.swift
//  RentalApp (Purrperty)
//
//  Core — Repository interfaces.
//
//  ─────────────────────────────────────────────────────────────────
//  CONTRACT
//  ─────────────────────────────────────────────────────────────────
//  • Reads are `async throws` and return `Page<T>` where the result
//    can grow. Signatures are shaped so a PostgREST or REST client
//    can implement them without changing a single caller.
//  • Search, filter, and sort are passed *in* as a `QuerySpec`, never
//    applied afterwards by a view model. That is what keeps the work
//    server-side once there is a server.
//  • Failures surface as `AppError`, never as transport types.
//  • Device-local preferences stay synchronous on purpose — see the
//    note above the settings protocols.
//

import Foundation

// MARK: - Query Vocabulary
//
// Each domain's filter and sort options live here rather than in a
// feature, because they are part of the repository's contract.

enum PropertyFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case fullyOccupied = "Full"
    case hasVacancy = "Vacancies"
    case hasIssues = "Issues"

    var id: String { rawValue }

    var icon: String? {
        switch self {
        case .all: nil
        case .fullyOccupied: "checkmark.circle.fill"
        case .hasVacancy: "door.left.hand.open"
        case .hasIssues: DS.Icons.warning
        }
    }
}

enum PropertySortField: String, CaseIterable, Identifiable, Sendable {
    case name
    case occupancy
    case revenue
    case units

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: "Name"
        case .occupancy: "Occupancy"
        case .revenue: "Revenue"
        case .units: "Units"
        }
    }
}

enum TenantFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case active = "Active"
    case notice = "Notice"
    case overdue = "Overdue"
    case premium = "Premium"

    var id: String { rawValue }

    var icon: String? {
        switch self {
        case .all: nil
        case .active: "checkmark.circle.fill"
        case .notice: "clock.fill"
        case .overdue: DS.Icons.warning
        case .premium: "crown.fill"
        }
    }
}

enum TenantSortField: String, CaseIterable, Identifiable, Sendable {
    case name
    case rent
    case leaseProgress = "lease_progress"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: "Name"
        case .rent: "Rent"
        case .leaseProgress: "Lease progress"
        }
    }
}

/// Nil priority means "any priority".
struct MaintenanceFilter: Equatable, Sendable {
    var priority: TicketPriority?
    var status: TicketStatus?

    init(priority: TicketPriority? = nil, status: TicketStatus? = nil) {
        self.priority = priority
        self.status = status
    }

    static let all = MaintenanceFilter()
}

enum MaintenanceSortField: String, CaseIterable, Sendable {
    case priority
    case createdAt = "created_at"
    case property
}

struct MessageFilter: Equatable, Sendable {
    var role: ChatRole?
    var unreadOnly: Bool

    init(role: ChatRole? = nil, unreadOnly: Bool = false) {
        self.role = role
        self.unreadOnly = unreadOnly
    }

    static let all = MessageFilter()
}

enum MessageSortField: String, CaseIterable, Sendable {
    case recency
}

struct DocumentFilter: Equatable, Sendable {
    var folderID: String?
    var type: DocFileType?
    var tags: Set<String>

    init(folderID: String? = nil, type: DocFileType? = nil, tags: Set<String> = []) {
        self.folderID = folderID
        self.type = type
        self.tags = tags
    }

    static let all = DocumentFilter()
}

enum DocumentSortField: String, CaseIterable, Sendable {
    case date
    case name
}

// MARK: - Type Aliases

typealias PropertyQuery = QuerySpec<PropertyFilter, PropertySortField>
typealias TenantQuery = QuerySpec<TenantFilter, TenantSortField>
typealias MaintenanceQuery = QuerySpec<MaintenanceFilter, MaintenanceSortField>
typealias MessageQuery = QuerySpec<MessageFilter, MessageSortField>
typealias DocumentQuery = QuerySpec<DocumentFilter, DocumentSortField>

// MARK: - Properties

/// What the create/edit form collects for a property.
///
/// A draft, not a `Property`: the presentation model carries derived
/// aggregates (occupancy, open requests) that the client has no business
/// sending. Only the fields a human actually types travel to the server.
struct PropertyDraft: Sendable, Equatable {
    var name: String
    var kind: PropertyKind
    var addressLine1: String
    var city: String
    var postalCode: String
    var neighborhood: String?
    var yearBuilt: Int?
    var squareFeet: Int?

    init(
        name: String = "",
        kind: PropertyKind = .condo,
        addressLine1: String = "",
        city: String = "Toronto",
        postalCode: String = "",
        neighborhood: String? = nil,
        yearBuilt: Int? = nil,
        squareFeet: Int? = nil
    ) {
        self.name = name
        self.kind = kind
        self.addressLine1 = addressLine1
        self.city = city
        self.postalCode = postalCode
        self.neighborhood = neighborhood
        self.yearBuilt = yearBuilt
        self.squareFeet = squareFeet
    }
}

/// What the create/edit form collects for a unit.
struct UnitDraft: Sendable, Equatable {
    var label: String
    var bedrooms: Int
    var bathrooms: Decimal
    var squareFeet: Int?
    var marketRent: Decimal
    var floor: Int?

    init(
        label: String = "",
        bedrooms: Int = 1,
        bathrooms: Decimal = 1,
        squareFeet: Int? = nil,
        marketRent: Decimal = 0,
        floor: Int? = nil
    ) {
        self.label = label
        self.bedrooms = bedrooms
        self.bathrooms = bathrooms
        self.squareFeet = squareFeet
        self.marketRent = marketRent
        self.floor = floor
    }
}

@MainActor
protocol PropertyRepositoryProtocol: AnyObject {

    // MARK: Reads

    func properties(matching query: PropertyQuery, forceRefresh: Bool) async throws -> Page<Property>
    func property(id: String) async throws -> Property
    func portfolioSummary(forceRefresh: Bool) async throws -> PropertyPortfolioSummary

    func units(forPropertyID id: String) async throws -> [PropertyUnit]
    func tenantRows(forPropertyID id: String) async throws -> [PropertyTenantRow]
    func requestRows(forPropertyID id: String) async throws -> [PropertyRequestRow]
    func documents(forPropertyID id: String) async throws -> [PropertyDocRow]
    func occupancyTrend(forPropertyID id: String) async throws -> [OccupancyTrendPoint]
    func revenueTrend(forPropertyID id: String) async throws -> [RevenuePoint]

    /// Archived rows, for the restore list. Kept separate from the main
    /// query so the default list never has to filter them out.
    func archivedProperties() async throws -> [Property]

    // MARK: Writes
    //
    // Each returns the affected id (or the new row) rather than Void, so
    // an optimistic caller can reconcile its placeholder with the real
    // record instead of forcing a full reload.

    @discardableResult
    func createProperty(_ draft: PropertyDraft) async throws -> Property
    func updateProperty(id: String, with draft: PropertyDraft) async throws -> Property

    /// Reversible. Hides the property but keeps every unit, lease, and
    /// ticket intact — this is what `Undo` restores.
    func archiveProperty(id: String) async throws
    func restoreProperty(id: String) async throws

    /// Irreversible, and refused by the server when dependent rows exist.
    /// A property with an active lease must be archived, not deleted.
    func deleteProperty(id: String) async throws

    @discardableResult
    func createUnit(_ draft: UnitDraft, propertyID: String) async throws -> PropertyUnit
    func updateUnit(id: String, with draft: UnitDraft) async throws -> PropertyUnit
    func deleteUnit(id: String) async throws
}

/// Aggregates shown in the properties header — computed by the source,
/// not by summing a partially-loaded page in the view model.
struct PropertyPortfolioSummary: Sendable, Equatable, Codable {
    let propertyCount: Int
    let totalUnits: Int
    let occupiedUnits: Int
    let monthlyRevenueText: String

    var occupancyRate: Double {
        totalUnits == 0 ? 0 : Double(occupiedUnits) / Double(totalUnits)
    }

    static let empty = PropertyPortfolioSummary(
        propertyCount: 0, totalUnits: 0, occupiedUnits: 0, monthlyRevenueText: "—"
    )
}

// MARK: - Tenants

struct TenantDraft: Sendable {
    var name: String
    var email: String
    var phone: String
    var propertyName: String
    var unit: String
    var rent: Int
    var leaseStart: Date
    var leaseEnd: Date
}

/// Counts for the tenants header.
struct TenantSummary: Sendable, Equatable {
    let total: Int
    let active: Int
    let overdue: Int
    let renewalsSoon: Int

    static let empty = TenantSummary(total: 0, active: 0, overdue: 0, renewalsSoon: 0)
}

/// What the renewal form collects.
struct LeaseRenewalDraft: Sendable, Equatable {
    var kind: LeaseTermKind = .fixedTerm
    var start: Date
    /// Ignored for month-to-month.
    var end: Date
    /// Monthly rent, whole dollars.
    var rent: Int
}

/// What the move form collects. A move ends the current lease the day
/// before `moveDate` and starts a new one on the target unit.
struct UnitTransferDraft: Sendable, Equatable {
    var targetUnitID: String?
    var moveDate: Date
    /// Monthly rent on the new unit, whole dollars.
    var rent: Int
    /// Carry the last month's rent deposit over rather than refunding it.
    var carriesDeposit = true
}

@MainActor
protocol TenantRepositoryProtocol: AnyObject {
    func tenants(matching query: TenantQuery, forceRefresh: Bool) async throws -> Page<Tenant>
    func tenant(id: String) async throws -> Tenant
    func summary(forceRefresh: Bool) async throws -> TenantSummary

    func timeline(forTenantID id: String) async throws -> [TenantEvent]
    func documents(forTenantID id: String) async throws -> [PropertyDocRow]
    func maintenanceHistory(forTenantID id: String) async throws -> [PropertyRequestRow]
    func messages(forTenantID id: String) async throws -> [TenantMessagePreview]

    func create(_ draft: TenantDraft) async throws
    func propertyNames() async throws -> [String]

    // MARK: Leasing

    func lease(forTenantID id: String) async throws -> LeaseSummary
    /// Vacant units across the portfolio, for a move.
    func vacantUnits() async throws -> [VacantUnit]

    /// Starts a new lease that follows the current one. Returns it.
    @discardableResult
    func renewLease(forTenantID id: String, with draft: LeaseRenewalDraft) async throws -> LeaseSummary
    /// Ends the current lease and starts one on another unit. Returns it.
    @discardableResult
    func moveTenant(id: String, with draft: UnitTransferDraft) async throws -> LeaseSummary
}

// MARK: - Payments

/// Rent owed and received. Records payments a landlord has received;
/// moving money needs a payment processor and a server, so nothing here
/// charges anyone.
@MainActor
protocol PaymentRepositoryProtocol: AnyObject {
    /// Every current lease's rent for the month containing `month`.
    func rentRoll(for month: Date, forceRefresh: Bool) async throws -> RentRoll
    func ledger(forTenantID id: String) async throws -> TenantLedger

    /// Records a payment received against one month's rent.
    @discardableResult
    func record(_ draft: PaymentDraft) async throws -> LedgerEntry
    /// Notes that a reminder went out for a month, so the roll can say so.
    func noteReminder(forTenantID id: String, month: Date) async throws
}

// MARK: - Maintenance

/// Counts for the maintenance stats strip.
struct MaintenanceSummary: Sendable, Equatable {
    let open: Int
    let urgent: Int
    let unassigned: Int
    let averageResolutionText: String

    static let empty = MaintenanceSummary(
        open: 0, urgent: 0, unassigned: 0, averageResolutionText: "—"
    )
}

/// What the new-request form collects.
///
/// Names travel with the ids so the in-memory source can build the row
/// without a join; a networked source sends only the ids.
struct MaintenanceRequestDraft: Sendable, Equatable {
    var propertyID: String?
    var propertyName: String = ""
    /// Nil means the common area.
    var unitID: String?
    var unitName: String = ""
    var tenantName: String?
    var title: String = ""
    var details: String = ""
    var category: TicketCategory = .general
    var priority: TicketPriority = .medium
    /// JPEG data, already downscaled for upload.
    var photos: [Data] = []
    var access = TicketAccess(permissionToEnter: false, window: .anytime)

    static let maxPhotos = 6
}

@MainActor
protocol MaintenanceRepositoryProtocol: AnyObject {
    func tickets(matching query: MaintenanceQuery, forceRefresh: Bool) async throws -> Page<MaintenanceTicket>
    func ticket(id: String) async throws -> MaintenanceTicket
    func summary(forceRefresh: Bool) async throws -> MaintenanceSummary

    func vendors() async throws -> [Vendor]
    func vendor(id: String) async throws -> Vendor?
    func timeline(forTicketID id: String) async throws -> [TenantEvent]

    @discardableResult
    func create(_ draft: MaintenanceRequestDraft) async throws -> MaintenanceTicket
    func move(_ ticketID: String, to status: TicketStatus) async throws
    func assign(_ vendorID: String, to ticketID: String) async throws
    func addComment(_ text: String, to ticketID: String) async throws
    func markReplySent(_ ticketID: String) async throws
}

// MARK: - Messaging

@MainActor
protocol MessageRepositoryProtocol: AnyObject {
    func conversations(matching query: MessageQuery, forceRefresh: Bool) async throws -> Page<Conversation>
    func conversation(id: String) async throws -> Conversation
    func messages(forConversationID id: String, forceRefresh: Bool) async throws -> [ChatMessage]
    func totalUnread() async throws -> Int

    /// Emits the id of a conversation whose typing state changed.
    var typingIn: Set<String> { get }

    func markRead(_ conversationID: String) async throws
    func send(_ text: String, attachment: ChatAttachment?, in conversationID: String) async throws
}

// MARK: - Documents

@MainActor
protocol DocumentRepositoryProtocol: AnyObject {
    func files(matching query: DocumentQuery, forceRefresh: Bool) async throws -> Page<DocFile>
    func folders() async throws -> [DocFolder]
    func tags() async throws -> [String]
    func fileCount(inFolderID id: String) async throws -> Int

    var uploads: [DocUpload] { get }

    func toggleFavorite(_ fileID: UUID) async throws
    func upload(named name: String, type: DocFileType, folderID: String) async throws
}

// MARK: - Notifications

/// What a user can silence.
///
/// Two shapes because both are wanted: "stop telling me about *this
/// ticket*" and "stop telling me about payments entirely".
enum MuteTarget: Sendable, Equatable {
    case subject(type: String, id: String)
    case category(NotificationCategory)
}

/// Per-category delivery preferences, mirroring the server rows.
struct NotificationPreference: Sendable, Equatable, Identifiable {
    let category: NotificationCategory
    var inApp: Bool
    var push: Bool
    var email: Bool
    /// Below this, the centre still records it but no push is sent.
    var minPushPriority: NotificationPriority

    var id: String { category.rawValue }
}

/// Account-wide delivery settings.
struct NotificationSettings: Sendable, Equatable {
    var quietHoursEnabled: Bool
    var quietStart: Int      // minutes from midnight, local
    var quietEnd: Int
    var allowCriticalInQuiet: Bool
    var digestEnabled: Bool
    var badgeEnabled: Bool

    static let `default` = NotificationSettings(
        quietHoursEnabled: false,
        quietStart: 22 * 60,
        quietEnd: 7 * 60,
        allowCriticalInQuiet: true,
        digestEnabled: false,
        badgeEnabled: true
    )
}

@MainActor
protocol NotificationRepositoryProtocol: AnyObject {

    // MARK: Reads

    func notifications(forceRefresh: Bool) async throws -> [AppNotification]
    func unreadCount() async throws -> Int

    // MARK: State

    func markRead(_ id: UUID) async throws
    func markAllRead() async throws
    func dismiss(_ id: UUID) async throws

    // MARK: Actions
    //
    // Performed server-side so an action taken from the lock screen behaves
    // identically to one taken in the app — and so a client cannot invent
    // an action the server never offered.
    func perform(action actionID: String, on notificationID: UUID) async throws

    // MARK: Muting

    func mute(_ target: MuteTarget, until: Date?) async throws
    func unmute(_ target: MuteTarget) async throws
    func mutedTargets() async throws -> [MuteTarget]

    // MARK: Preferences

    func preferences() async throws -> [NotificationPreference]
    func updatePreference(_ preference: NotificationPreference) async throws
    func settings() async throws -> NotificationSettings
    func updateSettings(_ settings: NotificationSettings) async throws

    // MARK: Push

    /// Registers this device for push. Idempotent — called on every launch
    /// so a rotated token replaces the old one.
    func registerDevice(token: String, platform: String, appVersion: String?) async throws
}

// MARK: - Dashboard

/// One payload for the whole dashboard. A single call keeps the screen
/// from flashing through eight independent loading states.
struct DashboardSnapshot: Sendable {
    let portfolio: PortfolioSummary
    let revenue: [RevenuePoint]
    let stats: [DashboardStat]
    let insights: [AIInsight]
    let maintenanceCounts: [MaintenanceStatusCount]
    let activity: [ActivityItem]
    let tasks: [UpcomingTask]
}

@MainActor
protocol DashboardRepositoryProtocol: AnyObject {
    func snapshot(forceRefresh: Bool) async throws -> DashboardSnapshot
    func toggleTask(_ id: UUID) async throws
}

// MARK: - AI Copilot

struct CopilotBriefing: Sendable {
    let narrative: String
    let actions: [AIRecommendedAction]
    let maintenanceInsights: [AIInsightRow]
    let leaseInsights: [AIInsightRow]
    let healthScore: Int
    let healthFactors: [AIHealthFactor]
    let quickActions: [AIQuickAction]
    let activity: [AIActivityEntry]
}

@MainActor
protocol CopilotRepositoryProtocol: AnyObject {
    func briefing(forceRefresh: Bool) async throws -> CopilotBriefing
    func run(_ quickAction: AIQuickAction) async throws -> AIActivityEntry
}

// MARK: - Settings
//
// Deliberately split into four focused repositories rather than one
// settings God object.
//
// These stay SYNCHRONOUS. Preferences and profile fields are device
// state bound directly to SwiftUI controls with `@Bindable`; wrapping
// a toggle in `async throws` would buy nothing and break two-way
// binding. When these move server-side, each gains an async `save()`
// while the bound properties remain local form state.

@MainActor
protocol ProfileRepositoryProtocol: AnyObject {
    var fullName: String { get set }
    var email: String { get set }
    var phone: String { get set }
    var jobTitle: String { get set }

    var orgName: String { get set }
    var orgSlug: String { get set }
    var orgCity: String { get set }

    var members: [TeamMember] { get }
    func invite(email: String)
    func save() async throws
}

@MainActor
protocol PreferencesRepositoryProtocol: AnyObject {
    // Notifications
    var notifyUrgentMaintenance: Bool { get set }
    var notifyPayments: Bool { get set }
    var notifyMessages: Bool { get set }
    var notifyLeaseEvents: Bool { get set }
    var notifyAIInsights: Bool { get set }
    var emailWeeklyDigest: Bool { get set }
    var emailMonthlyReport: Bool { get set }
    var quietHoursEnabled: Bool { get set }

    // Appearance
    var theme: AppTheme { get set }
    var reduceGlassEffects: Bool { get set }
    var showPortfolioValueOnHome: Bool { get set }

    // Copilot behaviour
    var aiAutoTriage: Bool { get set }
    var aiDraftReplies: Bool { get set }
    var aiVendorMatching: Bool { get set }
    var aiWeeklyBriefing: Bool { get set }
    var aiPricingAlerts: Bool { get set }
    var aiProactiveness: Double { get set }
}

@MainActor
protocol BillingRepositoryProtocol: AnyObject {
    var planName: String { get }
    var planPrice: String { get }
    var unitQuota: Int { get }
    var unitsUsed: Int { get }
    var invoices: [InvoiceItem] { get }
}

@MainActor
protocol IntegrationsRepositoryProtocol: AnyObject {
    var integrations: [IntegrationItem] { get }
    func toggleIntegration(_ id: String)
}
