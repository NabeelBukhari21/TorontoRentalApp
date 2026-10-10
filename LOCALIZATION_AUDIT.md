# Localization Audit

Generated from source. **189 user-facing string literals** across **52 files**.

- 132 plain literals — seeded into `Resources/Localizable.xcstrings`
- 57 interpolated literals — need `String(localized:)` with arguments, done by hand

## Interpolated strings (manual work)

These embed runtime values. Word order differs by language, so they cannot be
concatenated — each needs a format string with positional arguments.

- `Components/Core/DSAvatar.swift:125` — `+\(names.count - maxVisible)`
- `Components/Core/DSOfflineIndicators.swift:34` — `Saved copy · \(storedAt.formatted(.relative(presentation: .named)))`
- `Components/Core/DSProgress.swift:75` — `\(Int(animatedValue * 100))%`
- `Components/Core/DSProgress.swift:112` — `\(prefix)\(value)\(suffix)`
- `Features/AIAssistant/Components/AIAssistantComponents.swift:303` — `\(revealed ? score : 0)`
- `Features/AIAssistant/Components/AIAssistantComponents.swift:327` — `\(Int(factor.score * 100))`
- `Features/Auth/Components/AuthComponents.swift:301` — `Unlock with \(option.kind.title)`
- `Features/Auth/Components/AuthComponents.swift:335` — `Signing up as \(role.title)`
- `Features/Auth/Components/AuthComponents.swift:371` — `Password: \(MockAccountDirectory.demoPassword) · MFA code: \(MockAccountDirectory.demoMFACode)`
- `Features/Auth/Screens/ForgotPasswordView.swift:92` — `We sent a reset link to\n\(viewModel.email)`
- `Features/Dashboard/Components/DashboardCards.swift:54` — `\(count)`
- `Features/Dashboard/Components/DashboardCards.swift:112` — `\(status.count)`
- `Features/Dashboard/Components/DashboardFeeds.swift:109` — `\(tasks.filter { !$0.isDone }.count) open`
- `Features/Dashboard/Components/DashboardHeroCard.swift:53` — `\(propertyCount) properties · \(unitCount) units`
- `Features/Documents/Components/DocumentComponents.swift:140` — `\(file.size) · \(file.date)`
- `Features/Documents/Components/DocumentComponents.swift:202` — `\(file.type.rawValue) · \(file.size) · \(file.date)`
- `Features/Documents/Components/DocumentComponents.swift:309` — `\(count) files`
- `Features/Documents/Components/DocumentComponents.swift:423` — `\(Int(upload.progress * 100))%`
- `Features/Maintenance/Components/MaintenanceComponents.swift:43` — `\(ticket.unitName) · \(ticket.propertyName) · \(ticket.createdAgo)`
- `Features/Maintenance/Components/MaintenanceComponents.swift:61` — `\(ticket.photoCount)`
- `Features/Maintenance/Components/MaintenanceComponents.swift:71` — `\(Int(ticket.ai.urgencyScore * 100))`
- `Features/Maintenance/Components/MaintenanceComponents.swift:205` — `\(ticket.photoCount)`
- `Features/Maintenance/Components/MaintenanceComponents.swift:272` — `IMG_0\(index + 1)`
- `Features/Maintenance/Components/MaintenanceComponents.swift:240` — `Move to \(status.title)`
- `Features/Maintenance/MaintenanceDetailView.swift:110` — `\(ticket.unitName) · \(ticket.propertyName)`
- `Features/Maintenance/MaintenanceDetailView.swift:165` — `\(Int(ticket.ai.categoryConfidence * 100))% confidence`
- `Features/Maintenance/MaintenanceDetailView.swift:188` — `\(Int(ticket.ai.urgencyScore * 100))`
- `Features/Maintenance/MaintenanceDetailView.swift:283` — `\(ticket.photoCount)`
- `Features/Maintenance/MaintenanceDetailView.swift:409` — `\(ticket.comments.count)`
- `Features/Maintenance/MaintenanceInboxView.swift:239` — `\(tickets.count)`
- `Features/Messages/Components/MessageComponents.swift:76` — `\(conversation.unreadCount)`
- `Features/Notifications/NotificationsView.swift:82` — `\(unread) new`
- `Features/Notifications/NotificationsView.swift:175` — `Mute \(notification.category.label.lowercased())`
- `Features/Onboarding/Components/OnboardingInsightsIllustration.swift:31` — `$\(revenue)K`
- `Features/Onboarding/Components/OnboardingPortfolioIllustration.swift:84` — `\(Int(occupancy * 100))%`
- `Features/OrgSetup/Components/OrgSetupComponents.swift:23` — `Step \(stepIndex + 1) of \(stepCount)`
- `Features/OrgSetup/Components/OrgSetupComponents.swift:30` — `\(Int(progress * 100))%`
- `Features/OrgSetup/Steps/OrgSetupSteps.swift:45` — `rentos.app/\(slug)`
- `Features/Properties/Components/PropertyCard.swift:118` — `\(property.neighborhood) · \(property.address)`
- `Features/Properties/Components/PropertyDetailTabs.swift:154` — `\(unit.beds) bd · \(unit.baths) ba · \(unit.sqft) sq ft`
- `Features/Properties/Components/PropertyDetailTabs.swift:168` — `$\(unit.rent)`
- `Features/Properties/Components/PropertyDetailTabs.swift:255` — `\(tenant.unit) · Lease ends \(tenant.leaseEnds)`
- `Features/Properties/Components/PropertyDetailTabs.swift:309` — `\(request.unit) · \(request.time)`
- `Features/Properties/PropertyDetailView.swift:186` — `\(property.neighborhood) · \(property.address)`
- `Features/Search/Components/SearchComponents.swift:96` — `\(count)`
- `Features/Settings/SettingsPrefViews.swift:71` — `\(viewModel.unitsUsed) / \(viewModel.unitQuota)`
- `Features/Settings/SettingsSectionViews.swift:127` — `rentos.app/\(viewModel.orgSlug)`
- `Features/Settings/SettingsSectionViews.swift:222` — `\(member.role) · \(member.email)`
- `Features/Tenants/Components/TenantComponents.swift:42` — `\(tenant.unitName) · \(tenant.propertyName)`
- `Features/Tenants/Components/TenantComponents.swift:56` — `ends \(tenant.leaseEnd)`
- `Features/Tenants/Components/TenantComponents.swift:65` — `$\(tenant.rent)`
- `Features/Tenants/Components/TenantComponents.swift:138` — `$\(tenant.rent)`
- `Features/Tenants/Components/TenantComponents.swift:166` — `\(Int(tenant.leaseProgress * 100))% elapsed`
- `Features/Tenants/CreateTenantView.swift:165` — `\(viewModel.name) added`
- `Features/Tenants/CreateTenantView.swift:169` — `Lease invite sent to \(viewModel.email)`
- `Features/Tenants/TenantDetailView.swift:131` — `\(tenant.unitName) · \(tenant.propertyName)`
- `Features/Tenants/TenantDetailView.swift:350` — `\(request.unit) · \(request.time)`

## Per-file counts

| Count | File |
|---:|---|
| 15 | `Features/Maintenance/MaintenanceDetailView.swift` |
| 13 | `Features/Settings/SettingsPrefViews.swift` |
| 11 | `Features/Properties/Components/PropertyDetailTabs.swift` |
| 8 | `Components/Core/DSOfflineIndicators.swift` |
| 8 | `Features/Tenants/Components/TenantComponents.swift` |
| 7 | `Features/AIAssistant/Components/AIAssistantComponents.swift` |
| 7 | `Features/Maintenance/Components/MaintenanceComponents.swift` |
| 7 | `Features/Tenants/TenantDetailView.swift` |
| 6 | `Features/Auth/Components/AuthComponents.swift` |
| 6 | `Features/Dashboard/Components/DashboardFeeds.swift` |
| 5 | `Features/Documents/Components/DocumentComponents.swift` |
| 5 | `Features/Properties/Components/PropertyActionComponents.swift` |
| 5 | `Features/Search/GlobalSearchView.swift` |
| 4 | `Components/Navigation/DSSidebar.swift` |
| 4 | `Features/AIAssistant/AIAssistantView.swift` |
| 4 | `Features/Dashboard/Components/DashboardCards.swift` |
| 4 | `Features/Notifications/NotificationsView.swift` |
| 4 | `Features/Properties/PropertyDetailView.swift` |
| 4 | `Features/Properties/PropertyListView.swift` |
| 4 | `Features/Settings/SettingsSectionViews.swift` |
| 3 | `Features/Onboarding/Components/OnboardingInsightsIllustration.swift` |
| 3 | `Features/OrgSetup/Steps/OrgSetupSteps.swift` |
| 3 | `Features/Properties/PropertyFormView.swift` |
| 3 | `Features/Settings/SettingsHubView.swift` |
| 3 | `Features/Tenants/CreateTenantView.swift` |
| 2 | `Components/Brand/PurrpertyLogo.swift` |
| 2 | `Components/Core/DSCard.swift` |
| 2 | `Components/Core/DSProgress.swift` |
| 2 | `Components/Core/DSStateViews.swift` |
| 2 | `DesignSystem/DesignSystemShowcase.swift` |
| 2 | `DesignSystem/Foundations/DSMaterials.swift` |
| 2 | `Features/Auth/Screens/ForgotPasswordView.swift` |
| 2 | `Features/Auth/Screens/ResetPasswordView.swift` |
| 2 | `Features/Dashboard/Components/DashboardHeroCard.swift` |
| 2 | `Features/Maintenance/MaintenanceInboxView.swift` |
| 2 | `Features/Messages/ChatView.swift` |
| 2 | `Features/Messages/Components/MessageComponents.swift` |
| 2 | `Features/OrgSetup/Components/OrgSetupComponents.swift` |
| 2 | `Features/OrgSetup/Steps/OrgCompletionView.swift` |
| 2 | `Features/Properties/Components/PropertyCard.swift` |
| 2 | `Features/Properties/UnitFormView.swift` |
| 1 | `Components/Core/DSAvatar.swift` |
| 1 | `Components/Core/DSFormField.swift` |
| 1 | `Components/Core/DSToast.swift` |
| 1 | `Components/Navigation/DSSheet.swift` |
| 1 | `Features/Auth/Screens/LoginView.swift` |
| 1 | `Features/Auth/Screens/SignUpView.swift` |
| 1 | `Features/Onboarding/Components/OnboardingIntroIllustration.swift` |
| 1 | `Features/Onboarding/Components/OnboardingMaintenanceIllustration.swift` |
| 1 | `Features/Onboarding/Components/OnboardingPortfolioIllustration.swift` |
| 1 | `Features/Onboarding/OnboardingView.swift` |
| 1 | `Features/Search/Components/SearchComponents.swift` |