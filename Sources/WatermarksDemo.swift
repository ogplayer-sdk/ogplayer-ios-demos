import SwiftUI
import OGPlayerCore
import OGPlayerUI

private let watermarkStream = "https://media.ogplayer.tv/tos/master.m3u8"

/// Watermarks / overlays.
/// Toggle a watermark in ANY of the nine overlay slots (the 3×3 grid mirrors
/// the on-screen positions), live and mid-playback. The SDK keeps them clear of
/// the controls; the built-in unlicensed "OGPlayer" mark stays until licensed.
struct WatermarksDemo: View {
    @StateObject private var player = OGPlayer()
    @State private var isFullscreen = false
    @State private var enabled: Set<OverlaySlot> = [.topTrailing]

    /// The 9 slots laid out as they appear on screen.
    private let grid: [[OverlaySlot]] = [
        [.topLeading, .topCenter, .topTrailing],
        [.centerLeading, .center, .centerTrailing],
        [.bottomLeading, .bottomCenter, .bottomTrailing],
    ]

    private var overlays: [OverlaySlot: AnyView] {
        var map: [OverlaySlot: AnyView] = [:]
        for (i, slot) in OverlaySlot.allCases.enumerated() where enabled.contains(slot) {
            map[slot] = AnyView(watermark(i + 1))
        }
        return map
    }

    var body: some View {
        Group {
            if isFullscreen {
                OGPlayerView(player: player, isFullscreen: $isFullscreen, overlays: overlays)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    OGPlayerView(player: player, isFullscreen: $isFullscreen, overlays: overlays)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    controls
                    Spacer()
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
            if let item = OGMediaItem(urlString: watermarkStream, title: "Watermarks",
                   posterUrl: URL(string: "https://media.ogplayer.tv/posters/tos-mech.jpg")) {
                player.load(item, autoplay: false)
            }
        }
        .onDisappear { player.pause(); OrientationLock.apply(.portrait) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tap any slot to place a watermark there — all nine positions. The SDK keeps "
                 + "them clear of the controls (top slots drop below the top bar, bottom slots "
                 + "lift above it).")
                .font(.system(size: 12)).foregroundStyle(Ink.description)
            VStack(spacing: 8) {
                ForEach(grid.indices, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(grid[row], id: \.self) { slot in
                            slotButton(slot)
                        }
                    }
                }
            }
        }
        .padding(16)
    }

    private func slotButton(_ slot: OverlaySlot) -> some View {
        let on = enabled.contains(slot)
        return Button {
            if on { enabled.remove(slot) } else { enabled.insert(slot) }
        } label: {
            Text(shortName(slot))
                .font(.system(size: 12, weight: on ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(on ? Color.black : Ink.title)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(on ? Ink.accent : Ink.rowSurface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Ink.rowBorder, lineWidth: on ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private func watermark(_ n: Int) -> some View {
        Text("WATERMARK \(n)")
            // 15pt ≈ Android's 12sp relative to the wider iOS player.
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
    }

    private func shortName(_ s: OverlaySlot) -> String {
        switch s {
        case .topLeading: return "Top-left"
        case .topCenter: return "Top-center"
        case .topTrailing: return "Top-right"
        case .centerLeading: return "Left"
        case .center: return "Center"
        case .centerTrailing: return "Right"
        case .bottomLeading: return "Bottom-left"
        case .bottomCenter: return "Bottom-center"
        case .bottomTrailing: return "Bottom-right"
        }
    }
}
