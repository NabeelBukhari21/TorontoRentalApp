//
//  DSStateViews.swift
//  RentalApp (RentOS)
//
//  Components — Shared renderings for the asynchronous states every
//  screen can be in. One error view means one retry affordance, one
//  tone of voice, and one place to change either.
//

import SwiftUI

// MARK: - Error + Retry

/// The failure state. Always offers a way forward — an error screen
/// without a retry button is a dead end.
struct DSErrorView: View {

    let error: AppError
    var retry: (() async -> Void)?

    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DS.Colors.danger.opacity(0.15))
                    .frame(width: 84, height: 84)
                    .blur(radius: 12)

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle().strokeBorder(DS.Colors.danger.opacity(0.3), lineWidth: 1)
                    )

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DS.Colors.danger)
            }
            .dsFloating(amplitude: 4, duration: 3.6)

            VStack(spacing: DS.Spacing.sm) {
                Text("Something went wrong")
                    .font(DS.Typography.title3)
                    .foregroundStyle(DS.Colors.textPrimary)

                Text(error.errorDescription ?? "Please try again.")
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let retry {
                DSButton(
                    title: "Try Again",
                    icon: "arrow.clockwise",
                    variant: .primary,
                    isLoading: isRetrying
                ) {
                    Task {
                        isRetrying = true
                        await retry()
                        isRetrying = false
                    }
                }
                .padding(.top, DS.Spacing.sm)
            }
        }
        .padding(DS.Spacing.xxxl)
        .frame(maxWidth: .infinity)
        .dsEntrance()
    }
}

// MARK: - List Skeleton

/// First-load placeholder for list screens. Matches the row rhythm so
/// content does not jump when it arrives.
struct DSListSkeleton: View {

    var rows: Int = 5

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(0..<rows, id: \.self) { _ in
                DSSkeletonCard()
            }
        }
        .transition(.opacity)
    }
}

/// Card-grid placeholder, for the property and document screens.
struct DSCardSkeleton: View {

    var cards: Int = 3

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ForEach(0..<cards, id: \.self) { _ in
                DSSkeleton(shape: .rect(height: 190, cornerRadius: DS.Radius.xl))
            }
        }
        .transition(.opacity)
    }
}

// MARK: - Pagination Footer

/// Shown beneath a list while the next page loads.
struct DSPaginationFooter: View {

    let isLoading: Bool

    var body: some View {
        if isLoading {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView()
                    .controlSize(.small)
                    .tint(DS.Colors.brand)

                Text("Loading more…")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .transition(.opacity)
        }
    }
}

// MARK: - State Switch

/// Renders the right thing for a `LoadState`, so screens don't each
/// re-implement the same four-branch `switch`.
struct DSStateView<Value, Content: View, Skeleton: View>: View {

    let state: LoadState<Value>
    var retry: (() async -> Void)?
    @ViewBuilder let content: (Value) -> Content
    @ViewBuilder let skeleton: () -> Skeleton

    var body: some View {
        switch state {
        case .idle, .loading:
            skeleton()
        case .loaded(let value):
            content(value)
        case .failed(let error):
            DSErrorView(error: error, retry: retry)
        }
    }
}

// MARK: - Previews

#Preview("States") {
    ZStack {
        DSAmbientBackground()

        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                DSErrorView(error: .network) {}
                DSListSkeleton(rows: 2)
                DSPaginationFooter(isLoading: true)
            }
            .padding(DS.Spacing.xl)
        }
    }
}
