import SwiftUI
import OGPlayerCore
import OGPlayerUI

/// Custom action icons: up to 8 host-supplied, icon-only buttons rendered
/// inline in the top-end control row, left of the AirPlay button. They are
/// part of the chrome — they show/hide with the controls — while watermarks
/// (overlay slots) are a separate layer below that line. Every tap lands in
/// the host's callback (logged below). Toggle icons one by one to judge
/// spacing; add the watermark + NICAM row to see all three layers dance.
struct CustomActionsDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @State private var isFullscreen = false
    @State private var enabledIcons: Set<Int> = [0, 1]
    @State private var watermark = false
    @State private var nicam = false
    @State private var logger: EventLogger?

    private let demoIcons = ["square.and.arrow.up", "heart", "info.circle", "star",
                             "magnifyingglass", "bubble.right", "arrow.down.circle", "clock"]

    private var demoConfig: OGUIConfig {
        var c = OGUIConfig()
        c.customActions = enabledIcons.sorted().map { index in
            CustomAction(icon: Image(systemName: demoIcons[index]),
                         accessibilityLabel: "Icon \(index + 1)") {
                log.add("custom icon\(index + 1) tap callback")
            }
        }
        return c
    }

    private var demoOverlays: [OverlaySlot: AnyView] {
        guard watermark else { return [:] }
        return [.topTrailing: AnyView(
            Text("WATERMARK")
                // 15pt ≈ Android's 12sp relative to the wider iOS player.
                .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.black.opacity(0.5))
        )]
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                OGPlayerView(player: player, isFullscreen: $isFullscreen,
                             config: demoConfig, overlays: demoOverlays,
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
        .onChange(of: isFullscreen) { _, fs in OrientationLock.apply(fs ? .landscape : .portrait) }
        // Ratings render once at content start, so toggling NICAM reloads the
        // item to re-trigger the row.
        .onChange(of: nicam) { _, _ in load() }
        .onAppear {
            OrientationLock.apply(.all)
            if logger == nil { logger = attachEventLogging(player, to: log, includeProgress: false) }
            load()
        }
        .onDisappear { player.pause(); OrientationLock.apply(.portrait) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icons 1-8, individually toggleable (max 8 = the SDK cap); the
            // checkbox shows the glyph itself so it maps to the control row.
            ForEach([0..<4, 4..<8], id: \.self) { range in
                HStack(spacing: 28) {
                    ForEach(range, id: \.self) { index in
                        checkbox(isOn: enabledIcons.contains(index),
                                 toggle: {
                                     if enabledIcons.contains(index) {
                                         enabledIcons.remove(index)
                                     } else {
                                         enabledIcons.insert(index)
                                     }
                                 },
                                 label: { Image(systemName: demoIcons[index]) })
                    }
                }
            }
            HStack(spacing: 28) {
                checkbox(isOn: watermark, toggle: { watermark.toggle() },
                         label: { Text("Watermark").font(.system(size: 15)) })
                checkbox(isOn: nicam, toggle: { nicam.toggle() },
                         label: { Text("NICAM (reloads)").font(.system(size: 15)) })
            }
            Text("White icons sit inline left of AirPlay and hide with the "
                 + "controls; each tap fires the host callback (logged below). "
                 + "While NICAM icons show, the whole button row drops below "
                 + "them and glides back; the watermark stays below the line.")
                .font(.system(size: 12)).foregroundStyle(Ink.description)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func checkbox(isOn: Bool, toggle: @escaping () -> Void,
                          @ViewBuilder label: () -> some View) -> some View {
        Button(action: toggle) {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24))
                    .foregroundStyle(isOn ? Ink.accent : Ink.description)
                label()
                    .font(.system(size: 22))
                    .foregroundStyle(Ink.title)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func load() {
        guard let item = OGMediaItem(
            urlString: "https://demo.unified-streaming.com/k8s/features/stable/video/"
                + "tears-of-steel/tears-of-steel.ism/.m3u8",
            contentRatings: nicam ? [.age(.sixteen), .descriptor(.fear)] : []
        ) else { return }
        player.load(item, autoplay: true)
    }
}
