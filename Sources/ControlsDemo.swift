import SwiftUI
import OGPlayerCore
import OGPlayerUI

// Same content as the other demos: Mux VOD + Unified live.
private let controlsVOD = "https://media.ogplayer.tv/tos/master.m3u8"
private let controlsLive = "https://demo.unified-streaming.com/k8s/live/stable/live.isml/.m3u8"

private let controlsBlurb = """
Flip a switch — the running player updates instantly (OGUIConfig is state; no \
reload). Play/pause and the LIVE chip are always visible by SDK design.
"""

/// Control-visibility playground: every built-in control has an on/off
/// switch, plus the
/// master "Hide all controls" and a "Live content" toggle that reloads to a
/// live stream (LIVE chip). `OGUIConfig` is SwiftUI state, so changes apply to
/// the running player instantly.
struct ControlsDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var rotation = DeviceRotation()
    @State private var isFullscreen = false
    @State private var hideAll = false
    @State private var liveContent = false

    @State private var showSeek = true
    @State private var showProgress = true
    @State private var showTime = true
    @State private var showSubtitle = true
    @State private var showAudio = true
    @State private var showQuality = true
    @State private var showSpeed = true
    @State private var showVolume = true
    @State private var showAirPlay = true
    @State private var showFullscreen = true

    private var config: OGUIConfig {
        var c = OGUIConfig()
        if hideAll { c.hideAllControls(); return c }
        c.showSeekButtons = showSeek
        c.showProgressBar = showProgress
        c.showTimeLabels = showTime
        c.showSubtitleButton = showSubtitle
        c.showAudioTrackButton = showAudio
        c.showQualityButton = showQuality
        c.showSpeedButton = showSpeed
        c.showVolumeButton = showVolume
        c.showAirPlayButton = showAirPlay
        c.showFullscreenButton = showFullscreen
        return c
    }

    var body: some View {
        Group {
            if isFullscreen {
                OGPlayerView(player: player, isFullscreen: $isFullscreen, config: config)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    OGPlayerView(player: player, isFullscreen: $isFullscreen, config: config)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    switches
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.background.ignoresSafeArea())
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .onChange(of: isFullscreen) { _, fs in
            OrientationLock.apply(fs ? .landscape : .portrait)
        }
        // Physical rotation → enter/exit fullscreen.
        .onChange(of: rotation.isLandscape) { _, landscape in
            if landscape != isFullscreen { isFullscreen = landscape }
        }
        .onChange(of: liveContent) { _, _ in loadCurrent() }
        .onAppear { rotation.start(); OrientationLock.apply(.all); loadCurrent() }
        .onDisappear { player.pause(); rotation.stop(); OrientationLock.apply(.portrait) }
    }

    private func loadCurrent() {
        let item = liveContent
            ? OGMediaItem(urlString: controlsLive, streamType: .liveDVR,
                          title: "Controls playground — live")
            : OGMediaItem(urlString: controlsVOD, title: "Controls playground",
                   posterUrl: URL(string: "https://media.ogplayer.tv/posters/tos-mech.jpg"))
        if let item { player.load(item, autoplay: false) }
    }

    private var switches: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(controlsBlurb)
                    .font(.system(size: 12))
                    .foregroundStyle(Ink.description)
                    .padding(.bottom, 4)
                row("Live content (shows LIVE chip)", $liveContent, bold: true, dimWhenHidden: false)
                row("Hide all controls", $hideAll, bold: true, dimWhenHidden: false)
                Divider().overlay(Ink.rowBorder).padding(.vertical, 6)
                row("Seek buttons (±10s)", $showSeek)
                row("Progress bar", $showProgress)
                row("Time labels", $showTime)
                row("Subtitle button", $showSubtitle)
                row("Audio-track button", $showAudio)
                row("Quality button", $showQuality)
                row("Speed button", $showSpeed)
                row("Volume button", $showVolume)
                row("AirPlay button", $showAirPlay)
                row("Fullscreen button", $showFullscreen)
            }
            .padding(16)
        }
        .tint(Ink.accent)
    }

    private func row(_ label: String, _ binding: Binding<Bool>,
                     bold: Bool = false, dimWhenHidden: Bool = true) -> some View {
        Toggle(label, isOn: binding)
            .font(.system(size: bold ? 15 : 14, weight: bold ? .semibold : .regular))
            .foregroundStyle((dimWhenHidden && hideAll) ? Ink.description : Ink.title)
            .disabled(dimWhenHidden && hideAll)
    }
}
