//
//  DashboardHeroCard.swift
//  RentalApp
//
//  Dashboard — Hero analytics card: rolling revenue counter and a
//  gradient area chart that sweeps into view.
//

import SwiftUI
import Charts

struct DashboardHeroCard: View {

    let portfolioValue: String
    let monthlyRevenue: Double
    let revenueTrend: String
    let propertyCount: Int
    let unitCount: Int
    let revenue: [RevenuePoint]

    @State private var hasAppeared = false
    @State private var chartReveal: CGFloat = 0

    var body: some View {
        DSCard(style: .raised, cornerRadius: DS.Radius.xl, padding: DS.Spacing.xl) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                // Top row.
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Monthly Revenue").dsOverline()

                        Text(hasAppeared ? "$\(monthlyRevenue, specifier: "%.1f")K" : "$0.0K")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DS.Colors.textPrimary)
                            .contentTransition(.numericText())

                        Text(revenueTrend)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.success)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        DSBadge(text: "Live", kind: .success, icon: "dot.radiowaves.left.and.right")

                        Text(portfolioValue)
                            .font(DS.Typography.statValueSmall)
                            .foregroundStyle(DS.Colors.textPrimary)

                        Text("\(propertyCount) properties · \(unitCount) units")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }

                // Chart with sweep reveal.
                chart
                    .frame(height: 140)
                    .mask(
                        GeometryReader { proxy in
                            Rectangle()
                                .frame(width: proxy.size.width * chartReveal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    )
            }
        }
        .onAppear {
            guard !hasAppeared else { return }
            withAnimation(DS.Motion.smooth.delay(0.3)) {
                hasAppeared = true
            }
            withAnimation(.easeInOut(duration: 1.1).delay(0.35)) {
                chartReveal = 1
            }
        }
    }

    // MARK: Chart

    private var chart: some View {
        Chart(revenue) { point in
            AreaMark(
                x: .value("Month", point.month),
                y: .value("Revenue", point.amount)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        DS.Colors.brand.opacity(0.35),
                        DS.Colors.accentSunnyInk.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Month", point.month),
                y: .value("Revenue", point.amount)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(DS.Gradients.brand)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

            if point.id == revenue.last?.id {
                PointMark(
                    x: .value("Month", point.month),
                    y: .value("Revenue", point.amount)
                )
                .symbol {
                    ZStack {
                        Circle()
                            .fill(DS.Colors.brand.opacity(0.25))
                            .frame(width: 20, height: 20)
                        Circle()
                            .fill(DS.Colors.brand)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(DS.Colors.surfaceRaised, lineWidth: 2))
                    }
                }
            }
        }
        .chartYScale(domain: chartDomain)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel()
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
    }

    private var chartDomain: ClosedRange<Double> {
        let amounts = revenue.map(\.amount)
        let minValue = (amounts.min() ?? 0) - 2
        let maxValue = (amounts.max() ?? 100) + 2
        return minValue...maxValue
    }
}

#Preview("Hero Card") {
    ZStack {
        DSAmbientBackground()
        DashboardHeroCard(
            portfolioValue: "$4.2M",
            monthlyRevenue: 52.4,
            revenueTrend: "+$1.2K vs June",
            propertyCount: 12,
            unitCount: 48,
            revenue: DashboardMockData.revenue
        )
        .padding(DS.Spacing.xl)
    }
}
