import SwiftUI
import OGPlayerCore
import OGPlayerUI

/// Localised chrome (nl).
/// Every word the SDK's chrome shows or speaks to VoiceOver comes from one
/// flat key → text map (`OGStrings(map:)`, English by default) — the same keys
/// on every OGPlayer platform, so an app hands one map to all of them. This
/// screen feeds a complete Dutch map to Tears of Steel (subtitle, audio,
/// quality and speed menus), a live stream (the LIVE chip) and a stream that
/// never loads (the error overlay's copy and Retry button). The map lives
/// here in the app; the SDK ships English only.
private let dutch: [String: String] = [
    "play": "Afspelen",
    "pause": "Pauzeren",
    "replay": "Opnieuw afspelen",
    "seekForward": "{seconds} seconden vooruit",
    "seekBackward": "{seconds} seconden terug",
    "next": "Volgende",
    "previous": "Vorige",
    "volume": "Volume",
    "mute": "Dempen",
    "unmute": "Dempen opheffen",
    "enterFullscreen": "Volledig scherm",
    "exitFullscreen": "Volledig scherm sluiten",
    "seekBar": "Afspeelpositie",
    "customAction": "Actie {n}",
    "subtitles": "Ondertiteling",
    "subtitlesOff": "Uit",
    "audio": "Audio",
    "playbackSpeed": "Afspeelsnelheid",
    "speedNormal": "Normaal",
    "speedValue": "{speed}×",
    "quality": "Videokwaliteit",
    "qualityAuto": "Automatisch",
    "qualityHeight": "{height}p",
    "qualityBitrate": "{kbps} kbps",
    "qualityAdaptive": "adaptief",
    "audioDefault": "Standaard",
    "trackUnknown": "Onbekend",
    "audioFallback": "Audio {n}",
    "subtitlesFallback": "Ondertiteling {n}",
    "audioChannels": "{name} · {channels} kanalen",
    "live": "LIVE",
    "goLive": "Naar live",
    "upNext": "Volgende over {seconds}",
    "playNext": "Volgende afspelen: {title}",
    "nextVideo": "volgende video",
    "ad": "RECLAME",
    "adPod": "{index} van {count}",
    "learnMore": "Meer informatie",
    "skipAd": "Advertentie overslaan",
    "skipIn": "Overslaan over {seconds}",
    "pauseAd": "Advertentie pauzeren",
    "resumeAd": "Advertentie hervatten",
    "adBlockedTitle": "Advertenties worden geblokkeerd",
    "adBlockedText": "Deze video wordt aangeboden met advertenties, maar je adblocker houdt ze tegen.",
    "adBlockedTextHard": "Deze video is alleen beschikbaar met advertenties. Schakel je adblocker uit en laad de pagina opnieuw.",
    "adBlockedDismiss": "Begrepen",
    "adBlockedReload": "Uitgeschakeld — opnieuw laden",
    "dismiss": "Sluiten",
    "errorGeneric": "Afspeelfout {code}",
    "retry": "Opnieuw proberen",
    "downloading": "Downloaden",
    "downloadingItemsOne": "1 item downloaden",
    "downloadingItems": "{count} items downloaden",
    "cast": "Casten",
    "castConnecting": "Verbinden met cast-apparaat",
    "casting": "Bezig met casten",
    "castConnectingStatus": "Verbinden…",
    "castingTo": "Casten naar {device}",
    "airPlay": "AirPlay",
    "airPlayTo": "AirPlay — {device}",
    "pipPlaying": "Speelt af in beeld-in-beeld",
    "sponsored": "Gesponsord",
]

private let filmStream = "https://media.ogplayer.tv/tos/master.m3u8"
private let liveStream = "https://demo.unified-streaming.com/k8s/live/stable/live.isml/.m3u8"
/// Never loads — the errors demo pattern, here to show the overlay's copy.
private let missingStream = "https://media.ogplayer.tv/tos/does-not-exist.m3u8"

private enum LocalisedSource: String, CaseIterable, Identifiable {
    case film = "Film"
    case live = "Live"
    case error = "Error overlay"
    var id: String { rawValue }
}

struct LocalisedChromeDemo: View {
    @StateObject private var player = OGPlayer()
    @State private var isFullscreen = false
    @State private var source: LocalisedSource = .film

    private var config: OGUIConfig {
        var c = OGUIConfig()
        c.strings = OGStrings(map: dutch)
        c.showAirPlayButton = false
        switch source {
        case .film:
            break
        case .live:
            // One audio language and no subtitles on this stream.
            c.showSubtitleButton = false
            c.showAudioTrackButton = false
        case .error:
            // The stream never loads: nothing for the timeline, rate or track
            // controls to act on.
            c.showSeekButtons = false
            c.showProgressBar = false
            c.showTimeLabels = false
            c.showSpeedButton = false
            c.showQualityButton = false
            c.showAudioTrackButton = false
            c.showSubtitleButton = false
        }
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
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("", selection: $source) {
                            ForEach(LocalisedSource.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text(blurb)
                            .font(.system(size: 12))
                            .foregroundStyle(Ink.description)
                    }
                    .padding(16)
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
        .onChange(of: source) { _, _ in load() }
        .onAppear {
            OrientationLock.apply(.all)
            load()
        }
        .onDisappear { player.pause(); OrientationLock.apply(.portrait) }
    }

    private var blurb: String {
        let lead = "config.strings = OGStrings(map: dutch) — one key → text map for every word the "
            + "chrome shows or speaks to VoiceOver. The same keys work on every OGPlayer platform. "
        switch source {
        case .film:
            return lead + "Open the subtitle, audio, quality and speed menus: \u{201C}Uit\u{201D}, "
                + "\u{201C}Automatisch\u{201D}, \u{201C}Normaal\u{201D}. Track names come from the "
                + "stream and follow the device language."
        case .live:
            return lead + "The LIVE chip and the edge label read from the map; VoiceOver says "
                + "\u{201C}Naar live\u{201D} on the chip."
        case .error:
            return lead + "This stream never loads: the overlay reads \u{201C}Afspeelfout {code}\u{201D} "
                + "with an \u{201C}Opnieuw proberen\u{201D} button. errorMessageProvider and "
                + "retryButtonLabel still win where an app sets them."
        }
    }

    private func load() {
        let item: OGMediaItem?
        switch source {
        case .film:
            item = OGMediaItem(urlString: filmStream, title: "Tears of Steel",
                               posterUrl: URL(string: "https://media.ogplayer.tv/posters/tos-mech.jpg"))
        case .live:
            item = OGMediaItem(urlString: liveStream, streamType: .live, title: "Live")
        case .error:
            item = OGMediaItem(urlString: missingStream, title: "Tears of Steel")
        }
        if let item { player.load(item, autoplay: source == .live) }
    }
}
