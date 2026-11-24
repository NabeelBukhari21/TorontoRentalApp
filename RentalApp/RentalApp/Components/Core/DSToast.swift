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

    @State private var frame: CGRect = .zero
    @State private var slide: CGFloat = 0
    @State private var smear: CGFloat = 1
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Streaks in and skids to a stop. Failures just appear: they're read,
    /// not enjoyed.
    private func land() {
        guard toast.style == .success, !reduceMotion else { return }
        slide = -440
        smear = 1.6
        withAnimation(.spring(response: 0.42, dampingFraction: 0.66)) { slide = 0 }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.42).delay(0.2)) { smear = 1 }
        stage?.later(250) {
            feedback?.play(.stamp)
            let c = frame
            stage?.lines(c.minX + 10, c.midY, n: 9, dir: .pi, len: 60, spread: 18, life: 0.4)
            for u in [0.08, 0.22, 0.38] { stage?.puff(c.minX + c.width * u, c.maxY + 4, n: 4, size: .random(in: 7...11), vx: -.random(in: 10...30), vy: -8, life: .random(in: 0.7...1)) }
            stage?.pawPuff(c.maxX - 16, c.maxY + 6, size: 10, rot: 0.3, vx: 14, life: 0.8)
            stage?.shards(c.minX + 16, c.midY + 12, n: 4, size: 4, dir: .pi + 0.5, arc: 1.6)
            stage?.sfx("SKRRT!", c.midX - 34, c.maxY + 30, size: 34, rot: -0.1, life: 0.85, style: .dotted)
        }
    }

    private var role: StatusRole {
        switch toast.style {
        case .success: .positive
        case .failure: .critical
        case .info:    .informational
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Purr acts out the result; the message carries the meaning.
            PurrMascot(mood: toast.mood ?? toast.style.mood, size: 46, isInteractive: false)
                .padding(.vertical, -6)
                .padding(.leading, -8)
                .id(toast.id)

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
        .background(Capsule().fill(SakugaInk.fill).strokeBorder(SakugaInk.ink, lineWidth: 3))
        .background(Capsule().fill(SakugaInk.shade).offset(x: 4, y: 5))
        // Ink on paper in both themes.
        .environment(\.colorScheme, .light)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .scaleEffect(x: smear, y: 1 / sqrt(smear), anchor: .trailing)
        .offset(x: slide)
        .padding(.horizontal)
        .onAppear(perform: land)
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
                        .asymmetric(insertion: .opacity, removal: .scale(scale: 0.2).combined(with: .opacity))
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
    /// Purr's reaction to each outcome, when the toast doesn't name one.
    var mood: PurrMood {
        switch self {
        case .success: .success
        case .failure: .error
        case .info:    .newNotification
        }
    }
}
