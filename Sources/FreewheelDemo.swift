import SwiftUI
import OGPlayerCore
import OGPlayerUI

/// FreeWheel demo — bring your own FreeWheel SDK.
///
/// NOTE FOR DEVELOPERS: FreeWheel's AdManager SDK (`AdManager.framework`)
/// is licensed to FreeWheel customers and is NOT bundled with OGplayer.
/// To run this demo (physical device only — the framework ships no
/// simulator slice):
///
///  1. Obtain `AdManager.framework` from your FreeWheel account (MRM
///     support portal or your FreeWheel account manager).
///  2. Copy it into `PrivateFW/` next to `project.yml`.
///  3. Uncomment the FreeWheel block in `project.yml` (framework search
///     path, link flags, embed phase) and run `xcodegen generate`.
///  4. Fill in your network configuration in `DemoFwConfig.swift`.
///
/// The demo then exercises the native slot-provider path: FreeWheel
/// request, SDK-owned ad chrome (yellow bar, countdown, learn-more),
/// prerolls before content, playhead-driven midrolls, postrolls, and error
/// fallback to content. (A FreeWheel network can alternatively be reached
/// as a plain VMAP tag through the IMA provider — `AdTagConfig` with your
/// network's `/ad/g/1` URL — with IMA rendering the ads instead.)
struct FreewheelDemo: View {
#if canImport(AdManager)
    var body: some View {
        if DemoFwConfig.isConfigured {
            FreewheelPlayerView()
        } else {
            SetupNotice(
                detail: "Add your FreeWheel network configuration (network id, "
                    + "ad server URL, profile, site section, video asset) in "
                    + "DemoFwConfig.swift — every value comes from your "
                    + "FreeWheel (MRM) account.")
        }
    }
#else
    var body: some View {
        SetupNotice(
            detail: "The FreeWheel AdManager SDK is not in this build. It is "
                + "licensed to FreeWheel customers and not bundled: add your "
                + "AdManager.framework to PrivateFW/, enable the FreeWheel "
                + "block in project.yml, and rebuild for a device. See the "
                + "notes at the top of FreewheelDemo.swift.")
    }
#endif
}

/// What is missing and how to supply it (see the file-header steps).
private struct SetupNotice: View {
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 40)).foregroundStyle(Ink.accent)
            Text("FreeWheel setup needed")
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(Ink.title)
            Text(detail)
                .font(.system(size: 13)).foregroundStyle(Ink.description)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.background.ignoresSafeArea())
    }
}

#if canImport(AdManager)
private struct FreewheelPlayerView: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @State private var isFullscreen = false
    // Retain the loggers for the lifetime of the screen.
    @State private var loggers: [EventLogger] = []

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                OGPlayerView(player: player, isFullscreen: $isFullscreen,
                             autoFullscreenOnRotate: true)
                    .frame(maxWidth: .infinity)
                    .frame(height: isFullscreen ? geo.size.height : geo.size.width * 9 / 16)
                if !isFullscreen {
                    Text("Native FreeWheel provider — the SDK owns the full ad chrome "
                         + "(yellow bar, countdown, learn-more); FreeWheel renders only "
                         + "the ad media. Prerolls play before content; midrolls trigger "
                         + "from the playhead.")
                        .font(.system(size: 12)).foregroundStyle(Ink.description)
                        .padding(16)
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
            OrientationLock.apply(fs ? .landscape : .portrait)
        }
        .onAppear {
            OrientationLock.apply(.all)
            player.adsProvider = FWAdsProvider()
            if loggers.isEmpty {
                loggers = [attachEventLogging(player, to: log, includeProgress: false),
                           attachAdEventLogging(player, to: log)]
            }
            log.add("— loading with FreeWheel —")
            guard let item = OGMediaItem(
                urlString: "https://demo.unified-streaming.com/k8s/features/stable/video/"
                    + "tears-of-steel/tears-of-steel.ism/.m3u8",
                title: "FreeWheel demo — Tears of Steel",
                adBreaks: DemoFwConfig.build()) else { return }
            player.load(item, autoplay: true)
        }
        .onDisappear { player.pause(); OrientationLock.apply(.portrait) }
    }
}
#endif
