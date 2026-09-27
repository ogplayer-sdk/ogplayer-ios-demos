import SwiftUI
import OGPlayerCore
import OGPlayerUI

private let startFsStream = "https://media.ogplayer.tv/tos/master.m3u8"  // tears-of-steel

/// Starts directly in fullscreen — the player opens straight into
/// `StartFullscreenDemo`. The `isFullscreen` binding begins `true`, so the
/// player opens landscape and full-bleed on first appearance; tapping the
/// collapse button returns to the demo list.
struct StartFullscreenDemo: View {
    @StateObject private var player = OGPlayer()
    @State private var isFullscreen = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        OGPlayerView(player: player, isFullscreen: $isFullscreen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Ink.background.ignoresSafeArea())
            .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
            .statusBarHidden(isFullscreen)
            .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
            .onChange(of: isFullscreen) { _, fs in
                if fs {
                    OrientationLock.apply(.landscape)
                } else {
                    // Collapse returns to the list in portrait.
                    OrientationLock.apply(.portrait)
                    dismiss()
                }
            }
            .onAppear {
                OrientationLock.apply(.landscape)
                if let item = OGMediaItem(urlString: startFsStream, title: "Starts in fullscreen",
                   posterUrl: URL(string: "https://media.ogplayer.tv/posters/tos-mech.jpg")) {
                    // Test hook: SIMCTL_CHILD_OG_START_AT=<seconds> seeks a
                    // bright frame for headless visual checks.
                    let t = ProcessInfo.processInfo.environment["OG_START_AT"]
                        .flatMap(Double.init) ?? 0
                    player.load(item, startAt: t, autoplay: false)
                }
            }
            .onDisappear { player.pause(); OrientationLock.apply(.portrait) }
    }
}
