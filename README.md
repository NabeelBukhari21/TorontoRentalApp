# Purrperty

**Property management, reimagined.**

Purrperty is a native iOS app for landlords and property managers in Toronto and across Canada. It brings properties, tenants, maintenance, documents and messaging into one place, with AI assistance that always asks for human approval before it acts.

Built with **SwiftUI**, **Swift Concurrency** and **Supabase** (Postgres, Auth, Realtime, Storage, Edge Functions).

---

## Features

**Portfolio**
- Properties and units: create, edit, archive with undo, restore, and delete
- Property detail with Overview, Units, Tenants, Maintenance, Documents and Analytics tabs
- Tenants and leases: create, move, renew, and upload lease files
- Bulk actions, filtering, sorting and validation, with optimistic UI throughout

**Operations**
- Maintenance inbox in list and kanban views, with priorities, statuses, vendor assignment, photos, comments and a timeline
- Real-time messaging
- Document centre with upload, preview and categories

**Intelligence**
- Ten AI capabilities, including maintenance triage, lease summaries, risk detection, suggested replies and a portfolio copilot
- Provider-agnostic: Anthropic, OpenAI, Gemini or on-device, with automatic failover
- No provider API key ships in the app; all calls go through a server-side Edge Function
- Every AI action is logged, and every AI output needs a person to approve it

**Platform**
- Global search across 8 entity types, with highlighting and recent searches
- Notification centre with categories, priority, grouping, mutes and actionable push
- Live sync across seven surfaces
- Offline support with a persistent cache, a queued-write outbox, background drain and conflict resolution
- Four roles: Owner, Property Manager, Tenant and Vendor
- Organization setup, team invites, MFA and biometric unlock (in progress)

---

## Architecture

```
SwiftUI Views
    │
ViewModels  (@Observable, MVVM)
    │
Repository protocols  ← the seam: no view knows which backend it is using
    │
    ├── Supabase implementations   (production)
    └── In-memory implementations  (mock data, previews, tests)
```

- **Dependency injection** through a single composition root (`AppContainer`) with three graphs: Supabase, in-memory and preview
- **Swift Concurrency:** actors for analytics and sync, `@MainActor` for UI state
- **Design system (`DS`):** tokens for colour, type, spacing, motion and materials, plus about 20 reusable components
- **Security:** row-level security on every table, session tokens in the Keychain, analytics that cannot hold personal data by construction, and consent that is off by default
- **Optimistic concurrency:** versioned rows, with conflicts shown to the user rather than silently overwritten

### Project layout

```
RentalApp/RentalApp/
├── App/              Entry point, app delegate
├── Core/             DI, auth, AI, realtime, offline, search, notifications,
│                     analytics, diagnostics, feature flags, privacy, commerce
├── DesignSystem/     Tokens: colours, typography, spacing, motion…
├── Components/       Reusable UI: buttons, cards, sheets, tab bar…
├── Features/         One folder per screen area
├── Domain/           Rich domain model
├── Repositories/     In-memory implementations
├── Supabase/         Supabase implementations
└── FakeBackend/      Seeded Toronto data generator
supabase/
├── migrations/       Schema, RLS, RPCs, search, realtime, notifications
└── functions/        Edge Functions: AI proxy, push sender
```

---

## Getting started

**Requirements:** Xcode 26+, iOS 26+

1. Clone the repo and open `RentalApp/RentalApp.xcodeproj`.
2. Build and run.

That's all you need. **With no backend configured, the app runs on a built-in mock backend** seeded with realistic Toronto portfolio data.

### Connecting a real backend (optional)

1. Create a Supabase project and apply the migrations in `supabase/migrations/`.
2. Copy `RentalApp/Supabase.example.xcconfig` to `RentalApp/RentalApp/Supabase.xcconfig` and fill in your URL and **anon** key.
3. Set it as the target's configuration file in Xcode.

See [`supabase/README.md`](supabase/README.md) for details.

---

## Status

This is an active project. Built so far:

- ✅ All screens, navigation, the design system and the full CRUD flow
- ✅ Supabase schema, RLS, realtime, search and notifications on the server side
- 🚧 AI capabilities are implemented but not yet wired to screens
- 🚧 Subscriptions are scaffolded (StoreKit 2) but switched off
- 🚧 Localization groundwork only; strings are not yet extracted

---

## License

All rights reserved. This repository is shared publicly for portfolio purposes.
