import SwiftUI
import OGPlayerCore
import OGPlayerUI

// Content: "Tears of Steel" ((CC) Blender Foundation) throughout. The
// "embedded" case streams the variant with five subtitle languages muxed into
// the HLS manifest (the demo auto-selects the first so they're visible); the
// sideloaded case attaches the movie's real dialog subs — five bundled VTT
// files — to the subtitle-less variant of the same movie.
private let embeddedStream =
    "https://media.ogplayer.tv/tos/master.m3u8"
private let plainVOD = "https://media.ogplayer.tv/tos/master.m3u8"

/// The movie's own subtitles (language code, menu label), bundled as VTTs.
private let bundledSubs: [(code: String, label: String)] = [
    ("en", "English"), ("de", "Deutsch"), ("fr", "Français"),
    ("es", "Español"), ("ru", "Русский"),
]

private enum SubtitleDemoSource: String, CaseIterable, Identifiable {
    case embedded = "Embedded (in manifest)"
    case multiAudio = "Multi-audio (stereo · 5.1 · M&E)"
    case sideloaded = "Sideloaded VTT"
    case positioned = "Positioned VTT (local file, line/position cues)"
    var id: String { rawValue }
    /// Compact label for the split (left) column.
    var short: String {
        switch self {
        case .embedded: return "Embedded"
        case .multiAudio: return "Multi-audio"
        case .sideloaded: return "Sideloaded VTT"
        case .positioned: return "Positioned VTT"
        }
    }
}

/// Subtitle text-size presets → `OGPlayer.subtitleTextScale`.
private let sizeOptions: [(label: String, scale: Double)] =
    [("Small", 0.8), ("Default", 1.0), ("Large", 1.4), ("X-Large", 1.8)]

/// Subtitles, audio & devices.
/// Switch between embedded manifest tracks, an external sideloaded VTT, and a
/// local VTT that exercises every cue setting (line/position/align/size). Audio
/// languages + subtitles are chosen from the CC / audio menus in the controls.
struct TracksDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @StateObject private var rotation = DeviceRotation()
    @State private var isFullscreen = false
    @State private var source: SubtitleDemoSource = .embedded
    @State private var volumeMode: VolumeControlMode = .device
    @State private var textScale: Double = 1.0
    @State private var captionSerif = false
    @State private var logger: EventLogger?

    /// Tracks demo config: no AirPlay button (not relevant to this scenario).
    private var tracksConfig: OGUIConfig {
        var c = OGUIConfig()
        c.showAirPlayButton = false
        return c
    }

    var body: some View {
        // Explicit height (width × 9/16) instead of aspectRatio(.fit): .fit
        // shrinks the player's WIDTH when the controls below grow taller,
        // producing an inset player — the explicit frame stays edge-to-edge
        // regardless of how much UI sits under it (same as the other demos).
        GeometryReader { geo in
            VStack(spacing: 0) {
                OGPlayerView(player: player, isFullscreen: $isFullscreen, config: tracksConfig)
                    .frame(maxWidth: .infinity)
                    .frame(height: isFullscreen ? geo.size.height : geo.size.width * 9 / 16)
                if !isFullscreen {
                    controls
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
        .onChange(of: source) { _, _ in load() }
        .onChange(of: player.subtitleTracks.count) { _, n in
            // Embedded subs are off by default — auto-select the first so the
            // "Embedded" source actually shows subtitles. Sideloaded/positioned
            // are already auto-selected by the SDK (isDefault).
            if source == .embedded, n > 0,
               !player.subtitleTracks.contains(where: { $0.isSelected }),
               let first = player.subtitleTracks.first {
                player.selectSubtitle(id: first.id)
            }
        }
        .onAppear {
            rotation.start()
            OrientationLock.apply(.all)
            if logger == nil { logger = attachEventLogging(player, to: log, includeProgress: false) }
            player.subtitleTextScale = textScale
            load()
        }
        .onDisappear { player.pause(); rotation.stop(); OrientationLock.apply(.portrait) }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tap the player, then use the CC and audio menus in the bottom bar to switch "
                 + "subtitle / audio tracks. Sideloaded VTT is rendered by the SDK.")
                .font(.system(size: 12)).foregroundStyle(Ink.description)

            // Split: subtitle SOURCE on the left, subtitle SIZE on the right —
            // the size drives OGPlayer.subtitleTextScale (works for embedded +
            // sideloaded cues alike).
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Subtitle source")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.groupHeader)
                    ForEach(SubtitleDemoSource.allCases) { option in
                        chip(option.short, selected: source == option) { source = option }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Font size")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.groupHeader)
                    ForEach(sizeOptions, id: \.label) { option in
                        chip(option.label, selected: textScale == option.scale) { setSize(option.scale) }
                    }
                }
                .frame(width: 130, alignment: .leading)
            }

            // Caption typeface — SubtitleStyle.fontName. Georgia is the
            // obviously-different "custom" font; a real app passes its brand
            // font's PostScript name.
            Text("Caption font:")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.groupHeader)
                .padding(.top, 4)
            chip("System (default)", selected: !captionSerif) { setFont(serif: false) }
            chip("Georgia (custom)", selected: captionSerif) { setFont(serif: true) }

            Text("Volume slider controls:")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.groupHeader)
                .padding(.top, 4)
            chip("Device — hardware buttons move the slider",
                 selected: volumeMode == .device) { setMode(.device) }
            chip("Player only — hardware buttons ignored",
                 selected: volumeMode == .player) { setMode(.player) }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func load() {
        log.add("— loading \(source.rawValue) —")
        let item: OGMediaItem?
        switch source {
        case .embedded:
            item = OGMediaItem(urlString: embeddedStream,
                               title: "Embedded subtitles (5 languages)",
                               posterUrl: URL(string: "https://media.ogplayer.tv/posters/tos-mech.jpg"))
        case .multiAudio:
            // Angel One: five REAL audio languages in one manifest — the
            // audio-menu showcase (same asset on the Android and web demos).
            item = OGMediaItem(
                urlString: "https://media.ogplayer.tv/tos/master.m3u8",
                title: "Angel One — five audio languages",
                posterUrl: URL(string: "https://media.ogplayer.tv/posters/tos-mech.jpg"))
        case .sideloaded:
            let subs = bundledSubs.compactMap { sub in
                Bundle.main.url(forResource: "tears_of_steel_\(sub.code)",
                                withExtension: "vtt").map {
                    SubtitleSource(url: $0, language: sub.code, label: sub.label,
                                   isDefault: sub.code == "en")
                }
            }
            item = OGMediaItem(urlString: plainVOD,
                               title: "Sideloaded VTT (5 languages)", subtitles: subs)
        case .positioned:
            let subs: [SubtitleSource] = Bundle.main.url(forResource: "test_cue_settings",
                                                         withExtension: "vtt").map {
                [SubtitleSource(url: $0, language: "en",
                                label: "Cue settings test (local)", isDefault: true)]
            } ?? []
            item = OGMediaItem(urlString: plainVOD, title: "Positioned local VTT", subtitles: subs)
        }
        if let item { player.load(item, autoplay: false) }
    }

    private func setMode(_ m: VolumeControlMode) {
        volumeMode = m
        player.volumeControlMode = m
    }

    private func setSize(_ scale: Double) {
        textScale = scale
        player.subtitleTextScale = scale
        log.add("subtitle size → \(scale)×")
    }

    private func setFont(serif: Bool) {
        captionSerif = serif
        var style = player.subtitleStyle
        style.fontName = serif ? "Georgia" : nil
        player.subtitleStyle = style
        log.add("caption font → \(serif ? "Georgia (custom)" : "system")")
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Ink.accent : Ink.description)
                Text(label).font(.system(size: 13)).foregroundStyle(Ink.title)
                Spacer()
            }
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }
}
