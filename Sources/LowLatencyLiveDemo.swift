import SwiftUI
import OGPlayerCore
import OGPlayerUI

/// Public LL-HLS test stream: ~1 s fMP4 parts (EXT-X-PART), blocking playlist
/// reload and a PART-HOLD-BACK in EXT-X-SERVER-CONTROL, with a UTC clock
/// burned into the picture.
private let lowLatencyURL = "https://stream.mux.com/v69RSHhFelSm4701snP22dYz2jICy4E4FUyk02rW4gxRM.m3u8"

private let lowLatencyBlurb = """
Nothing to configure — the same item as any live stream. The engine holds the \
playlist's PART-HOLD-BACK and plays a few seconds behind real time; part of that \
delay is the stream's own, before it reaches the player. This test stream keeps \
only about 20 s of history, so it plays as plain live: no rewind bar. Pause, and \
\u{201C}To live edge\u{201D} (seekToLiveEdge()) brings the delay back down. The clock \
painted into the picture comes from the stream's encoder and can differ from the \
stream's time stamps by a second or two.
"""

private let lowLatencyCredit =
    "Content: Big Buck Bunny — (CC) Blender Foundation, via Mux's public low-latency test stream"

/// Low-latency HLS: the same `OGMediaItem` as any live stream — no flag, no
/// tuning. The test stream keeps only ~20 s of history, so it plays as plain
/// `.live`: the LIVE chip, no rewind bar, no seek buttons. The readout under
/// the player is one number — how far the playhead's program date-time
/// (`liveInfo.playheadDate`, i.e. `AVPlayerItem.currentDate()`) runs behind
/// this device's clock.
struct LowLatencyLiveDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @State private var isFullscreen = false
    @State private var logger: EventLogger?
    /// Seconds the playhead runs behind real time (device clock vs. the
    /// playhead's EXT-X-PROGRAM-DATE-TIME), sampled on each `liveInfo` update.
    @State private var behind: TimeInterval?

    /// One audio rendition and no subtitles: the buttons that would open empty
    /// menus are hidden, speed goes too (no rate changes at the live edge),
    /// AirPlay is not part of this scenario. The quality ladder stays.
    private var config: OGUIConfig {
        var c = OGUIConfig()
        c.showAirPlayButton = false
        c.showSubtitleButton = false
        c.showAudioTrackButton = false
        c.showSpeedButton = false
        return c
    }

    var body: some View {
        // ONE OGPlayerView resized by the fullscreen state (as in AdsDemo):
        // swapping between two instances on the binding left the embedded
        // page on screen when hand rotation flipped it.
        GeometryReader { geo in
            VStack(spacing: 0) {
                OGPlayerView(player: player, isFullscreen: $isFullscreen, config: config,
                             autoFullscreenOnRotate: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: isFullscreen ? geo.size.height : geo.size.width * 9 / 16)
                if !isFullscreen {
                    VStack(alignment: .leading, spacing: 10) {
                        readout
                        // The imperative twin of tapping the LIVE chip in the chrome.
                        Button("To live edge") { player.seekToLiveEdge() }
                            .font(.system(size: 13, weight: .semibold))
                            .buttonStyle(.bordered)
                            .tint(Ink.accent)
                        Text(lowLatencyBlurb)
                            .font(.system(size: 12)).foregroundStyle(Ink.description)
                        Text(lowLatencyCredit)
                            .font(.system(size: 11)).foregroundStyle(Ink.description.opacity(0.8))
                    }
                    .padding(16)
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
        .onAppear {
            OrientationLock.apply(.all)
            if logger == nil { logger = attachEventLogging(player, to: log, includeProgress: false) }
            if player.currentItem == nil,
               // Plain LIVE: a ~20 s window is no DVR — the chrome shows the
               // LIVE chip and no rewind bar.
               let item = OGMediaItem(urlString: lowLatencyURL, streamType: .live,
                                      title: "Low-latency live") {
                log.add("— loading LIVE low-latency HLS —")
                player.load(item, autoplay: true)
            }
        }
        .onReceive(player.$liveInfo) { info in
            behind = info?.playheadDate.map { max(0, Date().timeIntervalSince($0)) }
        }
        .onDisappear { player.pause(); OrientationLock.apply(.portrait) }
    }

    /// `liveInfo` refreshes twice a second; the delay is taken the moment
    /// each update lands, so the reading is not aged by the render cadence.
    private var readout: some View {
        Text("Behind real time: " + (behind.map { String(format: "%.1f s", $0) } ?? "—"))
            .font(.system(size: 17, weight: .semibold, design: .monospaced))
            .foregroundStyle(Ink.title)
    }
}
