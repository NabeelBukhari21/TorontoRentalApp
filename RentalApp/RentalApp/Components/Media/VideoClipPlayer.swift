//
//  VideoClipPlayer.swift
//  RentalApp (Purrperty)
//
//  Media — Silent, decorative video clips (mascot animations, feature
//  teasers). Not a media player: no controls, no audio, no Now Playing.
//
//  Two pieces, so screens never touch AVFoundation directly:
//
//  • `VideoClipPlayer` — owns the AVPlayer, plays a bundled clip once
//    and reports when it has finished, can hold any frame.
//  • `VideoClipSurface` — renders it through an AVPlayerLayer (hardware
//    decoded; far cheaper than decoding frames into SwiftUI images).
//
//  Clips must not interrupt the user's music: the audio session is set
//  to `.ambient` + mix-with-others the first time a clip player is made,
//  and players are muted. Bundled clips carry no audio track anyway.
//

import AVFoundation
import OSLog
import SwiftUI
import UIKit

@MainActor
@Observable
final class VideoClipPlayer {

    /// The underlying player, for `VideoClipSurface` only.
    let player: AVPlayer
    /// The item, so views can observe its end-of-playback notification.
    let item: AVPlayerItem?

    /// True once a play-through has reached the end. Reset by `playFromStart`.
    private(set) var hasFinished = false

    /// Whether the resource was found. When it isn't, views should show
    /// their fallback instead of an empty surface.
    var isAvailable: Bool { item != nil }

    init(resource: String, withExtension ext: String = "mp4", bundle: Bundle = .main) {
        Self.configureAudioSessionOnce()

        if let url = bundle.url(forResource: resource, withExtension: ext) {
            let item = AVPlayerItem(url: url)
            self.item = item
            self.player = AVPlayer(playerItem: item)
        } else {
            AppLog.app.error("Missing bundled clip \(resource, privacy: .public).\(ext, privacy: .public)")
            self.item = nil
            self.player = AVPlayer()
        }

        player.isMuted = true
        player.actionAtItemEnd = .pause
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
    }

    // MARK: Playback

    /// Rewinds to the first frame and plays through once.
    func playFromStart() {
        guard isAvailable else { return }
        hasFinished = false
        player.pause()
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }

    /// Stops and shows `time` (e.g. the final pose, for Reduce Motion).
    func hold(at time: CMTime) {
        guard isAvailable else { return }
        player.pause()
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        hasFinished = true
    }

    /// Stops and rewinds, so the next appearance starts from the top.
    func reset() {
        guard isAvailable else { return }
        player.pause()
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        hasFinished = false
    }

    /// Call when the item reports it played to the end.
    func didPlayToEnd() {
        hasFinished = true
    }

    // MARK: Audio Session

    private static var didConfigureAudioSession = false

    /// Decorative clips must never stop the user's music or podcast.
    private static func configureAudioSessionOnce() {
        guard !didConfigureAudioSession else { return }
        didConfigureAudioSession = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        } catch {
            AppLog.app.error("Audio session setup failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Surface

/// Draws a `VideoClipPlayer`. Aspect-fit, transparent around the video.
struct VideoClipSurface: UIViewRepresentable {

    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    /// A view whose backing layer is the player layer, so it resizes with
    /// Auto Layout and SwiftUI without manual frame syncing.
    final class PlayerLayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
