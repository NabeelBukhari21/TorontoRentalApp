//
//  MascotFace.swift
//  RentalApp
//
//  Mascot — Expression tiles: the cat's face on a soft rounded tile, for
//  small places where a full-body mascot would be too much (toasts, the AI
//  orb, list badges, avatars).
//
//  The tiles are cut at their native ~110–130 px, so they stay crisp up to
//  about 40 pt on a 3× display. `MascotFaceView` clamps to that; for anything
//  larger, use `MascotView`.
//

import SwiftUI

enum MascotFace: String, CaseIterable, Sendable {
    case happy
    case wink
    case laugh
    case curious
    case sleepy
    case surprised
    case sassy
    case angry
    case love
    case thinking
    case excited
    case sad

    var assetName: String {
        "MascotFace" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// Largest size (points) the tile is drawn at before it would soften.
    static let maxCrispSize: CGFloat = 44
}

struct MascotFaceView: View {

    let face: MascotFace
    var size: CGFloat = 32
    /// A small pop whenever the face changes.
    var animatesChanges: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let side = min(size, MascotFace.maxCrispSize)
        Image(face.assetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: side, height: side)
            .id(face)
            .transition(
                reduceMotion || !animatesChanges
                    ? .opacity
                    : .scale(scale: 0.6).combined(with: .opacity)
            )
            .animation(.spring(response: 0.32, dampingFraction: 0.6), value: face)
            .accessibilityHidden(true)
    }
}

// MARK: - Previews

#Preview("Faces") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
        ForEach(MascotFace.allCases, id: \.self) { face in
            VStack(spacing: 6) {
                MascotFaceView(face: face, size: 44)
                Text(face.rawValue).font(.caption2)
            }
        }
    }
    .padding()
}
