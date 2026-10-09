//
//  DSAvatar.swift
//  RentalApp
//
//  Design System — Avatar with initials fallback, deterministic gradient,
//  optional image and status indicator.
//

import SwiftUI

struct DSAvatar: View {

    enum Size {
        case small, medium, large, xlarge

        var diameter: CGFloat {
            switch self {
            case .small: 32
            case .medium: 44
            case .large: 60
            case .xlarge: 88
            }
        }

        var font: Font {
            switch self {
            case .small: .system(size: 12, weight: .semibold, design: .rounded)
            case .medium: .system(size: 16, weight: .semibold, design: .rounded)
            case .large: .system(size: 22, weight: .bold, design: .rounded)
            case .xlarge: .system(size: 32, weight: .bold, design: .rounded)
            }
        }
    }

    let name: String
    var image: Image? = nil
    var size: Size = .medium
    var status: DSStatusKind? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent
                .frame(width: size.diameter, height: size.diameter)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
                )
                .dsShadow(DS.Shadows.soft)

            if let status {
                Circle()
                    .fill(status.color)
                    .frame(width: size.diameter * 0.26, height: size.diameter * 0.26)
                    .overlay(
                        Circle().strokeBorder(DS.Colors.surface, lineWidth: 2)
                    )
            }
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let image {
            image
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                gradient
                Text(initials)
                    .font(size.font)
                    .foregroundStyle(.white)
            }
        }
    }

    /// Up to two initials from the name, e.g. "Sarah Chen" → "SC".
    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.joined().uppercased()
    }

    /// Deterministic gradient derived from the name, so each person
    /// keeps a stable color everywhere in the app.
    private var gradient: LinearGradient {
        let palette: [(Color, Color)] = [
            (DS.Colors.brand, DS.Colors.brandViolet),
            (DS.Colors.brandCyan, DS.Colors.brand),
            (DS.Colors.accentCoral, DS.Colors.brandViolet),
            (DS.Colors.success, DS.Colors.brandCyan),
            (DS.Colors.accentAmber, DS.Colors.accentCoral)
        ]
        var hash = 0
        for scalar in name.unicodeScalars {
            hash = (hash &* 31 &+ Int(scalar.value)) & 0xFFFF
        }
        let pair = palette[hash % palette.count]
        return LinearGradient(
            colors: [pair.0, pair.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Avatar Stack

/// Overlapping avatars for teams / multiple tenants.
struct DSAvatarStack: View {

    let names: [String]
    var size: DSAvatar.Size = .small
    var maxVisible: Int = 4

    var body: some View {
        HStack(spacing: -size.diameter * 0.3) {
            ForEach(Array(names.prefix(maxVisible).enumerated()), id: \.offset) { _, name in
                DSAvatar(name: name, size: size)
            }

            if names.count > maxVisible {
                ZStack {
                    Circle().fill(DS.Colors.surfaceSecondary)
                    Text("+\(names.count - maxVisible)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .frame(width: size.diameter, height: size.diameter)
                .overlay(Circle().strokeBorder(DS.Colors.surface, lineWidth: 2))
            }
        }
    }
}

// MARK: - Previews

#Preview("Avatars") {
    ZStack {
        DS.Colors.background.ignoresSafeArea()

        VStack(spacing: DS.Spacing.xxl) {
            HStack(spacing: DS.Spacing.lg) {
                DSAvatar(name: "Sarah Chen", size: .small)
                DSAvatar(name: "Marcus Johnson", size: .medium, status: .success)
                DSAvatar(name: "Priya Patel", size: .large, status: .warning)
                DSAvatar(name: "Syed Bukhari", size: .xlarge)
            }

            DSAvatarStack(names: ["Sarah Chen", "Marcus Johnson", "Priya Patel", "Ada Lovelace", "Grace Hopper", "Alan Kay"])
        }
        .padding(DS.Spacing.xxl)
    }
}
