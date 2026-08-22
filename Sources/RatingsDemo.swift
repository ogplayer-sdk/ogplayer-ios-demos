import SwiftUI
import OGPlayerCore
import OGPlayerUI
import OGPlayerAdsIMA

/// Content-rating icons (Kijkwijzer/NICAM style). Pick an age + descriptors;
/// icons show at program start for a few seconds (SDK art; licensed hosts
/// pass official pictograms via `.custom`).
struct RatingsDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()

    @State private var isFullscreen = false
    @State private var age: ContentRating.Age = .sixteen
    @State private var descriptors: Set<Descriptor> = [.violence, .fear]
    /// Demonstrates `.custom` — a host-supplied PNG (from the app's asset
    /// catalog) mixed in with the built-in preset art.
    @State private var custom = false
    /// Proves the icons wait for the ad: with a preroll, ratings show only
    /// when CONTENT starts.
    @State private var withPreroll = false
    @State private var loggers: [EventLogger] = []

    private enum Descriptor: String, CaseIterable {
        case violence, fear, sex, discrimination, drugsAlcohol, coarseLanguage
        var label: String {
            switch self {
            case .violence: return "Violence"; case .fear: return "Fear"
            case .sex: return "Sex"; case .discrimination: return "Discrim."
            case .drugsAlcohol: return "Drugs"; case .coarseLanguage: return "Language"
            }
        }
        var rating: ContentRating.Descriptor {
            switch self {
            case .violence: return .violence; case .fear: return .fear
            case .sex: return .sex; case .discrimination: return .discrimination
            case .drugsAlcohol: return .drugsAlcohol; case .coarseLanguage: return .coarseLanguage
            }
        }
    }
    private let ages: [(ContentRating.Age, String)] = [
        (.all, "AL"), (.six, "6"), (.nine, "9"), (.twelve, "12"),
        (.fourteen, "14"), (.sixteen, "16"), (.eighteen, "18"),
    ]
    private var ratings: [ContentRating] {
        var r: [ContentRating] = [.age(age)]
        r += descriptors.map { .descriptor($0.rating) }
        if custom { r.append(.custom(imageName: "DemoCustomRating")) }
        return r
    }

    var body: some View {
        Group {
            if isFullscreen {
                OGPlayerView(player: player, isFullscreen: $isFullscreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    OGPlayerView(player: player, isFullscreen: $isFullscreen)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Icons show at content start (after ads) for 5s. Defaults are "
                             + "SDK art — licensed hosts pass official NICAM pictograms via "
                             + ".custom.")
                            .font(.system(size: 12)).foregroundStyle(Ink.description)

                        group("Age") {
                            ForEach(ages, id: \.1) { a in
                                chip(a.1, selected: age == a.0) { age = a.0 }
                            }
                        }
                        group("Descriptors") {
                            ForEach(Descriptor.allCases, id: \.self) { d in
                                chip(d.label, selected: descriptors.contains(d)) {
                                    if descriptors.contains(d) { descriptors.remove(d) }
                                    else { descriptors.insert(d) }
                                }
                            }
                        }
                        FlowChips {
                            chip("Custom badge", selected: custom) { custom.toggle() }
                            chip("With preroll", selected: withPreroll) { withPreroll.toggle() }
                        }
                    }
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
        .onChange(of: isFullscreen) { _, fs in OrientationLock.apply(fs ? .landscape : .portrait) }
        .onChange(of: ratings) { _, _ in reload() }
        .onChange(of: withPreroll) { _, _ in reload() }
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

    private func reload() {
        if let item = OGMediaItem(urlString: ratingsStream, title: "NICAM demo",
                                  contentRatings: ratings,
                                  adBreaks: withPreroll ? AdTagConfig(adTagURI: prerollTag) : nil) {
            player.load(item, autoplay: true)
        }
    }

    @ViewBuilder
    private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.groupHeader)
            FlowChips { content() }
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
}

// Short ~60s clip.
private let ratingsStream = "https://media.ogplayer.tv/tos/master.m3u8"

// Google IMA skippable-preroll sample tag.
private let prerollTag =
    "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/"
    + "single_preroll_skippable&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1"
    + "&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator="

/// Simple wrapping row of chips.
private struct FlowChips<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        // A lazy wrapping layout via a simple HStack that scrolls if needed.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { content }
        }
    }
}
