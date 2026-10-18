# Purrperty UI rebuild — Phase 0 audit and plan

Goal: rebuild the presentation layer on Apple's design language (HIG,
Liquid Glass, iOS 27) so Purrperty looks and behaves like a first-party
app. Features, navigation destinations, models, view models,
repositories, analytics and security stay as they are.

Sources checked (via sosumi, Apple docs as of 2026-10-18): Adopting
Liquid Glass, Preparing your app for iPhone Duo, `TabBarMinimizeBehavior`,
`ToolbarSpacer`, `ArrangementView`, `SubscriptionStoreView`,
`ControlWidget` / `ControlWidgetButton`, Icon Composer.

---

## 1. Environment facts that shape the plan

| Fact | Consequence |
|---|---|
| Installed: **Xcode 27.0, iOS 27.0 SDK**. Deployment target **iOS 26.4**. | iOS 27 APIs compile behind `if #available(iOS 27, *)` with 26.4 fallbacks. |
| `ArrangementView` (the iPhone Duo fold-aware split/overlay container) is **iOS 27.1+**. Apple's iPhone Duo resources ship with **Xcode 27.1 beta**. | It **can't compile with Xcode 27.0**, and there is no iPhone Duo simulator without 27.1. See decision D1. |
| `ToolbarSpacer`, `tabBarMinimizeBehavior`, `Tab(role: .search)`, `.glassEffect`, `GlassEffectContainer`, `.glass` / `.glassProminent` button styles are iOS 26.0+. | Usable directly, no gating. |
| `SubscriptionStoreView` is iOS 17+ and loads products from the App Store or a **StoreKit configuration file**. The app has no `.storekit` file and no App Store Connect products. | Phase 3 (Paywall) needs a `.storekit` file added in Xcode (manual step). |
| "iPhone 17 Pro" simulator on **iOS 26.2** can't run the app (below 26.4). An iPhone 17 Pro on **iOS 26.4** exists. | Use *iPhone 17 Pro (26.4)* as the default, plus one iOS 27 device to exercise the `#available(iOS 27)` paths. |
| The app has been installed with a **free Apple ID** (CLAUDE.md, Info.plist notes). | App Groups, Push Notifications, Time Sensitive and Communication Notifications need a **paid** developer team on device. The simulator works either way. See decision D4. |

## 2. Size of the job

- ~53,000 lines of Swift; ~3,500 references to the custom `DS` system.
- 383 fixed `.system(size:)` fonts, 16 hex colours outside the design
  system, 32 custom icon tokens in `DS.Icons`.
- 14 screen areas, ~120 custom view types (listed below).

At one commit per screen with build + 3-mode screenshot checks, this is
a multi-session project.

## 3. Component audit: custom → system

### Foundations (`DesignSystem/`)

| Custom | Replacement |
|---|---|
| `DSColors` (palette, fills/inks, 60+ tokens) | `AppStyle` colour roles mapped to semantic system colours (`.primary`, `.secondary`, `Color(.systemBackground)`, `.secondarySystemBackground`, `.systemGroupedBackground`, `.separator`, `.red/.green/.orange/.blue`…). One `.tint` (violet) set on the root. Status meaning by role (`.success → .green`), not hex. |
| `DSAccent` / `AccentStore` | Removed if D2 is approved: `.tint(Color("AccentColor"))` from the asset catalog, which gives Increase Contrast and dark variants for free. |
| `DSGradients`, `DSAmbientBackground`, `DSMaterials` (surface/hero/panel), `DSShadows` | Deleted. Content sits on system backgrounds; glass only via system bars/controls and `.glassEffect` on custom floating controls. |
| `DSTypography`, 383 `.system(size:)` | Dynamic Type text styles only (`.largeTitle` … `.caption2`, `.bold()`/emphasized). |
| `DSIcons` (32 tokens) | SF Symbols named inline at the call site, with `.symbolRenderingMode`, `.symbolEffect` (bounce/pulse/replace/draw on), variable values. |
| `DSSpacing` / radii | System margins, `List`/`Form` insets, `.padding()` defaults; `ContainerRelativeShape`/`.rect(cornerRadius:)` with system radii only where a card is unavoidable. |
| `DSMotion` (`DSPressStyle`, `dsEntrance`, `dsFloating`) | System button styles' own press feedback; `.spring`/`.smooth`; `matchedTransitionSource` + `.navigationTransition(.zoom)`; no staggered entrances. |
| `DesignSystemShowcase` | Replaced by a small `AppStyle` preview file. |

### Core components (`Components/Core`)

| Custom | Replacement |
|---|---|
| `DSButton`, `DSIconButton` | `Button` + `.buttonStyle(.glassProminent / .glass / .borderedProminent / .bordered)`, `.controlSize`, `Label` for icon + title. |
| `DSCard`, `DSStatCard` | `Section` in an inset-grouped `List`; for Home tiles a thin `AppStyle.Card` (secondary grouped background, system corner radius, no shadow). |
| `DSBadge`, `DSChip`, `DSStatusDot`, `DSStatusLabel` | `Label` with tinted SF Symbol; `.badge()` on rows/tabs; Text with `.foregroundStyle(.secondary)`. |
| `DSAvatar`, `DSAvatarStack` | Kept as a tiny `AppStyle.Avatar` (initials on `.fill.tertiary` circle) — no system equivalent. |
| `DSTextField`, `DSFormField`, `DSStepperField`, `AuthTextField` | `TextField`/`SecureField` in `Form` sections with `.textContentType`, `LabeledContent`, `Stepper`. Validation via section footers. |
| `DSDropdown` | `Picker` (`.menu` style) / `Menu`. |
| `DSSearchBar` | `.searchable` on the navigation stack + Search tab. |
| `DSEmptyState`, `DSStateView`, `DSErrorView` | `ContentUnavailableView` (Purr image as the label's image where it adds personality), `.search` variant for no results. |
| `DSSkeleton`, `DSListSkeleton`, `DSCardSkeleton`, shimmer | `.redacted(reason: .placeholder)` on real row layouts; `ProgressView` for first load. |
| `DSProgressBar`, `DSProgressRing`, `DSAnimatedCounter` | `ProgressView(value:)`, `Gauge` (`.accessoryCircular` style where ring-like), `.contentTransition(.numericText())`. |
| `DSToast`, `DSToastHost` | Keep the single `ToastCenter` (it's logic), restyle the host as a small glass capsule (`.glassEffect`) at the bottom; errors that need action become `.alert`. |
| `DSConnectionBanner`, `DSStaleDataBar`, `DSPendingBadge`, `ConflictResolutionView` | Toolbar status item / `.safeAreaInset` glass capsule for offline; conflicts as a native sheet with a `Form` and `.confirmationDialog`. |
| `DSAccentPicker` | Removed with D2 (or a `Picker` if kept). |

### Navigation (`Components/Navigation`, `Navigation/`)

| Custom | Replacement |
|---|---|
| `DSTabBar` (floating custom bar) + `CompactTabLayout` | `TabView` with `Tab` API: Home, Properties, Maintenance, Messages, AI, and `Tab(role: .search)`. `.tabBarMinimizeBehavior(.onScrollDown)`. `.tabViewStyle(.sidebarAdaptable)` gives the iPad sidebar for free. |
| `DSSidebar`, `SidebarSplitLayout` | Removed — `sidebarAdaptable` tab view. |
| `DSNavigationHeader` / `dsHeader` (custom large header, fades) | `NavigationStack` `.navigationTitle` + `.navigationBarTitleDisplayMode(.large)`, `.navigationSubtitle` where useful, scroll edge effects. |
| `DSFloatingActionButton` | Toolbar `+` `Menu` (`ToolbarItem(placement: .primaryAction)`) with icon + title. |
| `DSSheet`, `DSModalCard`, `DSSheetContainer`, `DSFullScreenContainer` | `.sheet` with `.presentationDetents`, `NavigationStack` inside, `cancellationAction` / `confirmationAction` toolbar items; `.fullScreenCover` only for onboarding/auth. |
| Search entry (`SearchEntryButton`, `GlobalSearchView` chrome) | Search tab root with `.searchable`, `.searchSuggestions`, scopes for the 8 entity types. |

### Brand and mascot

| Custom | Plan |
|---|---|
| `PurrpertyLogoMark/Tile/Wordmark` + sub-shapes | Keep `PurrpertyLogoTile` for onboarding hello and About only. Wordmark becomes plain `Text("Purrperty")` in `.largeTitle.bold()`. |
| `MascotView`, `MascotFaceView`, `MascotClipView` | Kept as **content** (onboarding, empty states, celebrations, Home brief). |
| `MascotSpeechBubble` / `MascotGuide` | Kept for onboarding and the Home brief; restyled on `secondarySystemBackground` with system text styles. |
| Splash (`SplashView`, `SplashBackground`, `SplashParticleField`, `SplashCascadeText`, `SplashLogoView`) | See D3: system launch screen + no animated splash. |

### Feature components (restyled per screen in Phase 3)

| Screen | Custom views → system |
|---|---|
| Onboarding | `OnboardingProgressBar` → `ProgressView`; `OnboardingChoiceCard` → `List` rows with icon `Label` + checkmark/selection; question header → large title + Purr above; bottom CTA → `.glassProminent` button in `safeAreaBar`/bottom toolbar; `OnboardingBuildChecklist` → `List` rows with symbol `.replace` effect (circle → checkmark.circle.fill); password checklist → `Label` rows with `.symbolEffect(.bounce)`; `OrgConfettiBurst` kept for the aha moment only. |
| Auth | `AuthCard`, `AuthHeader`, `AuthDivider`, `AuthBackButton`, `AuthFormError`, `AuthSelectedRoleChip`, `RoleOptionCard`, `DigitBox` → `Form` sections, system back button, footers for errors, `Picker` for role, `TextField` with `.oneTimeCode` for MFA; `SignInWithAppleButton` (AuthenticationServices) for Apple. |
| Org setup | `OrgSetupProgressBar`, `OrgSetupStepHeader`, `OrgOptionCard`, `OrgInviteChip` → `Form` + `ProgressView`, `Picker(.inline)`, `PhotosPicker`, invite rows with swipe-to-delete. |
| Home | `DashboardHeroCard`, `DashboardOccupancyCard`, `DashboardMaintenanceCard`, `DashboardQuickActionsRow`, feeds → Swift Charts (system styled) + compact tiles in a `LazyVGrid` / `ViewThatFits`, `List` sections for activity/tasks; quick actions → toolbar `+` menu. Purr brief stays as content at the top. |
| Properties | `PropertyCard`, `PropertyHeroImage`, `PropertyOccupancyBadge`, `PropertyMapPreview`, `BulkActionBar`, `SelectionTick`, detail tabs → `List` rows with thumbnails, `Map` (MapKit) snapshot, `EditButton` + `List(selection:)` with bottom toolbar for bulk actions, segmented `Picker` for detail sections, swipe actions (archive/delete), zoom transition list → detail. |
| Tenants | `TenantRow`, `TenantLeaseCard`, `TenantTimelineRow` → `List` rows, `LabeledContent`, `Gauge` for lease progress. |
| Maintenance | `TicketCard`, `KanbanTicketCard`, `TicketPriorityBadge`, `TicketPhotoThumb`, `TicketWorkflowView` → `List` with sections by status (kanban kept as horizontal `ScrollView` of `List`-styled columns on regular width only), priority as tinted symbol, swipe actions (advance status), photo grid, workflow as a `Picker`/`Menu`. |
| Messages | `ConversationRow`, `ChatBubble`, `MessageReceipt`, `TypingIndicatorBubble`, `ChatDateSeparator` → `List` rows; bubbles kept (no system equivalent) on `.tint`/`.secondarySystemBackground` with system text; composer as glass `safeAreaBar` with `TextField(axis: .vertical)`. |
| AI Assistant | `AIOrb`, `AIHeroPanel`, `AIActionCard`, `AIInsightPanel`, `AIHealthCard`, `AIActivityRow`, `AILoadingState` → `List` sections; Apple Intelligence-style guidance (HIG Generative AI): label AI output, show sources, "Review" before apply; loading via `ProgressView` + symbol `.pulse`. |
| Documents | `DocFileGridCard`, `DocFileListRow`, `DocFolderCard`, `DocTagChip`, `DocDropZone`, `DocPreviewSheet` → `List`/grid toggle via toolbar `Picker`, `QuickLook` preview, `fileImporter`/`PhotosPicker`, `.dropDestination`. |
| Notifications | `NotificationRow` → `List` rows with swipe actions, sections by day, filter `Menu`. |
| Settings | `SettingsSectionCard`, `SettingsNavRow`, `SettingsToggleRow`, `SettingsValueRow`, `SettingsIconTile`, `DSToggleStyle`, `SettingsSaveButton` → standard `Form` with `NavigationLink`, `Toggle`, `Picker`, `LabeledContent`, Settings-app style icon tiles (SF Symbol on filled rounded square, the one sanctioned "card"). |
| Paywall | 3-step flow kept: steps 1–2 as native onboarding-style pages; step 3 = `SubscriptionStoreView` (`.subscriptionStoreControlStyle(.picker)`, `storeButton(.visible, for: .restorePurchases)`, policy destinations). |

## 4. New targets, capabilities and manual Xcode steps

I'll stop and give click-by-click steps for each, and continue only after
you confirm. Nothing below is done by editing `project.pbxproj`.

| # | What | Needed for | Where |
|---|---|---|---|
| T1 | **Widget Extension** target `PurrpertyWidgets` ("Include Live Activity" and "Include Control" ticked) | Widgets (B), Live Activities (C), Control Center control (E) | Phase 4 |
| T2 | **`Shared/` folder** added as a synchronised group to **both** the app and widget targets | Codable snapshot models, App Group store, App Intents used by widgets | Phase 4 start |
| C1 | **App Groups** on app + widget: `group.Seneca.Syed.RentalApp` (new ID; stable IDs untouched) | Snapshot store shared with extensions | Phase 4 |
| C2 | **Push Notifications** | Remote notifications, Live Activity push updates | Phase 4 D |
| C3 | **Time Sensitive Notifications** | Urgent repairs only | Phase 4 D |
| C4 | **Communication Notifications** | Tenant messages with sender avatars (`INSendMessageIntent`) | Phase 4 D |
| I1 | Info.plist `NSSupportsLiveActivities = YES` (I can add this through the Xcode MCP `AddInfoPlist` tool, not pbxproj) | Live Activities | Phase 4 C |
| A1 | **AccentColor** in the asset catalog set to #6C5CE7 (+ dark / high-contrast variants) | Single system tint | Phase 1 |
| A2 | **`.icon` file** made in Icon Composer and dragged into the project; I provide layer SVGs + steps | App icon (A) | Phase 4 A |
| S1 | **StoreKit configuration file** (`Purrperty.storekit`) + scheme → Run → Options → StoreKit Configuration | `SubscriptionStoreView` locally | Phase 3 Paywall |

No separate App Intents extension is needed: App Shortcuts, Siri,
Spotlight and the interactive widget intents run from the app and widget
targets with intents compiled into both via `Shared/`. A Notification
Service Extension is only needed for **remote** communication
notifications; with the mock backend everything is local, so I'll
propose it only if/when Supabase push is configured.

Apple Pay: the app has no rent-payment UI yet (tenant portal not
built), so there's nothing to convert. When payments arrive they'll use
`PayWithApplePayButton` / PassKit, never IAP.

## 5. Phases (each waits for your approval)

0. **This audit.**
1. **Foundations** — `AppStyle` (colour roles, tint, a handful of row/
   card/button styles), AccentColor asset, typography helpers. Old `DS`
   stays compiling in parallel until screens move over.
2. **Navigation shell** — `TabView`/`Tab`, search tab, minimise on
   scroll, `NavigationStack` large titles, toolbar `+` menu, native
   sheets; delete `DSTabBar`, `DSSidebar`, `DSFloatingActionButton`,
   `DSNavigationHeader`, sheet containers.
3. **Screens**, one commit each: Splash → Onboarding → Auth → Org setup
   → Home → Properties → Tenants → Maintenance → Messages → AI Assistant
   → Documents → Notifications → Settings → Paywall.
4. **System surfaces**, one commit each: A icon → B widgets → C Live
   Activities → D notifications → E App Intents + control → F IAP.
5. **Accessibility pass**, delete the old design system, update
   CLAUDE.md. (iPhone Duo is out of scope — D1.)

Per-step checks: XcodeBuildMCP build, zero new warnings, run on iPhone 17
Pro (26.4) + one iOS 27 device, screenshots in light, dark and AX5
Dynamic Type, compared against the HIG page for that component.

## 6. Decisions (answered 2026-10-18)

- **D1 — iPhone Duo: out of scope.** No `ArrangementView`, no Duo
  simulator, no Duo pass. Layouts still adapt to iPhone and iPad through
  size classes and system containers, which is the HIG baseline anyway.
- **D2 — Accent picker: removed.** `AccentStore`, `DSAccentPicker`, the
  accent row in "Make it yours" and in Settings → Appearance are deleted.
  Violet comes from the `AccentColor` asset as the single system tint.
  "Make it yours" keeps Light / Dark / System.
- **D3 — Splash: replaced** by a system launch screen (plain system
  background) that hands straight to onboarding or Home. The session
  check runs without a branded animation.
- **D4 — Developer account: unknown.** At Phase 4 I'll show how to check
  (Xcode → target → Signing & Capabilities → Team: "Personal Team" means
  free). Extensions are built and tested in the simulator either way, and
  the app must keep running on device without the paid-only capabilities.
- **D5 — Simulator:** iPhone 17 Pro (iOS 26.4) as default, plus an
  iOS 27 device for gated paths.
