//
//  DSToast.swift
//  RentalApp (Purrperty)
//
//  Components — Transient feedback, and the confirmation modifier.
//
//  Feedback banner: a Liquid Glass capsule at the top of the screen,
//  like a system banner. It's a control-layer element, so glass is
//  right here; the message itself is plain text on it.
//

import SwiftUI

// MARK: - Toast View

struct DSToastView: View {

    let toast: Toast
    let isUndoing: Bool
    let onUndo: () -> Void
    let onRetry: () -> Void
    let onDismiss: () -> Void

    private var role: StatusRole {
        switch toast.style {
        case .success: .positive
        case .failure: .critical
        case .info:    .informational
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(symbol: role.symbol)
                .font(.title3)
                .foregroundStyle(role.color)
                .symbolEffect(.bounce, value: toast.id)
                .accessibilityHidden(true)

            Text(toast.message)
                .font(.subheadline)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if toast.undo != nil {
                Button(action: onUndo) {
                    if isUndoing {
                        ProgressView()
                    } else {
                        Text("Undo").bold()
                    }
                }
                .disabled(isUndoing)
            } else if toast.retry != nil {
                Button("Retry", action: onRetry)
                    .bold()
            } else {
                Button("Dismiss", systemImage: AppSymbol.close.rawValue, action: onDismiss)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 52)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Host

/// Mounts the toast layer over its content. Applied once, at the root.
private struct DSToastHost: ViewModifier {

    @Environment(\.toasts) private var toasts

    func body(content: Content) -> some View {
        content
            // Top, like a system banner: the tab bar owns the bottom edge
            // and minimises on scroll, so nothing should sit on it.
            .overlay(alignment: .top) {
                if let toast = toasts.current {
                    DSToastView(
                        toast: toast,
                        isUndoing: toasts.isUndoing,
                        onUndo: { Task { await toasts.performUndo() } },
                        onRetry: { Task { await toasts.runRetry() } },
                        onDismiss: { toasts.dismiss() }
                    )
                    .padding(.top, 4)
                    .transition(
                        .move(edge: .top).combined(with: .opacity)
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
