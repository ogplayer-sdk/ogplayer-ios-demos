import SwiftUI
import OGPlayerCore
import OGPlayerUI
import OGPlayerAdsIMA

/// Client-side Google IMA ads.
/// Pick a scenario (skippable preroll, or a VMAP pre/mid/post pod schedule);
/// the player loads the content with the ad tag and streams every ad callback
/// into the green event log. IMA renders its own skip / "Learn More" UI.
struct AdsDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @State private var isFullscreen = false
    @State private var scenario: Scenario = .preroll
    // Retain the loggers for the lifetime of the screen.
    @State private var loggers: [EventLogger] = []

    enum Scenario: String, CaseIterable, Identifiable {
        case preroll = "Skippable preroll"
        case preMidPost = "Pre + mid + post"
        case midPod3 = "Mid-roll pod (3 ads)"
        case midPod5 = "Long pod (5 ads)"
        case broken = "Broken tag (error)"
        var id: String { rawValue }
        var tag: String {
            switch self {
            case .preroll:
                return "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/"
                    + "single_preroll_skippable&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1"
                    + "&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator="
            case .preMidPost: return vmapBase + "&cust_params=sample_ar%3Dpremidpost"
            case .midPod3: return vmapBase + "&cust_params=sample_ar%3Dpremidpostpod"
            case .midPod5: return vmapBase + "&cust_params=sample_ar%3Dpremidpostlongpod"
            case .broken:
                return "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/"
                    + "does_not_exist&sz=640x480&gdfp_req=1&output=vast&env=vp&impl=s&correlator="
            }
        }
    }

    var body: some View {
        // ONE OGPlayerView (never a second instance) so its ad container
        // survives fullscreen/rotation. Fullscreen is driven by isFullscreen
        // alone; the SDK's autoFullscreenOnRotate flips it on hand rotation.
        GeometryReader { geo in
            VStack(spacing: 0) {
                OGPlayerView(player: player, isFullscreen: $isFullscreen,
                             autoFullscreenOnRotate: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: isFullscreen ? geo.size.height : geo.size.width * 9 / 16)
                if !isFullscreen {
                    controls
                    EventLogView(log: log).frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.background.ignoresSafeArea())
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .onChange(of: isFullscreen) { _, fs in
            // Entering locks landscape; exiting forces portrait so the
            // button works even while the phone is held sideways. Hand
            // rotation still re-enters: the SDK's autoFullscreenOnRotate
            // reads the physical sensor, which ignores interface locks.
            OrientationLock.apply(fs ? .landscape : .portrait)
        }
        .onChange(of: scenario) { _, _ in reload() }
        .onAppear {
            OrientationLock.apply(.all)
            player.adsProvider = IMAAdsProvider()
            if loggers.isEmpty {
                loggers = [attachEventLogging(player, to: log, includeProgress: false),
                           attachAdEventLogging(player, to: log)]
            }
            reload()
        }
        .onDisappear { player.pause(); OrientationLock.apply(.portrait) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Client-side Google IMA ads. Pick a scenario to reload; ad callbacks "
                 + "stream below. IMA renders its own skip / Learn More UI, and the SDK "
                 + "hides its overlays during the break.")
                .font(.system(size: 12)).foregroundStyle(Ink.description)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Scenario.allCases) { s in
                        chip(s.rawValue, selected: scenario == s) { scenario = s }
                    }
                }
            }
        }
        .padding(16)
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
        guard let item = OGMediaItem(urlString: adsContentURL, title: "Ad-supported content",
                                     adBreaks: AdTagConfig(adTagURI: scenario.tag)) else { return }
        player.load(item, autoplay: true)
    }
}

// Short (~60s) clip so the VMAP sample's mid/post cue points land at
// sensible positions on the scrubber.
private let adsContentURL =
    "https://media.ogplayer.tv/tos-clip-60s.mp4"

// Google's public IMA VMAP ad-rule sample base (pre/mid/post scenarios differ
// only by cust_params sample_ar).
private let vmapBase =
    "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/vmap_ad_samples"
    + "&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1&ad_rule=1&output=vmap"
    + "&unviewed_position_start=1&env=vp&impl=s&cmsid=496&vid=short_onecue&correlator="
