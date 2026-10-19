# Missing features — build plan

The six features the app is missing, in build order. Each step builds on the one
before it, ships on its own and is committed separately.

The same architecture applies throughout: a `Draft` struct and repository
methods in `Core/Protocols`, the in-memory implementation over `FakeBackend`, an
`@Observable @MainActor` view model and native SwiftUI screens (Form/List,
system toolbars). Server tables for leases, payments and maintenance already
exist in `supabase/migrations`, so Supabase repositories can be added later
without changing any caller.

Local writes publish on `SyncEngine.publishLocalChange(_:)`. The server's echo
of a device's own write is suppressed, so this is what lets other screens on
the same device (inbox, Home) refresh after a sheet saves.

## 1. New maintenance request form
- `MaintenanceRequestDraft`: property, unit, title, details, category,
  priority, photos, permission to enter and preferred time.
- `MaintenanceRepositoryProtocol.create(_:)` returns the new ticket.
- `MaintenanceTicket.ai` becomes optional. A new request has no AI analysis
  until the AI layer runs, and the UI doesn't pretend otherwise.
- Form: property and unit pickers (the tenant is filled in from the unit),
  category, priority, up to 6 photos (PhotosPicker) and access. The footer
  notes the Ontario RTA 24-hour entry notice.

## 2. Lease renewal and move
- `LeaseRenewalDraft`: new end date, new rent and term kind (fixed or
  month-to-month).
  - Shows the Ontario rent-increase guideline (2.5% for 2025 and 2026) and
    warns when the increase exceeds it.
  - The guideline applies to units first occupied before 15 Nov 2018; newer
    units are exempt, so this is a warning, never a block.
- `UnitTransferDraft`: target unit, move date and rent.
- Both go in `TenantRepositoryProtocol`, and both are reachable from tenant
  detail.
- Renewal creates a new lease row and links the old one through
  `renewedIntoLeaseID`, as the domain already models it.

## 3. Rent collection and payments
- `PaymentRepositoryProtocol`:
  - rent roll for the month (due, paid, partial, overdue)
  - ledger per tenant
  - record a payment (e-Transfer, cheque, cash, PAD or card, with a
    reference)
  - send a reminder
  - summary (expected, collected, outstanding)
- A "Rent" screen opens from Home's Collect action, and from the toolbar
  menu.
- Recording a payment is manual reconciliation. Real money movement needs a
  payment processor and a server, which is out of scope. The UI never claims
  money was moved.

## 4. Tenant portal
- A tenant session gets its own shell, `TenantRootView`, with these tabs:
  - **Home**: rent due, lease summary and open requests
  - **Requests**: reuses the step 1 form, locked to their unit
  - **Payments**: their ledger from step 3, plus how to pay
  - **Messages**: their conversation with the manager
- `SessionViewModel` routes by role. The staff UI is never shown to tenants.

## 5. Vendor experience
- A vendor session gets `VendorRootView` with two tabs:
  - **Jobs**: assigned work orders. A vendor can accept a job, schedule it,
    mark it done and add notes or photos.
  - **Messages**
- It reuses the maintenance repository with vendor-scoped queries.

## 6. System surfaces (redesign Phase 4)
These need targets and capabilities added in Xcode. The click-by-click steps
are given when we get there, because `project.pbxproj` is never edited by hand.
- Push: APNs capability, a registration hook into
  `NotificationRepository.registerDevice`, and notification actions.
- Widgets: rent collected, open requests and urgent count.
- Live Activity: a maintenance visit in progress.
- Siri and Shortcuts: App Intents for "New maintenance request",
  "Rent status" and "Record payment".
