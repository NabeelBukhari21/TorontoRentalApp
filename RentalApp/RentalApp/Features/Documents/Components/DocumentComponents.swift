//
//  DocumentComponents.swift
//  RentalApp (RentOS)
//
//  Documents — File cards (grid + list), folder cards, drop zone,
//  upload rows, and the PDF preview placeholder.
//

import SwiftUI

// MARK: - File Thumbnail

/// Type-specific preview art for a file.
struct DocFileThumbnail: View {

    let file: DocFile
    var height: CGFloat = 110

    var body: some View {
        ZStack {
            switch file.type {
            case .pdf, .contract:
                pagePreview
            case .image:
                PropertyPalettes.gradient(file.paletteIndex)
                Image(systemName: DS.Icons.camera)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(DS.Colors.onFixedColor)
            case .spreadsheet:
                sheetPreview
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .topTrailing) {
            // Type chip.
            Text(file.type.rawValue)
                .font(.system(size: 8.5, weight: .heavy, design: .rounded))
                .foregroundStyle(file.type.accent.onFill)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(file.type.accent.fill, in: Capsule())
                .padding(6)
        }
    }

    /// Mock document page with text lines.
    private var pagePreview: some View {
        ZStack {
            DS.Colors.surfaceSecondary

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DS.Colors.surfaceRaised)
                .frame(width: 66, height: 84)
                .overlay(
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(file.type.accent.fill)
                            .frame(width: 26, height: 5)

                        ForEach(0..<6, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(DS.Colors.textPrimary.opacity(0.15))
                                .frame(width: index == 5 ? 30 : 50, height: 3)
                        }

                        if file.type == .contract {
                            HStack {
                                Spacer()
                                Image(systemName: "signature")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(DS.Colors.brand)
                            }
                        }
                    }
                    .padding(8)
                )
                .dsShadow(DS.Shadows.soft)
                .rotationEffect(.degrees(-2))
        }
    }

    /// Mock spreadsheet grid.
    private var sheetPreview: some View {
        ZStack {
            DS.Colors.surfaceSecondary

            Canvas { context, size in
                let cols = 5
                let rows = 5
                let cellW = (size.width - 40) / CGFloat(cols)
                let cellH: CGFloat = 12
                let originX: CGFloat = 20
                let originY = (size.height - CGFloat(rows) * cellH) / 2

                for row in 0...rows {
                    var path = Path()
                    path.move(to: CGPoint(x: originX, y: originY + CGFloat(row) * cellH))
                    path.addLine(to: CGPoint(x: originX + CGFloat(cols) * cellW, y: originY + CGFloat(row) * cellH))
                    context.stroke(path, with: .color(DS.Colors.success.opacity(0.35)), lineWidth: 1)
                }
                for col in 0...cols {
                    var path = Path()
                    path.move(to: CGPoint(x: originX + CGFloat(col) * cellW, y: originY))
                    path.addLine(to: CGPoint(x: originX + CGFloat(col) * cellW, y: originY + CGFloat(rows) * cellH))
                    context.stroke(path, with: .color(DS.Colors.success.opacity(0.35)), lineWidth: 1)
                }

                // Header row fill.
                let header = CGRect(x: originX, y: originY, width: CGFloat(cols) * cellW, height: cellH)
                context.fill(Path(header), with: .color(DS.Colors.success.opacity(0.25)))
            }
        }
    }
}

// MARK: - Grid Card

struct DocFileGridCard: View {

    let file: DocFile
    let onOpen: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 0) {
                DocFileThumbnail(file: file)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(file.name)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: DS.Spacing.xs) {
                        Text("\(file.size) · \(file.date)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(DS.Colors.textTertiary)

                        Spacer()

                        Button(action: onFavorite) {
                            Image(systemName: file.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(file.isFavorite ? DS.Colors.brand : DS.Colors.textTertiary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(DSPressStyle(scale: 0.8))
                    }

                    if !file.tags.isEmpty {
                        HStack(spacing: 3) {
                            ForEach(file.tags.prefix(2), id: \.self) { tag in
                                DocTagChip(tag: tag, isSelected: false, compact: true)
                            }
                        }
                    }
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.surfaceRaised)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(DS.Gradients.cardHairline, lineWidth: 1)
            )
            .dsShadow(DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle())
    }
}

// MARK: - List Row

struct DocFileListRow: View {

    let file: DocFile
    let onOpen: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: file.type.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(file.type.tint)
                    .frame(width: 40, height: 40)
                    .background(file.type.tint.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.xs) {
                        Text("\(file.type.rawValue) · \(file.size) · \(file.date)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.Colors.textTertiary)

                        ForEach(file.tags.prefix(2), id: \.self) { tag in
                            DocTagChip(tag: tag, isSelected: false, compact: true)
                        }
                    }
                }

                Spacer(minLength: DS.Spacing.sm)

                Button(action: onFavorite) {
                    Image(systemName: file.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(file.isFavorite ? DS.Colors.brand : DS.Colors.textTertiary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(DSPressStyle(scale: 0.8))

                Image(systemName: DS.Icons.chevronRight)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(DS.Gradients.cardHairline, lineWidth: 1)
            )
            .dsShadow(DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle())
    }
}

// MARK: - Tag Chip

struct DocTagChip: View {

    let tag: String
    var isSelected: Bool = false
    var compact: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(DSPressStyle(scale: 0.92))
            } else {
                label
            }
        }
    }

    private var label: some View {
        HStack(spacing: 2) {
            Image(systemName: "tag.fill")
                .font(.system(size: compact ? 6 : 8, weight: .bold))
            Text(tag)
                .font(.system(size: compact ? 8.5 : 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? DS.Colors.onHighlight : DS.Colors.brand)
        .padding(.horizontal, compact ? 5 : DS.Spacing.sm + 1)
        .padding(.vertical, compact ? 2 : 4)
        .background(
            isSelected
                ? AnyShapeStyle(
                    DS.Gradients.highlight
                  )
                : AnyShapeStyle(DS.Colors.brand.opacity(0.1)),
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(DS.Colors.brand.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
        )
    }
}

// MARK: - Folder Card

struct DocFolderCard: View {

    let folder: DocFolder
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Image(systemName: folder.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? DS.Colors.textOnBrand : folder.tint)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected ? AnyShapeStyle(DS.Gradients.brand) : AnyShapeStyle(folder.tint.opacity(0.13)),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    )

                Text(folder.name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                Text("\(count) files")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .contentTransition(.numericText())
            }
            .padding(DS.Spacing.md)
            .frame(width: 118, alignment: .leading)
            .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(DS.Colors.brand.opacity(0.55))
                            : AnyShapeStyle(DS.Gradients.cardHairline),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .dsShadow(isSelected ? DS.Shadows.glow(DS.Colors.brand, intensity: 0.2) : DS.Shadows.soft)
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(DSPressStyle())
        .animation(DS.Motion.bouncy, value: isSelected)
    }
}

// MARK: - Drop Zone

struct DocDropZone: View {

    var isTargeted: Bool
    let onBrowse: () -> Void

    @State private var dashPhase: CGFloat = 0

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "square.and.arrow.up.on.square.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(
                    isTargeted
                        ? AnyShapeStyle(DS.Gradients.brand)
                        : AnyShapeStyle(DS.Colors.textTertiary)
                )
                .contentTransition(.symbolEffect(.replace))
                .scaleEffect(isTargeted ? 1.2 : 1)

            Text(isTargeted ? "Release to upload" : "Drop files here")
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(isTargeted ? DS.Colors.brand : DS.Colors.textPrimary)

            Button(action: onBrowse) {
                Text("or browse")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.brandInk)
            }
            .buttonStyle(DSPressStyle(scale: 0.95))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(isTargeted ? DS.Colors.brand.opacity(0.08) : DS.Colors.background.opacity(0.001))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(
                    isTargeted ? DS.Colors.brand : DS.Colors.brand.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5], dashPhase: dashPhase)
                )
        )
        .animation(DS.Motion.bouncy, value: isTargeted)
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                dashPhase = -24
            }
        }
    }
}

// MARK: - Upload Row

struct DocUploadRow: View {

    let upload: DocUpload

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .stroke(DS.Colors.outline, lineWidth: 3)

                Circle()
                    .trim(from: 0, to: upload.progress)
                    .stroke(
                        DS.Gradients.brand,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Image(systemName: upload.type.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(upload.type.tint)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(upload.name)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(1)

                DSProgressBar(value: upload.progress, height: 4)
            }

            Text("\(Int(upload.progress * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.brandInk)
                .contentTransition(.numericText())
                .frame(width: 34, alignment: .trailing)
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Colors.brand.opacity(0.25), lineWidth: 1)
        )
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

// MARK: - PDF Preview Sheet

struct DocPreviewSheet: View {

    let file: DocFile

    @Environment(\.dismiss) private var dismiss
    @State private var pageVisible = false

    var body: some View {
        DSModalCard(title: file.name, subtitle: "\(file.type.rawValue) · \(file.size) · \(file.date)") {
            VStack(spacing: DS.Spacing.lg) {
                // Mock page.
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.Colors.surfaceRaised)
                        .dsShadow(DS.Shadows.floating)

                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(file.type.accent.fill)
                            .frame(width: 90, height: 12)

                        ForEach(0..<12, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(DS.Colors.textPrimary.opacity(index % 4 == 3 ? 0.06 : 0.14))
                                .frame(width: index % 4 == 3 ? 120 : nil, height: 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Spacer()

                        HStack {
                            Spacer()
                            Image(systemName: "signature")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(DS.Colors.brand.opacity(0.7))
                        }
                    }
                    .padding(DS.Spacing.xl)
                }
                .aspectRatio(0.72, contentMode: .fit)
                .frame(maxHeight: 420)
                .scaleEffect(pageVisible ? 1 : 0.92)
                .opacity(pageVisible ? 1 : 0)

                // Tags.
                if !file.tags.isEmpty {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(file.tags, id: \.self) { tag in
                            DocTagChip(tag: tag)
                        }
                        Spacer()
                    }
                }

                // Actions.
                HStack(spacing: DS.Spacing.md) {
                    DSButton(title: "Share", icon: "square.and.arrow.up", variant: .secondary, isFullWidth: true) {}
                    DSButton(title: "Download", icon: "arrow.down.circle.fill", variant: .primary, isFullWidth: true) {
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .onAppear {
            withAnimation(DS.Motion.entrance.delay(0.15)) {
                pageVisible = true
            }
        }
    }
}

// MARK: - Previews

#Preview("Document Components") {
    ZStack {
        DSAmbientBackground()

        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                DocDropZone(isTargeted: false) {}

                HStack(spacing: DS.Spacing.md) {
                    DocFileGridCard(file: DocumentsMockData.files[0], onOpen: {}, onFavorite: {})
                    DocFileGridCard(file: DocumentsMockData.files[3], onOpen: {}, onFavorite: {})
                }

                DocFileListRow(file: DocumentsMockData.files[1], onOpen: {}, onFavorite: {})

                DocUploadRow(upload: DocUpload(name: "New Lease.pdf", type: .pdf, progress: 0.62))
            }
            .padding(DS.Spacing.xl)
        }
    }
}
