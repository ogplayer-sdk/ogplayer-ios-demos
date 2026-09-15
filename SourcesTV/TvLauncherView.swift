import SwiftUI

struct TvDemo: Identifiable {
    let route: String
    let title: String
    let description: String
    var id: String { route }
}

let tvDemos: [TvDemo] = [
    TvDemo(route: "vod", title: "VOD playback",
           description: "Adaptive HLS — D-pad chrome, Select, Menu, key-driven scrub with storyboard preview."),
    TvDemo(route: "live", title: "Live & DVR",
           description: "Live edge chip, DVR window scrubbing, live gating of the chrome."),
    TvDemo(route: "drm", title: "FairPlay",
           description: "HLS + FairPlay streaming keys with a rotating-token provider — device only."),
    TvDemo(route: "tracks", title: "Subtitles & audio",
           description: "Sideloaded WebVTT and the manifest's audio tracks, ten-foot menus."),
    TvDemo(route: "playlist", title: "Playlist & up next",
           description: "Three items; the Up-next card is focusable — Select skips ahead."),
    TvDemo(route: "ads", title: "Ads (IMA tvOS)",
           description: "Pre/mid/post-roll VMAP through Google's tvOS IMA SDK."),
    TvDemo(route: "ratings", title: "Content ratings",
           description: "Kijkwijzer age + descriptor icons at program start."),
    TvDemo(route: "customactions", title: "Custom action icons",
           description: "Host icons in the chrome, reachable with the D-pad."),
    TvDemo(route: "errormessages", title: "Error overlay",
           description: "A dead stream: the Retry button takes focus."),
]

private enum Ink {
    static let background = Color(red: 0x0E/255, green: 0x0E/255, blue: 0x10/255)
    static let accent = Color(red: 0xF6/255, green: 0xC4/255, blue: 0x45/255)
}

/// tvOS launcher: a focusable list of scenarios. Select opens the player
/// screen; the player's own Menu handling returns here once its chrome is down.
/// Rows draw their own focus look — an amber stroke — never the system
/// list's white card.
struct TvLauncherView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Ink.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 0) {
                        Text("OG").foregroundStyle(Ink.accent)
                        Text("Player")
                        Text(" TV").foregroundStyle(.white.opacity(0.6)).fontWeight(.regular)
                    }
                    .font(.system(size: 40, weight: .bold))
                    Text("Apple TV — Siri Remote chrome")
                        .font(.system(size: 22)).foregroundStyle(.white.opacity(0.48))
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 14) {
                            ForEach(tvDemos) { demo in
                                NavigationLink(destination: TvPlayerScreen(route: demo.route)) {
                                    TvDemoRow(demo: demo)
                                }
                                .buttonStyle(TvRowStyle())
                                .accessibilityIdentifier("tv_row_\(demo.route)")
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 6)   // room for the focused stroke
                    }
                    .focusEffectDisabled()
                    .accessibilityIdentifier("tv_menu")
                    Text("▲ ▼ choose   Select open   Menu back")
                        .font(.system(size: 20)).foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 24)
            }
        }
    }
}

private struct TvDemoRow: View {
    let demo: TvDemo
    var body: some View {
        HStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Ink.accent.opacity(0.12))
                Image(systemName: "play.fill").font(.system(size: 32)).foregroundStyle(Ink.accent)
            }
            .frame(width: 88, height: 88)
            VStack(alignment: .leading, spacing: 6) {
                Text(demo.title).font(.system(size: 32, weight: .semibold)).foregroundStyle(.white)
                Text(demo.description).font(.system(size: 22)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }
}

/// Focus = an amber stroke on a faint amber fill.
private struct TvRowStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(focused ? Ink.accent.opacity(0.14) : Color.white.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24)
                .stroke(focused ? Ink.accent : Color.white.opacity(0.07), lineWidth: focused ? 4 : 1))
            .animation(.easeOut(duration: 0.12), value: focused)
    }
}
