import SwiftUI
import OGPlayerCore
import OGPlayerUI
import OGPlayerAdsIMAtvOS

private let tos = "https://media.ogplayer.tv/tos/master.m3u8"
private let liveURL = "https://demo.unified-streaming.com/k8s/live/stable/live.isml/.m3u8"
private let vmapPreMidPost =
    "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/vmap_ad_samples"
    + "&sz=640x480&cust_params=sample_ar%3Dpremidpost&ciu_szs=300x250&gdfp_req=1&ad_rule=1"
    + "&output=vmap&unviewed_position_start=1&env=vp&impl=s&cmsid=496&vid=short_onecue&correlator="
// Public multi-DRM test vector (FairPlay flavour) and its published token.
private let fairPlayCertificateURL = "https://tools.axinom.com/FPScert/fairplay.cer"
private let fairPlayLicenseURL = "https://drm-fairplay-licensing.axprod.net/AcquireLicense"
private let drmToken =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ewogICJ2ZXJzaW9uIjogMSwKICAiY29tX2tleV9pZCI6ICI2OWU1NDA4OC1lOWUwLTQ1MzAtOGMxYS0xZWI2ZGNkMGQxNGUiLAogICJtZXNzYWdlIjogewogICAgInR5cGUiOiAiZW50aXRsZW1lbnRfbWVzc2FnZSIsCiAgICAidmVyc2lvbiI6IDIsCiAgICAibGljZW5zZSI6IHsKICAgICAgImFsbG93X3BlcnNpc3RlbmNlIjogdHJ1ZQogICAgfSwKICAgICJjb250ZW50X2tleXNfc291cmNlIjogewogICAgICAiaW5saW5lIjogWwogICAgICAgIHsKICAgICAgICAgICJpZCI6ICIzMDJmODBkZC00MTFlLTQ4ODYtYmNhNS1iYjFmODAxOGEwMjQiLAogICAgICAgICAgImVuY3J5cHRlZF9rZXkiOiAicm9LQWcwdDdKaTFpNDNmd3YremZ0UT09IiwKICAgICAgICAgICJ1c2FnZV9wb2xpY3kiOiAiUG9saWN5IEEiCiAgICAgICAgfQogICAgICBdCiAgICB9LAogICAgImNvbnRlbnRfa2V5X3VzYWdlX3BvbGljaWVzIjogWwogICAgICB7CiAgICAgICAgIm5hbWUiOiAiUG9saWN5IEEiLAogICAgICAgICJwbGF5cmVhZHkiOiB7CiAgICAgICAgICAibWluX2RldmljZV9zZWN1cml0eV9sZXZlbCI6IDE1MCwKICAgICAgICAgICJwbGF5X2VuYWJsZXJzIjogWwogICAgICAgICAgICAiNzg2NjI3RDgtQzJBNi00NEJFLThGODgtMDhBRTI1NUIwMUE3IgogICAgICAgICAgXQogICAgICAgIH0KICAgICAgfQogICAgXQogIH0KfQ._NfhLVY7S6k8TJDWPeMPhUawhympnrk6WAZHOVjER6M"

/// One full-screen player per scenario. On tvOS the SDK's chrome is the
/// remote chrome — nothing to configure beyond the scenario itself; the
/// Now Playing mirror is the one opt-in (`mediaSessionEnabled`).
struct TvPlayerScreen: View {
    let route: String
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @State private var loggers: [AnyObject] = []
    @State private var loaded = false

    private var config: OGUIConfig {
        var c = OGUIConfig()
        c.mediaSessionEnabled = true
        // Test hook: SIMCTL_CHILD_OG_CONTROLS_TIMEOUT=<s>
        // keeps the chrome up longer for screenshots and slow UI-test trees.
        if let t = ProcessInfo.processInfo.environment["OG_CONTROLS_TIMEOUT"], let secs = Double(t) {
            c.controlsTimeout = secs
        }
        if route == "customactions" {
            c.customActions = (1...2).map { i in
                CustomAction(icon: Image(systemName: i == 1 ? "heart" : "square.and.arrow.up"),
                             accessibilityLabel: "Custom action \(i)") { log.add("custom action \(i)") }
            }
        }
        return c
    }

    var body: some View {
        OGPlayerView(player: player, config: config)
            .ignoresSafeArea()
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if route == "ads" { player.adsProvider = IMAAdsProvider() }
                loggers = [attachEventLogging(player, to: log, includeProgress: false)]
                load()
            }
    }

    private func load() {
        switch route {
        case "live":
            if let item = OGMediaItem(urlString: liveURL, streamType: .liveDVR, title: "Live & DVR") {
                player.load(item)
            }
        case "drm":
            let drm = FairPlayConfig(
                certificateURLString: fairPlayCertificateURL,
                licenseServerURLString: fairPlayLicenseURL,
                licenseHeaders: ["X-AxDRM-Message": drmToken],
                requestFormat: .binary)
            if let drm,
               let item = OGMediaItem(
                   urlString: "https://media.axprod.net/TestVectors/Cmaf/protected_1080p_h264_cbcs/manifest.m3u8",
                   title: "Multi-DRM demo (encrypted)", drm: drm) {
                player.load(item)
            }
        case "tracks":
            var subs = [("en", "English"), ("de", "Deutsch")].compactMap { code, label in
                Bundle.main.url(forResource: "tears_of_steel_\(code)", withExtension: "vtt").map {
                    SubtitleSource(url: $0, language: code, label: label, isDefault: code == "en")
                }
            }
            // The phone demo's positioned file: line / position / align / size cues.
            if let url = Bundle.main.url(forResource: "test_cue_settings", withExtension: "vtt") {
                subs.append(SubtitleSource(url: url, language: "en", label: "Positioned (line/position cues)"))
            }
            if let item = OGMediaItem(urlString: tos, title: "Tears of Steel — sideloaded VTT", subtitles: subs) {
                player.load(item)
            }
        case "playlist":
            player.loadPlaylist(["Part 1", "Part 2", "Part 3"].compactMap { OGMediaItem(urlString: tos, title: $0) })
        case "ads":
            if let item = OGMediaItem(urlString: "https://media.ogplayer.tv/tos-clip-60s.mp4",
                                      title: "Ads on TV", adBreaks: AdTagConfig(adTagURI: vmapPreMidPost)) {
                player.load(item)
            }
        case "ratings":
            if let item = OGMediaItem(urlString: tos, title: "Content ratings",
                                      contentRatings: [.age(.twelve), .descriptor(.violence), .descriptor(.fear)]) {
                player.load(item)
            }
        case "errormessages":
            if let item = OGMediaItem(urlString: "https://media.ogplayer.tv/does-not-exist/master.m3u8", title: "Error") {
                player.load(item)
            }
        default:
            if let item = OGMediaItem(urlString: tos, title: "Tears of Steel") { player.load(item) }
        }
    }
}
