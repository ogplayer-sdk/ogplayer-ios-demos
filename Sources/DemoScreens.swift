import SwiftUI
import OGPlayerCore
import OGPlayerUI

private let muxVOD = "https://media.ogplayer.tv/tos/master.m3u8"
// Storyboard VTT: preview thumbnails appear while scrubbing (same track as
// storyboard sprites).
private let muxStoryboardVTT =
    "https://media.ogplayer.tv/tos/storyboard/storyboard.vtt"
private let liveURL = "https://demo.unified-streaming.com/k8s/live/stable/live.isml/.m3u8"

private let orientationBlurb = """
Embedded 16:9 player.

Tap the fullscreen button: the page rotates into landscape fullscreen. Tap it \
again (icon changes to “collapse”) and the player returns here, back in \
portrait. Rotating the device physically does the same.
"""

/// Orientation & fullscreen:
/// an embedded 16:9 player in a portrait page. Tapping the SDK's fullscreen
/// button rotates into landscape fullscreen and back to embedded portrait
/// (icon flips to "collapse"); rotating the device physically does the same.
struct OrientationDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var rotation = DeviceRotation()
    @State private var isFullscreen = false

    var body: some View {
        Group {
            if isFullscreen {
                OGPlayerView(player: player, isFullscreen: $isFullscreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    OGPlayerView(player: player, isFullscreen: $isFullscreen)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    Text(orientationBlurb)
                        .font(.system(size: 14))
                        .foregroundStyle(Ink.description)
                        .padding(16)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.background.ignoresSafeArea())
        // Hide the app chrome (nav back button, status bar, home indicator)
        // while in fullscreen.
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        // Fullscreen state → interface orientation (lock landscape / portrait).
        .onChange(of: isFullscreen) { _, fs in
            OrientationLock.apply(fs ? .landscape : .portrait)
        }
        // Physical rotation → enter/exit fullscreen (autoFullscreenOnRotate).
        .onChange(of: rotation.isLandscape) { _, landscape in
            if landscape != isFullscreen { isFullscreen = landscape }
        }
        .onAppear {
            rotation.start()
            OrientationLock.apply(.all)
            if let item = OGMediaItem(urlString: muxVOD, title: "Orientation demo",
                   posterUrl: URL(string: "https://media.ogplayer.tv/posters/tos-mech.jpg"),
                                      thumbnailTrack: URL(string: muxStoryboardVTT)) {
                player.load(item, autoplay: false)
            }
        }
        .onDisappear {
            player.pause()
            rotation.stop()
            OrientationLock.apply(.portrait)   // return to the list in portrait
        }
    }
}

/// Live showcase, both flavors: LIVE (locked
/// to the edge, no seeking) and LIVE_DVR (seekable window). Scrub behind the
/// DVR edge; tap the LIVE chip or \u{201C}To live edge\u{201D} (seekToLiveEdge()) to jump back.
struct LivePlayerDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @StateObject private var rotation = DeviceRotation()
    @State private var dvr = false
    @State private var isFullscreen = false
    @State private var logger: EventLogger?

    /// Live demo config: no AirPlay button (not relevant to this scenario).
    private var liveConfig: OGUIConfig {
        var c = OGUIConfig()
        c.showAirPlayButton = false
        return c
    }

    var body: some View {
        Group {
            if isFullscreen {
                OGPlayerView(player: player, isFullscreen: $isFullscreen, config: liveConfig)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    OGPlayerView(player: player, isFullscreen: $isFullscreen, config: liveConfig)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("", selection: $dvr) {
                            Text("Live (locked to edge)").tag(false)
                            Text("Live DVR (seekable)").tag(true)
                        }
                        .pickerStyle(.segmented)
                        if dvr {
                            // The imperative twin of tapping the LIVE chip in
                            // the chrome — hosts can jump back programmatically.
                            Button("To live edge") { player.seekToLiveEdge() }
                                .font(.system(size: 13, weight: .semibold))
                                .buttonStyle(.bordered)
                                .tint(Ink.accent)
                        }
                        Text(dvr
                             ? "LIVE_DVR — scrub behind the edge, then tap the LIVE chip or \u{201C}To live edge\u{201D} (seekToLiveEdge()) to jump back. The label reads LIVE at the edge, else a −offset; the thumb creeps toward live as you watch behind it."
                             : "LIVE — no seeking: no progress bar, the chip stays at the edge.")
                            .font(.system(size: 12)).foregroundStyle(Ink.description)
                    }
                    .padding(16)
                    // Terminal-style analytics/callback log.
                    EventLogView(log: log)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.background.ignoresSafeArea())
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .onChange(of: isFullscreen) { _, fs in OrientationLock.apply(fs ? .landscape : .portrait) }
        // Physical rotation → enter/exit fullscreen.
        .onChange(of: rotation.isLandscape) { _, landscape in
            if landscape != isFullscreen { isFullscreen = landscape }
        }
        .onChange(of: dvr) { _, _ in load() }
        .onAppear {
            rotation.start()
            OrientationLock.apply(.all)
            if logger == nil { logger = attachEventLogging(player, to: log) }
            load()
        }
        .onDisappear { player.pause(); rotation.stop(); OrientationLock.apply(.portrait) }
    }

    private func load() {
        let type: StreamType = dvr ? .liveDVR : .live
        log.add("— loading \(dvr ? "LIVE_DVR" : "LIVE") \(liveURL) —")
        let item = OGMediaItem(urlString: liveURL,
                               streamType: type,
                               title: dvr ? "Live DVR demo" : "Live demo")
        // Live starts immediately — no reason to sit paused at the edge.
        if let item { player.load(item, autoplay: true) }
    }
}
