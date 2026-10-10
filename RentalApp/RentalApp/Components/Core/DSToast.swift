//
//  DSToast.swift
//  RentalApp (Purrperty)
//
//  Components — Transient feedback, and the confirmation modifier.
//
//  The toast sits above the tab bar rather than at the top, because on
//  a phone the user's thumb is already down there when they trigger the
//  action they might want to undo.
//

import SwiftUI

// MARK: - Toast View

struct DSToastView: View {

    let toast: Toast
    let isUndoing: Bool
    let onUndo: () -> Void
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // The cat reacts to the outcome; the text carries the meaning.
            MascotFaceView(face: toast.style.mascotFace, size: 30)

            Text(toast.message)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(DS.Colors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DS.Spacing.sm)

            if toast.undo != nil {
                Button(action: onUndo) {
                    if isUndoing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(DS.Colors.brand)
                    } else {
                        Text("Undo")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.brand)
                    }
                }
                .buttonStyle(DSPressStyle(scale: 0.93))
                .disabled(isUndoing)
            } else if toast.retry != nil {
                Button("Retry", action: onRetry)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.brand)
                    .buttonStyle(DSPressStyle(scale: 0.93))
            } else {
                Button(action: onDismiss) {
                    Image(systemName: DS.Icons.close)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(DSPressStyle(scale: 0.9))
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Colors.surfaceRaised, in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                toast.style == .failure
                    ? AnyShapeStyle(DS.Colors.danger.opacity(0.35))
                    : AnyShapeStyle(DS.Gradients.cardHairline),
                lineWidth: 1
            )
        )
        .dsShadow(DS.Shadows.floating)
        .padding(.horizontal, DS.Spacing.lg)
    }
}

extension Toast.Style: Equatable {}

// MARK: - Host

/// Mounts the toast layer over its content. Applied once, at the root.
private struct DSToastHost: ViewModifier {

    @Environment(\.toasts) private var toasts

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let toast = toasts.current {
                    DSToastView(
                        toast: toast,
                        isUndoing: toasts.isUndoing,
                        onUndo: { Task { await toasts.performUndo() } },
                        onRetry: { Task { await toasts.runRetry() } },
                        onDismiss: { toasts.dismiss() }
                    )
                    .padding(.bottom, DSTabBar.overlayClearance)
                    .transition(
                        .move(edge: .bottom).combined(with: .opacity)
                    )
                    // A toast is an announcement, not a control surface —
                    // it must never swallow a tap meant for the tab bar.
                    .allowsHitTesting(true)
                }
            }
            .animation(DS.Motion.bouncy, value: toasts.current?.id)
    }
}

extension View {
    /// Mount the app-wide toast layer.
    func dsToastLayer() -> some View {
        modifier(DSToastHost())
    }
}

// MARK: - Confirmation

/// A destructive action awaiting confirmation.
///
/// Modelled as a value so a view can hold one `@State` and drive the
/// dialog from any number of rows, instead of a Bool per action.
struct DSConfirmation: Identifiable {

    let id = UUID()
    let title: String
    let message: String?
    let confirmTitle: String
    let isDestructive: Bool
    let action: @MainActor () -> Void

    init(
        title: String,
        message: String? = nil,
        confirmTitle: String = "Confirm",
        isDestructive: Bool = true,
        action: @escaping @MainActor () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.action = action
    }
}

extension View {

    /// Presents a native confirmation dialog for a pending destructive
    /// action.
    ///
    /// Native rather than a custom glass sheet on purpose: iOS users
    /// already know this control means "this is serious", and a bespoke
    /// one would look designed but read as less trustworthy.
    func dsConfirmation(_ pending: Binding<DSConfirmation?>) -> some View {
        confirmationDialog(
            pending.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: pending.wrappedValue
        ) { confirmation in
            Button(
                confirmation.confirmTitle,
                role: confirmation.isDestructive ? .destructive : nil
            ) {
                confirmation.action()
                pending.wrappedValue = nil
            }
            Button("Cancel", role: .cancel) {
                pending.wrappedValue = nil
            }
        } message: { confirmation in
            if let message = confirmation.message {
                Text(message)
            }
        }
    }
}

// MARK: - Previews

#Preview("Toast") {
    ZStack {
        DSAmbientBackground()
        VStack(spacing: DS.Spacing.lg) {
            DSToastView(
                toast: Toast(
                    message: "Property archived",
                    style: .success,
                    undo: UndoToken(message: "Property archived") {}
                ),
                isUndoing: false, onUndo: {}, onRetry: {}, onDismiss: {}
            )
            DSToastView(
                toast: Toast(
                    message: "We couldn't reach the network. Check your connection and try again.",
                    style: .failure,
                    retry: {}
                ),
                isUndoing: false, onUndo: {}, onRetry: {}, onDismiss: {}
            )
            DSToastView(
                toast: Toast(message: "3 properties archived", style: .info),
                isUndoing: false, onUndo: {}, onRetry: {}, onDismiss: {}
            )
        }
    }
}

// MARK: - Mascot

private extension Toast.Style {
    /// The cat's reaction to each outcome.
    var mascotFace: MascotFace {
        switch self {
        case .success: .happy
        case .failure: .sad
        case .info:    .curious
        }
    }
}
