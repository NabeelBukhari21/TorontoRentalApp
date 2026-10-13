# Purrperty — project guide for Claude

Purrperty (formerly RentOS) is a native iOS property-management app for
Toronto landlords and property managers. Purr is the cat mascot, who lives
inside the name the way Duo lives inside Duolingo. The style is bright and
colourful, for students, on a white background.

## Role and standards
- Act as lead staff iOS engineer and principal product designer.
- Use clean architecture, MVVM, SOLID principles, reusable components and
  Apple's Human Interface Guidelines. No quick hacks or temporary fixes.
- For any new feature, think through the architecture first and explain
  the plan, then build production-quality code.
- Don't over-engineer, but keep the planned scope in mind: AI,
  properties, tenant portal, maintenance, messaging, payments,
  notifications, analytics and auth.

## Project facts
- Xcode project: `RentalApp/RentalApp.xcodeproj`. Sources:
  `RentalApp/RentalApp/`.
- The folder is a file-system-synchronised group, so new files join the
  target automatically. **Never edit `project.pbxproj` by hand** unless a
  build setting truly requires it.
- Schemes:
  - `RentalApp` launches normally (a restored session goes straight to
    Home).
  - `RentalApp (Onboarding)` passes `-PurrpertyStartAt onboarding`, so
    the app opens at onboarding. Also supported: `login`. This works in
    DEBUG builds only; see `Core/Diagnostics/DebugLaunchOverride.swift`.
- Deployment target: iOS 26.4. Default simulator: iPhone 17 Pro. Physical
  device: iPhone 15 Pro Max.
- Swift settings: `SWIFT_VERSION = 5.0`, Approachable Concurrency,
  `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated`, and
  `MemberImportVisibility`. Every file must import the modules it uses:
  `OSLog` wherever `AppLog` is used, `Combine` for `.onReceive`
  publishers, `AVFoundation`, `UIKit` and so on.
- There is no test target yet.
- Bundle ID: `Seneca.Syed.RentalApp`.

## Architecture
- MVVM with `@Observable` `@MainActor` view models. Views never call
  repositories directly.
- DI goes through `AppContainer` (`Core/DI`), which has three graphs:
  `supabase`, `inMemory` and `preview`.
  - `live()` falls back to `inMemory` when Supabase isn't configured, so
    the app runs on mock data (`FakeBackend/`) until it is.
  - Previews use `.preview` automatically.
- `SessionViewModel` is the single owner of "where am I?"
  (`AuthState`: checking → onboarding → unauthenticated → MFA → org setup
  → authenticated).
- Folder layout:
  - `Features/<Feature>/`, each with a `Components/` subfolder
  - `Components/` for shared UI: Mascot, Brand, Media, Core
  - `DesignSystem/` for tokens
  - `Core/` for infrastructure
  - `Domain/`, `Models/`, `Repositories/`, `Services/`, `Supabase/`
- Release infrastructure:
  - consent-gated `AnalyticsService` (typed `AnalyticsEvent`)
  - `CrashReporter` (async-signal-safe)
  - `FeatureFlagStore`
  - `LegalGate`
  - `EntitlementStore` (StoreKit scaffold)
  - `KeychainSessionStore`
  - `AppLog` (OSLog categories)

## Design system: always use tokens, never hardcoded colours
- Palette:
  - bg #FFFFFF, surface #F6F7FB, ink #1B1B2F, secondary #6B7085
  - primary violet #6C5CE7
  - coral #FF6B6B, sunny #FFD93D, mint #2ED8A3, sky #4DA8FF
- Use `DS.Colors`, `DS.Gradients`, `DS.Spacing` (radii 10/14/20/26/32),
  `DS.Shadows`, `DS.Motion` and `DS.Icons`.
- Accents have `.fill` and `.ink` pairs. Use the **ink** variant for text
  on light backgrounds; all text must pass WCAG AA.
- `textOnBrand` is adaptive.
- The theme is light by default and dark mode is supported. Respect
  Reduce Motion everywhere.
- Brand: `PurrpertyLogoMark`, `PurrpertyLogoTile` and `PurrpertyWordmark`
  in `Components/Brand/PurrpertyLogo.swift`. Their fixed palette is
  `PurrpertyBrand`.

## Mascot (Purr)
- `MascotView(mood:size:)` is the live, animated cat.
  - Moods: idle, happy, cheer, thinking, concerned, cool, working,
    sleeping, excited.
  - Smaller poses fall back to the hi-res sit/cheer poses when they
    would be upscaled.
- `MascotGuide` is the cat plus a speech bubble. `showsMascot: false`
  makes the bubble point up instead.
- `MascotFaceView(face:)` shows 12 expression tiles, up to about 44pt.
- `MascotClipView(clip:)` plays a video clip on a white card.
  - `.hello` → `Resources/Media/PurrHello.mp4`.
  - Prepare new clips with `tools/mascot/video_whiten.py`.
- Assets live in `Resources/Assets.xcassets/Mascot/`. The cut-out
  pipeline is in `tools/mascot/`.

## Rules
- After every change: build, fix all errors **and warnings**, and run on
  the simulator to check UI work. Use screenshots for UI.
- Commit after each coherent piece of work, with a descriptive message
  (this is a portfolio repo). Author: `NabeelBukhari21
  <nabeelbukhari21@gmail.com>`. The user pushes via GitHub Desktop.
- Security:
  - Never commit `Supabase.xcconfig`; it is gitignored.
  - Use the anon key only, never `service_role`.
  - No AI provider keys in the app binary. AI calls go through the
    `supabase/functions/ai-complete` edge function.
  - Never trust the client; RLS enforces access.
- Don't rename the stable identifiers: the bundle ID, the `rentos://`
  deep-link scheme, the `ca.rentos.*` background-task IDs and the
  keychain service. Changing them breaks sessions and links.
- Mascot copy may only promise features that actually exist.
- Onboarding, permissions and paywall work must follow
  `docs/ONBOARDING_PLAYBOOK.md`.

## Current status and next steps
- Done:
  - bright retheme
  - mascot system and new poses
  - logo redesign and app icon
  - Purrperty rebrand
  - onboarding hello clip
  - debug launch override
- Next, the user's plan, step by step:
  1. Fix the loading screen.
  2. Fix onboarding.
  3. Fix the Home UI.
  4. Build new features.
- Open items:
  - The hello clip still carries the DomoAI watermark. Replace it with a
    clean export.
  - Request 1024px exports of the cool, work, sleep and leap poses.
  - The "Reduce glass effects" setting is now a no-op.
  - AI tasks aren't wired to any screens.
  - Supabase isn't configured.
  - The GitHub About description needs updating.
