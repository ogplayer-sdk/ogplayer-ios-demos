import SwiftUI
import OGPlayerCore
import OGPlayerUI
import OGPlayerAdsIMA

/// Playlist & "Up next".
/// Three short clips queue and auto-advance; a countdown card appears in the
/// lead window before each item ends (tap it to skip immediately). Every knob
/// has a mode chip: the lead time, the card's text template, its colors and
/// font — or no card at all (silent advance). The card is deliberately
/// config-only: no custom-view slot.
// Google's public IMA sample tags — a skippable preroll (VAST) and a
// postroll-only ad rule (VMAP).
private let skippablePreroll =
    "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/"
    + "single_preroll_skippable&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1"
    + "&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator="
private let postrollOnly =
    "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/vmap_ad_samples"
    + "&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1&ad_rule=1&output=vmap"
    + "&unviewed_position_start=1&env=vp&impl=s&cmsid=496&vid=short_onecue"
    + "&cust_params=sample_ar%3Dpostonly&correlator="

/// Ads are PER ITEM: with `withAds`, clip 1 opens with a skippable preroll,
/// clip 2 ends with a postroll (played BEFORE the queue advances), clip 3
/// stays ad-free.
private func playlistItems(withAds: Bool) -> [OGMediaItem] {
    [
        ("w169-01", "The old church", skippablePreroll),
        ("w169-02", "Crossing the bridge", postrollOnly),
        ("w169-03", "The machine waits", nil),
    ].compactMap { (file: String, title: String, adTag: String?) in
        OGMediaItem(
            urlString: "https://media.ogplayer.tv/shorts/v3/\(file).mp4",
            streamType: .vod,
            title: title,
            posterUrl: URL(string: "https://media.ogplayer.tv/shorts/v3/\(file).jpg"),
            adBreaks: withAds ? adTag.map { AdTagConfig(adTagURI: $0) } : nil
        )
    }
}

/// Playlist demo: just the queue lifecycle — no analytics noise.
private final class PlaylistLogger: PlaybackListener {
    let log: EventLogState
    init(log: EventLogState) { self.log = log }

    func onPlaylistItemChanged(index: Int, item: OGMediaItem) {
        log.add("onPlaylistItemChanged: #\(index) · \(item.title ?? "?")")
    }

    func onPlaylistItemSkipped(fromIndex: Int, toIndex: Int) {
        log.add("onPlaylistItemSkipped: #\(fromIndex) → #\(toIndex)")
    }

    func onPlaybackCompleted() { log.add("onPlaybackCompleted") }

    func onError(_ error: OGPlayerError) { log.add("onError: \(error)") }
}

struct PlaylistDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @StateObject private var rotation = DeviceRotation()
    @State private var isFullscreen = false
    @State private var logger: PlaylistLogger?
    // Retain the ad logger for the lifetime of the screen.
    @State private var adLogger: EventLogger?

    // 0=default, 1=short lead, 2=custom text, 3=branded, 4=hidden, 5=with ads
    // (OG_PLAYLIST_MODE launch-env selects a mode for headless testing.)
    @State private var mode =
        Int(ProcessInfo.processInfo.environment["OG_PLAYLIST_MODE"] ?? "0") ?? 0

    private var config: OGUIConfig {
        var c = OGUIConfig()
        switch mode {
        case 1:
            c.upNextLeadSeconds = 5
        case 2:
            c.upNextText = "{title} starts in {seconds}s…"
        case 3:
            c.upNextText = "Up next · {title} · {seconds}"
            c.upNextBackgroundColor = Ink.accent.opacity(0.9)
            c.upNextTextFont = .system(size: 13, design: .serif)
            c.upNextTextColor = Color(red: 0.075, green: 0.075, blue: 0.075)
        case 4:
            c.showUpNext = false
        default:
            break
        }
        return c
    }

    var body: some View {
        Group {
            if isFullscreen {
                // Fullscreen means the player and nothing else.
                OGPlayerView(player: player, isFullscreen: $isFullscreen, config: config)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                embedded
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
        .onChange(of: mode) { _, _ in reload() }
        .onAppear {
            rotation.start()
            OrientationLock.apply(.all)
            player.adsProvider = IMAAdsProvider()
            let logger = PlaylistLogger(log: log)
            self.logger = logger
            player.addListener(logger)
            adLogger = attachAdEventLogging(player, to: log)
            reload()
        }
        .onDisappear {
            player.pause()
            rotation.stop()
            OrientationLock.apply(.portrait)   // return to the list in portrait
        }
    }

    private var embedded: some View {
        VStack(spacing: 0) {
            OGPlayerView(player: player, isFullscreen: $isFullscreen, config: config)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            // Five modes don't fit one row on phones — two rows, like the
            // Android demo's FlowRow wraps them.
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    chip("Default", selected: mode == 0) { mode = 0 }
                    chip("Lead 5s", selected: mode == 1) { mode = 1 }
                    chip("Custom text", selected: mode == 2) { mode = 2 }
                }
                HStack(spacing: 8) {
                    chip("Branded style", selected: mode == 3) { mode = 3 }
                    chip("Hidden", selected: mode == 4) { mode = 4 }
                    chip("With ads", selected: mode == 5) { mode = 5 }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            Text(explainer)
                .font(.footnote)
                .foregroundColor(Ink.description)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            EventLogView(log: log)
        }
    }

    private var explainer: String {
        switch mode {
        case 1:
            return "upNextLeadSeconds = 5 — the card appears 5 seconds before "
                + "the end instead of the default 10."
        case 2:
            return "upNextText = \"{title} starts in {seconds}s…\" — your copy, "
                + "any language; {seconds} and {title} are substituted."
        case 3:
            return "upNextBackgroundColor / upNextTextFont / upNextTextColor — "
                + "brand the card: accent background, serif font, dark text."
        case 4:
            return "showUpNext = false — no card at all; the playlist still "
                + "auto-advances silently."
        case 5:
            return "Ads are per item (adBreaks on each OGMediaItem): clip 1 "
                + "opens with a skippable preroll, clip 2 ends with a postroll "
                + "that plays before the queue advances, clip 3 is ad-free."
        default:
            return "Three 14-second clips auto-advance; the \"Up next\" card "
                + "counts down during the last 10 seconds — tap it to skip "
                + "immediately. Changing modes reloads the playlist."
        }
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.black : Ink.title)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(selected ? Ink.accent : Ink.rowSurface, in: Capsule())
                .overlay(Capsule().stroke(Ink.rowBorder, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private func reload() {
        log.add(mode == 5
            ? "— loading playlist with per-item IMA tags —"
            : "— loading playlist (3 clips, 14s each) —")
        player.loadPlaylist(playlistItems(withAds: mode == 5))
    }
}
