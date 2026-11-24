//
//  RentStreakCard.swift
//  RentalApp (Purrperty)
//
//  Dashboard — The on-time rent streak as a trail of paw prints, one per
//  month: solid when every tenant paid on time, hollow when not.
//

import SwiftUI

struct RentStreakCard: View {

    let streak: RentStreak
    let onOpen: () -> Void

    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onOpen) {
            DSCard(style: .raised) {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(DS.Typography.brand(.title3, weight: .semibold))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text(detail)
                                .font(DS.Typography.brand(.subheadline, weight: .regular))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        PurrMascot(mood: streak.count > 0 ? .streak : .rentDue, size: 84, isInteractive: false)
                            .padding(.vertical, -10)
                    }
                    trail
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(SquishStyle(scale: 0.97))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityAddTraits(.isButton)
        .task {
            for i in 0...streak.months.count {
                withAnimation(DS.Motion.bouncy) { shown = i }
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(90)) }
            }
        }
    }

    private var title: String {
        switch streak.count {
        case 0: "Start a rent streak"
        case 1: "1 month on time"
        default: "\(streak.count) months on time"
        }
    }

    private var detail: String {
        streak.count == 0
            ? "A month counts when every tenant pays by the due date."
            : "Every tenant paid by the due date."
    }

    private var trail: some View {
        HStack(spacing: 0) {
            ForEach(Array(streak.months.enumerated()), id: \.element.id) { i, month in
                VStack(spacing: 4) {
                    Image(systemName: month.isOnTime ? "pawprint.fill" : "pawprint")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(month.isOnTime ? AnyShapeStyle(DS.Colors.brand) : AnyShapeStyle(DS.Colors.textTertiary))
                        .rotationEffect(.degrees(i.isMultiple(of: 2) ? 74 : 106))
                        .offset(y: i.isMultiple(of: 2) ? -5 : 5)
                        .scaleEffect(i < shown ? 1 : 0.2)
                        .opacity(i < shown ? 1 : 0)
                    Text(month.month, format: .dateTime.month(.narrow))
                        .font(DS.Typography.brand(.caption2))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 4)
    }
}
