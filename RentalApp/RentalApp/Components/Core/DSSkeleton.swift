//
//  DSSkeleton.swift
//  RentalApp
//
//  Design System — Loading skeletons with shimmer.
//

import SwiftUI

// MARK: - Shimmer Effect

/// A moving highlight band. Applied automatically by `DSSkeleton`,
/// or add to any placeholder with `.dsShimmer()`.
struct DSShimmerModifier: ViewModifier {

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            .white.opacity(0),
                            .white.opacity(0.5),
                            .white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: phase * proxy.size.width * 1.6)
                    .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {

    /// Adds a moving shimmer highlight. For custom skeleton layouts.
    func dsShimmer() -> some View {
        modifier(DSShimmerModifier())
    }
}

// MARK: - Skeleton Shapes

/// A shimmering placeholder block.
struct DSSkeleton: View {

    enum Shape {
        case line(width: CGFloat? = nil, height: CGFloat = 12)
        case rect(height: CGFloat, cornerRadius: CGFloat = DS.Radius.md)
        case circle(diameter: CGFloat)
    }

    let shape: Shape

    var body: some View {
        placeholder
            .foregroundStyle(DS.Colors.surfaceSecondary)
            .dsShimmer()
    }

    @ViewBuilder
    private var placeholder: some View {
        switch shape {
        case .line(let width, let height):
            Capsule()
                .frame(width: width, height: height)
                .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        case .rect(let height, let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .frame(height: height)
        case .circle(let diameter):
            Circle()
                .frame(width: diameter, height: diameter)
        }
    }
}

// MARK: - Skeleton Card

/// A ready-made loading placeholder matching the standard card layout.
struct DSSkeletonCard: View {

    var body: some View {
        DSCard(style: .elevated) {
            HStack(spacing: DS.Spacing.md) {
                DSSkeleton(shape: .circle(diameter: 44))

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    DSSkeleton(shape: .line(width: 140, height: 12))
                    DSSkeleton(shape: .line(width: 90, height: 10))
                }

                Spacer()
            }
        }
    }
}

// MARK: - Previews

#Preview("Skeletons") {
    ZStack {
        DS.Colors.background.ignoresSafeArea()

        VStack(spacing: DS.Spacing.md) {
            DSSkeleton(shape: .rect(height: 120, cornerRadius: DS.Radius.lg))
            DSSkeletonCard()
            DSSkeletonCard()
        }
        .padding(DS.Spacing.xxl)
    }
}
