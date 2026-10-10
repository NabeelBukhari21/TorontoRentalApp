//
//  MessageComponents.swift
//  RentalApp (Purrperty)
//
//  Messages — Bubbles, typing indicator, attachments, receipts,
//  conversation rows, and date separators.
//

import SwiftUI

// MARK: - Conversation Row

struct ConversationRow: View {

    let conversation: Conversation
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                DSAvatar(
                    name: conversation.name,
                    size: .medium,
                    status: conversation.isOnline ? .success : nil
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(conversation.name)
                            .font(
                                conversation.unreadCount > 0
                                    ? DS.Typography.headline
                                    : DS.Typography.subheadline
                            )
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1)

                        if conversation.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(DS.Colors.brand)
                                .rotationEffect(.degrees(45))
                        }

                        DSBadge(text: conversation.role.rawValue, kind: conversation.role.kind)
                            .scaleEffect(0.85)
                    }

                    Text(conversation.context)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .lineLimit(1)

                    Text(conversation.lastMessage)
                        .font(DS.Typography.caption)
                        .foregroundStyle(
                            conversation.unreadCount > 0
                                ? DS.Colors.textPrimary
                                : DS.Colors.textSecondary
                        )
                        .fontWeight(conversation.unreadCount > 0 ? .semibold : .regular)
                        .lineLimit(1)
                }

                Spacer(minLength: DS.Spacing.sm)

                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    Text(conversation.lastTime)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(
                            conversation.unreadCount > 0 ? DS.Colors.brand : DS.Colors.textTertiary
                        )

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(DS.Colors.onHighlight)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(
                                DS.Gradients.highlight,
                                in: Capsule()
                            )
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(
                isSelected ? AnyShapeStyle(DS.Colors.brand.opacity(0.1)) : AnyShapeStyle(DS.Colors.surfaceRaised),
                in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? AnyShapeStyle(DS.Colors.brand.opacity(0.45))
                            : (conversation.unreadCount > 0
                                ? AnyShapeStyle(DS.Colors.brand.opacity(0.3))
                                : AnyShapeStyle(DS.Gradients.cardHairline)),
                        lineWidth: 1
                    )
            )
            .dsShadow(DS.Shadows.soft)
        }
        .buttonStyle(DSPressStyle())
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {

    let message: ChatMessage
    var senderName: String = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            if message.isMine { Spacer(minLength: 48) }

            if !message.isMine {
                DSAvatar(name: senderName, size: .small)
            }

            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 3) {
                // Attachment.
                if let attachment = message.attachment {
                    ChatAttachmentView(attachment: attachment, isMine: message.isMine)
                }

                // Text.
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.system(size: 14.5, weight: .regular))
                        .foregroundStyle(message.isMine ? DS.Colors.onHighlight : DS.Colors.textPrimary)
                        .padding(.horizontal, DS.Spacing.md + 2)
                        .padding(.vertical, DS.Spacing.sm + 2)
                        .background(bubbleBackground)
                        .clipShape(bubbleShape)
                        .overlay(
                            bubbleShape.strokeBorder(
                                message.isMine ? Color.clear : DS.Colors.outline,
                                lineWidth: 1
                            )
                        )
                }

                // Time + receipt.
                HStack(spacing: 3) {
                    Text(message.time)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)

                    if message.isMine {
                        MessageReceipt(status: message.status)
                    }
                }
            }

            if !message.isMine { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: message.isMine ? .trailing : .leading)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.8, anchor: message.isMine ? .bottomTrailing : .bottomLeading)
                    .combined(with: .opacity),
                removal: .opacity
            )
        )
    }

    private var bubbleShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: message.isMine ? 18 : 5,
            bottomTrailingRadius: message.isMine ? 5 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    private var bubbleBackground: AnyShapeStyle {
        message.isMine
            ? AnyShapeStyle(
                DS.Gradients.highlight
              )
            : AnyShapeStyle(DS.Colors.surfaceRaised)
    }
}

// MARK: - Receipt

struct MessageReceipt: View {

    let status: MessageStatus

    var body: some View {
        Group {
            switch status {
            case .sending:
                Image(systemName: "clock")
                    .foregroundStyle(DS.Colors.textTertiary)
            case .sent:
                Image(systemName: "checkmark")
                    .foregroundStyle(DS.Colors.textTertiary)
            case .read:
                HStack(spacing: -3) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .foregroundStyle(DS.Colors.brand)
            }
        }
        .font(.system(size: 8.5, weight: .bold))
        .contentTransition(.symbolEffect(.replace))
    }
}

// MARK: - Attachment View

struct ChatAttachmentView: View {

    let attachment: ChatAttachment
    let isMine: Bool

    var body: some View {
        switch attachment {
        case .photo(let paletteIndex):
            ZStack(alignment: .bottomTrailing) {
                PropertyPalettes.gradient(paletteIndex)

                Canvas { context, size in
                    // Simple "photo" texture — soft light blobs.
                    for i in 0..<4 {
                        let x = size.width * (0.2 + Double(i) * 0.22)
                        let y = size.height * (i % 2 == 0 ? 0.3 : 0.6)
                        let rect = CGRect(x: x, y: y, width: 26, height: 26)
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(DS.Colors.onFixedColor.opacity(0.18))
                        )
                    }
                }

                Image(systemName: DS.Icons.camera)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(DS.Colors.onFixedColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("Photo")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.Colors.onFixedColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Colors.mediaBackground.opacity(0.35), in: Capsule())
                    .padding(6)
            }
            .frame(width: 190, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(DS.Colors.highlightLine, lineWidth: 1)
            )
            .dsShadow(DS.Shadows.soft)

        case .document(let name, let size):
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isMine ? DS.Colors.onHighlight : DS.Colors.brandInk)
                    .frame(width: 36, height: 36)
                    .background(
                        isMine ? DS.Colors.onHighlight.opacity(0.2) : DS.Colors.brand.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(isMine ? DS.Colors.onHighlight : DS.Colors.textPrimary)
                        .lineLimit(1)

                    Text(size)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(isMine ? DS.Colors.onHighlight : DS.Colors.textTertiary)
                }

                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isMine ? DS.Colors.onHighlight : DS.Colors.brandInk)
            }
            .padding(DS.Spacing.sm + 2)
            .background(
                isMine
                    ? AnyShapeStyle(
                        DS.Gradients.highlight
                      )
                    : AnyShapeStyle(DS.Colors.surfaceRaised),
                in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(isMine ? Color.clear : DS.Colors.outline, lineWidth: 1)
            )
            .frame(maxWidth: 240)
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorBubble: View {

    let senderName: String

    @State private var phase = false

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            DSAvatar(name: senderName, size: .small)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(DS.Colors.textTertiary)
                        .frame(width: 7, height: 7)
                        .offset(y: phase ? -4 : 2)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.16),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, DS.Spacing.md + 2)
            .padding(.vertical, DS.Spacing.md)
            .background(DS.Colors.surfaceRaised, in: Capsule())
            .overlay(Capsule().strokeBorder(DS.Colors.outline, lineWidth: 1))

            Spacer(minLength: 48)
        }
        .transition(.scale(scale: 0.7, anchor: .bottomLeading).combined(with: .opacity))
        .onAppear { phase = true }
    }
}

// MARK: - Date Separator

struct ChatDateSeparator: View {

    let text: String

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            line
            Text(text)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.Colors.textTertiary)
                .fixedSize()
            line
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    private var line: some View {
        LinearGradient(
            colors: [.clear, DS.Colors.outline],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 0.5)
    }
}

// MARK: - Previews

#Preview("Message Components") {
    ZStack {
        DSAmbientBackground()

        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                ConversationRow(conversation: MessagesMockData.conversations[0], isSelected: false) {}

                ChatDateSeparator(text: "Today")

                ChatBubble(
                    message: ChatMessage(text: "Hi! There's water pooling under my sink 😰", isMine: false, time: "9:41 AM"),
                    senderName: "Sarah Chen"
                )
                ChatBubble(
                    message: ChatMessage(text: "A plumber is booked for today.", isMine: true, time: "9:55 AM", status: .read)
                )
                ChatBubble(
                    message: ChatMessage(text: "", isMine: false, time: "9:42 AM", attachment: .photo(paletteIndex: 1)),
                    senderName: "Sarah Chen"
                )

                TypingIndicatorBubble(senderName: "Sarah Chen")
            }
            .padding(DS.Spacing.xl)
        }
    }
}
