//
//  OnboardingView.swift
//  RentalApp
//
//  Onboarding — Four-page swipeable experience, guided by the mascot.
//
//  The cat sits OUTSIDE the paged content, Duolingo-style: the pages slide
//  behind it while it stays put, reacts to each swipe with a change of
//  mood, and "says" each page's message in its speech bubble. Shares the
//  splash background so the launch flow reads as one continuous space.
//

import SwiftUI

struct OnboardingView: View {

    /// Called when onboarding completes — the parent advances to the main app.
    let onFinished: () -> Void

    @State private var selection: OnboardingPage = .intro

    var body: some View {
        ZStack {
            SplashBackground()
            SplashParticleField(particleCount: 22)

            VStack(spacing: 0) {
                topBar

                TabView(selection: $selection) {
                    ForEach(OnboardingPage.allCases) { page in
                        OnboardingPageView(page: page, isActive: selection == page)
                            .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(DS.Motion.smooth, value: selection)

                // The guide. One instance for every page, so it reacts to
                // page changes instead of being rebuilt with each page.
                MascotGuide(
                    mood: selection.mascotMood,
                    message: selection.mascotLine,
                    mascotSize: 112,
                    // On the intro page Purr is already on stage in the
                    // hello clip; the bubble points up at it instead.
                    showsMascot: selection != .intro
                )
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.sm)

                bottomBar
            }
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            Spacer()

            Button {
                onFinished()
            } label: {
                Text("Skip")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.surfaceRaised, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(DS.Colors.outline, lineWidth: 1)
                    )
            }
            .buttonStyle(DSPressStyle(scale: 0.94))
            .opacity(selection.isLast ? 0 : 1)
            .animation(DS.Motion.gentle, value: selection)
            .disabled(selection.isLast)
            .accessibilityLabel("Skip onboarding")
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.sm)
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: DS.Spacing.xl) {
            OnboardingProgressIndicator(current: selection)

            DSButton(
                title: selection.isLast ? "Get Started" : "Continue",
                icon: selection.isLast ? DS.Icons.aiAssistant : nil,
                variant: .primary,
                size: .large,
                isFullWidth: true
            ) {
                advance()
            }
            .padding(.horizontal, DS.Spacing.xxl)
        }
        .padding(.bottom, DS.Spacing.xxl)
    }

    // MARK: Actions

    private func advance() {
        if let next = selection.next {
            withAnimation(DS.Motion.smooth) {
                selection = next
            }
        } else {
            onFinished()
        }
    }
}

// MARK: - Page

private struct OnboardingPageView: View {

    let page: OnboardingPage
    let isActive: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            illustration
                .frame(height: 290)
                .frame(maxWidth: .infinity)

            VStack(spacing: DS.Spacing.md) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DS.Colors.textPrimary, DS.Colors.brandInk],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .multilineTextAlignment(.center)
                    .opacity(isActive ? 1 : 0)
                    .offset(y: isActive ? 0 : 16)
                    .animation(DS.Motion.entrance.delay(0.2), value: isActive)
                // The page's explanation is spoken by the mascot below
                // (`OnboardingPage.mascotLine`) rather than repeated here.
            }
            .padding(.horizontal, DS.Spacing.xxl)

            Spacer(minLength: 0)
        }
        .padding(.top, DS.Spacing.lg)
    }

    @ViewBuilder
    private var illustration: some View {
        switch page {
        case .intro:
            OnboardingIntroIllustration(isActive: isActive)
        case .maintenance:
            OnboardingMaintenanceIllustration(isActive: isActive)
        case .portfolio:
            OnboardingPortfolioIllustration(isActive: isActive)
        case .insights:
            OnboardingInsightsIllustration(isActive: isActive)
        }
    }
}

// MARK: - Previews

#Preview("Onboarding") {
    OnboardingView(onFinished: {})
}
