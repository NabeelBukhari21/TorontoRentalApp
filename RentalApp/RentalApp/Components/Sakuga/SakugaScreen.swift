//
//  SakugaScreen.swift
//  RentalApp (Purrperty)
//
//  Components/Sakuga — The app's side of it: the effects layer a screen or
//  sheet carries, hints that open over everything, and small pieces that
//  add the effects to controls the app already has.
//

import SwiftUI

// MARK: - Screen

private struct SakugaScreen: ViewModifier {
    @State private var stage = SakugaStage()

    func body(content: Content) -> some View {
        content
            .environment(\.sakuga, stage)
            .toggleStyle(SakugaToggleStyle())
            .overlay { SakugaHintLayer(stage: stage) }
            .overlay { SakugaLayer(stage: stage, followsScreen: true).ignoresSafeArea() }
    }
}

extension View {
    /// Gives a screen its own effects layer. A sheet needs one too: the
    /// screen's sits underneath it.
    func sakugaScreen() -> some View { modifier(SakugaScreen()) }
}

// MARK: - Toggle Style

struct SakugaToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 8)
            SakugaToggle(isOn: configuration.$isOn, scale: 0.6)
        }
    }
}

// MARK: - Typing

private struct SakugaKeys: ViewModifier {
    let text: String
    let font: CGFloat
    let leading: CGFloat
    @State private var frame: CGRect = .zero
    @State private var squeeze: CGFloat = 1
    @Environment(\.sakuga) private var stage
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: squeeze, y: 2 - squeeze)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .onChange(of: text) { old, new in
                // Typing only: not autofill, paste or a draft arriving.
                guard !reduceMotion, abs(new.count - old.count) == 1, let stage else { return }
                let width = (new as NSString).size(withAttributes: [.font: UIFont(name: "Fredoka", size: font) ?? .systemFont(ofSize: font)]).width
                let x = min(frame.minX + leading + width, frame.maxX - 16)
                squeeze = 0.988
                withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) { squeeze = 1 }
                stage.puff(x, frame.midY + 8, n: 2, size: .random(in: 3.5...5.5), vx: .random(in: -10...10), vy: -22, life: 0.4)
                if Int.random(in: 0..<3) == 0 { stage.shards(x, frame.midY + 6, n: 2, speed: 110, size: 2.6, life: 0.5) }
            }
    }
}

extension View {
    /// Kicks up dust at the caret as `text` is typed.
    func sakugaKeys(_ text: String, font: CGFloat = 17, leading: CGFloat = 52) -> some View {
        modifier(SakugaKeys(text: text, font: font, leading: leading))
    }
}

// MARK: - Tap

private struct SakugaTap: ViewModifier {
    let isOn: Bool
    @State private var frame: CGRect = .zero
    @Environment(\.sakuga) private var stage

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .simultaneousGesture(TapGesture().onEnded {
                guard isOn, let stage else { return }
                stage.ticks(frame.maxX - 10, frame.minY - 2, n: 3, r: 5, len: 16, dir: -1.05, life: 0.5, fan: 0.36)
                stage.ticks(frame.minX + 10, frame.minY - 2, n: 3, r: 5, len: 16, dir: -2.1, life: 0.5, fan: 0.36)
                stage.puff(frame.minX - 2, frame.maxY - 6, n: 3, size: 7, vx: -22, vy: -8, life: 0.6)
                stage.puff(frame.maxX + 2, frame.maxY - 6, n: 3, size: 7, vx: 22, vy: -8, life: 0.6)
            })
    }
}

extension View {
    /// Whiskers and a little dust when tapped: the light reaction.
    func sakugaTap(_ isOn: Bool = true) -> some View { modifier(SakugaTap(isOn: isOn)) }
}

// MARK: - Hints

/// A "?" that explains something, in a speech bubble.
struct SakugaHint: View {
    let text: String
    @State private var frame: CGRect = .zero
    @State private var id = UUID()
    @Environment(\.sakuga) private var stage
    @Environment(\.feedback) private var feedback

    var body: some View {
        Button {
            feedback?.play(.tap)
            if stage?.hint?.id == id { stage?.hint = nil } else { stage?.hint = .init(id: id, text: text, anchor: frame) }
        } label: {
            Text(verbatim: "?")
                .font(DS.Typography.brand(15, weight: .bold, relativeTo: .footnote))
                .foregroundStyle(SakugaInk.fill)
                .frame(width: 26, height: 26)
                .background(Circle().fill(SakugaInk.cherry).strokeBorder(SakugaInk.ink, lineWidth: 2))
                .background(Circle().fill(SakugaInk.shade).offset(x: 2, y: 2))
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .buttonStyle(SquishStyle(scale: 0.8))
        .accessibilityLabel("Explain")
        .accessibilityHint(text)
    }
}

/// Draws the open hint over the whole screen; a tap anywhere closes it.
private struct SakugaHintLayer: View {
    let stage: SakugaStage
    @State private var origin: CGPoint = .zero
    @State private var isIn = false

    var body: some View {
        GeometryReader { proxy in
            if let hint = stage.hint {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { stage.hint = nil }
                let x = min(max(hint.anchor.midX - origin.x, 146), proxy.size.width - 152)
                let above = hint.anchor.minY - origin.y > 170
                Text(hint.text)
                    .font(DS.Typography.brand(.subheadline))
                    .foregroundStyle(SakugaInk.ink)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(width: 270)
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SakugaInk.fill).strokeBorder(SakugaInk.ink, lineWidth: 3))
                    .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(SakugaInk.shade).offset(x: 5, y: 6))
                    .scaleEffect(isIn ? 1 : 0.05, anchor: above ? .bottom : .top)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxHeight: 400, alignment: above ? .bottom : .top)
                    .frame(height: 400, alignment: above ? .bottom : .top)
                    .position(x: x, y: above ? hint.anchor.minY - origin.y - 210 : hint.anchor.maxY - origin.y + 210)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.45)) { isIn = true }
                        let a = hint.anchor
                        stage.later(120) {
                            stage.ring(a.midX, a.midY, rx: 22, ry: 6, life: 0.5, w: 3)
                            stage.puff(x + origin.x - 130, a.minY - 40, n: 4, size: 8, vx: -14, vy: -10)
                            stage.pawPuff(x + origin.x + 136, a.minY - 30, size: 10, rot: 0.3, vx: 14, vy: -6)
                            stage.sfx("PSST!", x + origin.x - 70, a.minY - (above ? 150 : -150), size: 28, rot: -0.1, life: 0.85, style: .hollow)
                        }
                    }
                    .onDisappear { isIn = false }
                    .id(hint.id)
            }
        }
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { origin = $0 }
    }
}

// MARK: - Credit

/// The licence the effects came with, for Settings.
struct SakugaCredit: View {
    private static let licence = Bundle.main.url(forResource: "SakugaVFX-LICENSE", withExtension: "txt").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

    var body: some View {
        DisclosureGroup("Impact effects adapted from Sakuga VFX") {
            Text(Self.licence)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(DS.Typography.caption)
        .foregroundStyle(DS.Colors.textSecondary)
        .tint(DS.Colors.brandInk)
    }
}
