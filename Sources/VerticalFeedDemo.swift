import SwiftUI
import OGPlayerCore
import OGPlayerUI

/// Vertical feed. Portrait-only by design (the component has no
/// fullscreen/rotation API), so the screen pins orientation while visible.
/// A chooser presents the layouts in three groups; each mode gets a fresh
/// analytics log shown from the action bar.
struct VerticalFeedDemo: View {
    @State private var mode: Int? = nil            // nil = chooser
    @State private var liked: Set<Int> = []
    @State private var likeCounts: [Int: Int] = [0: 1240, 1: 87, 3: 356, 4: 9, 5: 2031]
    @State private var shareCounts: [Int: Int] = [0: 61, 1: 12, 3: 44, 4: 2, 5: 118]
    @State private var showAnalytics = false
    @State private var toast: String?
    @State private var toastGeneration = 0
    @StateObject private var feedState = OGVerticalFeedState()
    @StateObject private var analyticsLog = EventLogState()

    private let base = "https://media.ogplayer.tv/shorts/v3"

    var body: some View {
        Group {
            if let mode {
                feed(mode: mode)
            } else {
                chooser
            }
        }
        .background(Ink.background.ignoresSafeArea())
        // Inside a mode the demo's own header hosts the back chevron — hide
        // the nav bar completely so there is no system chrome to fight.
        .toolbar(mode != nil ? .hidden : .visible, for: .navigationBar)
        .onAppear {
            OrientationLock.apply(.portrait)
            // Test hook: SIMCTL_CHILD_OG_FEED_MODE=0..5 jumps into a mode.
            if mode == nil,
               let raw = ProcessInfo.processInfo.environment["OG_FEED_MODE"],
               let m = Int(raw) {
                mode = m
            }
        }
        .onDisappear { OrientationLock.apply(.portrait) }
    }

    // MARK: chooser

    private var chooser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Vertical feed")
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                Text("One component, six ways to ship it. Pick a mode:")
                    .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))

                groupHeader("VERTICAL VIEW")
                modeCard("OG vertical view",
                         "The feed exactly as the SDK ships it: video, tap-to-pause, progress " +
                         "hairline. No title, no subtitle, no icons — the right rail is an " +
                         "empty placeholder your app fills (up to 6 actions).", 0)
                modeCard("Custom: icons, title & badge",
                         "Everything the host can add: title + subtitle in a custom font, " +
                         "custom play glyph, a custom AD badge on the sponsored item, and " +
                         "rail actions with live state — like, share, mute and a ⋯ hook.", 1)

                groupHeader("SPLIT VIEW")
                modeCard("Split screen: text + video",
                         "The page splits into a text section and a video section — text " +
                         "above or below (TextPlacement), sized by textBandFraction, with " +
                         "band background color, custom font and text sizes. " +
                         "Swipe: item 2 has the text below.", 2)
                modeCard("Split video: two sources",
                         "Two videos on one page — the primary plays on top with audio, " +
                         "scrubbing and analytics; the second plays below, starting in the " +
                         "same frame and pausing/resuming with the primary " +
                         "(secondaryMedia). Page 2 flips the audio to the bottom half.", 3)

                groupHeader("ERROR HANDLING")
                modeCard("Errors: SDK default",
                         "Every stream in this feed 404s on purpose. The SDK shows its " +
                         "default compact error state — message + Retry — and onItemError " +
                         "fires per item. Swiping past a failed page always works.", 4)
                modeCard("Errors: custom overlay",
                         "Same broken feed, but the errorOverlay slot renders the app's own " +
                         "panel with its own button.", 5)
            }
            .padding(20)
        }
    }

    private func groupHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Ink.accent.opacity(0.8))
            .padding(.top, 6)
    }

    private func modeCard(_ title: String, _ body: String, _ value: Int) -> some View {
        Button {
            analyticsLog.clear()   // each mode gets its own session, like Android
            // Fresh screen per mode: likes, share counts and feed state must
            // not leak from the previous mode.
            liked.removeAll()
            shareCounts = [0: 61, 1: 12, 3: 44, 4: 2, 5: 118]
            feedState.isMuted = false
            mode = value
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(Ink.accent)
                Text(body).font(.system(size: 13)).foregroundColor(.white.opacity(0.72))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.09, green: 0.094, blue: 0.11)))
        }
        .buttonStyle(.plain)
    }

    // MARK: feed

    @ViewBuilder
    private func feed(mode: Int) -> some View {
        ZStack(alignment: .bottom) {
        feedBody(mode: mode)
        if let toast {
            Text(toast)
                .font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Capsule().fill(Color(red: 0.16, green: 0.17, blue: 0.20)))
                .padding(.bottom, 64)
                .transition(.opacity)
        }
        }
    }

    /// The Android demo shows a Toast on share/menu taps so the callback is
    /// visible; this is the iOS stand-in.
    private func showToast(_ message: String) {
        toastGeneration += 1
        let generation = toastGeneration
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if toastGeneration == generation { withAnimation { toast = nil } }
        }
    }

    @ViewBuilder
    private func feedBody(mode: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    self.mode = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                Text(mode == 1 ? "Vertical feed — custom" : "Vertical feed")
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Button("Analytics (\(analyticsLog.entries.count))") { showAnalytics = true }
                    .font(.system(size: 13)).foregroundColor(Ink.accent)
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Ink.background)

            OGVerticalFeedView(
                items: items(for: mode),
                config: config(for: mode),
                state: feedState,
                onItemSkipped: { _, _ in },
                onAnalyticsEvent: { event in analyticsLog.add("analytics: \(event)") },
                onItemDoubleTapped: { index, _ in
                    analyticsLog.add("— double-tap on item \(index): your action here —")
                },
                sponsoredBadge: mode == 1 ? { _ in
                    AnyView(
                        Text("AD")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.075, green: 0.075, blue: 0.075))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Ink.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(16)
                    )
                } : nil,
                errorOverlay: mode == 5 ? { error, retry in
                    AnyView(
                        ZStack {
                            Color(red: 0.07, green: 0.075, blue: 0.09).opacity(0.92)
                            VStack(spacing: 5) {
                                Text("😕  This clip won't play")
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                Text("Error \(error.code) — this panel is the demo app's UI.")
                                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                                Button(action: retry) {
                                    Text("Try again").fontWeight(.semibold)
                                        .padding(.horizontal, 22).padding(.vertical, 8)
                                        .background(Ink.accent)
                                        .foregroundColor(Color(red: 0.075, green: 0.075, blue: 0.075))
                                        .clipShape(Capsule())
                                }
                                .padding(.top, 6)
                            }
                            .padding(24)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.114, green: 0.122, blue: 0.141)))
                        }
                    )
                } : nil)
                // New identity per mode: full teardown of the previous
                // mode's player pool — no paused state or page index leaks.
                .id(mode)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("OGPlayer demo — your tab bar goes here (back returns to the modes)")
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Ink.background)
        }
        .sheet(isPresented: $showAnalytics) {
            NavigationStack {
                Group {
                    if analyticsLog.entries.isEmpty {
                        Text("No events yet — swipe through the feed, let a clip loop.")
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
                    } else {
                        EventLogView(log: analyticsLog)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Ink.background.ignoresSafeArea())
                .navigationTitle("Feed analytics — this session")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: content

    private var portraitClips: [(String, String, Int)] {[
        ("The memory scan", "@tearsofsteel · Forty years on, they scan his memories of her — every one still intact. #scifi", 0),
        ("Forty years later", "@tearsofsteel · Old Thom returns to the ruined church where it all began. #shortfilm", 1),
        ("Sponsored — OGPlayer", "One player API — multi-DRM, ads, subtitles, casting. Free to evaluate at ogplayer.tv", 2),
        ("Rooftops of Amsterdam", "@tearsofsteel · The projection sweeps across the old city's rooftops. #vfx", 3),
        ("Face to face", "@tearsofsteel · Thom and the machine that remembers him, alone in the ruins. #robots", 4),
        ("The final projection", "@tearsofsteel · He reaches out one last time — released CC-BY by the Blender Foundation. #ccby", 5),
    ]}

    private func rail(for i: Int) -> [RailAction] {[
        RailAction(icon: Image(systemName: i.isMultiple(of: 2) ? "heart.fill" : "heart"),
                   label: format(count: (likeCounts[i] ?? 42) + (liked.contains(i) ? 1 : 0)),
                   isActive: liked.contains(i),
                   accessibilityLabel: "Like") {
            if liked.contains(i) { liked.remove(i) } else { liked.insert(i) }
        },
        RailAction(icon: Image(systemName: "square.and.arrow.up"),
                   label: format(count: shareCounts[i] ?? 7),
                   accessibilityLabel: "Share") {
            shareCounts[i] = (shareCounts[i] ?? 7) + 1
            showToast("Share tapped — your share sheet goes here")
        },
        RailAction(icon: Image(systemName: feedState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"),
                   label: feedState.isMuted ? "Unmute" : "Mute",
                   isActive: feedState.isMuted,
                   accessibilityLabel: "Mute") {
            feedState.isMuted.toggle()
        },
        RailAction(icon: Image(systemName: "ellipsis"),
                   accessibilityLabel: "More") {
            showToast("Your menu goes here")
            analyticsLog.add("— ⋯ tapped: your menu goes here —")
        },
    ]}

    private func items(for mode: Int) -> [OGVerticalFeedItem] {
        switch mode {
        case 2:
            let wides: [(String, String, TextPlacement)] = [
                ("The old church",
                 "Amsterdam's canal belt, forty years on. The survivors kept the church exactly as it was on the night of the projection — every stone, every cable, every memory of her still wired into the walls.",
                 .aboveVideo),
                ("Crossing the bridge",
                 "Thom walks the Oudezijds bridge one more time. The city looks ordinary — bicycles, canal houses, tourists — but the machines remember everything that happened here.",
                 .belowVideo),
                ("The machine waits",
                 "It has stood on the bridge for decades, silent and patient — and this text lives in the section above it.",
                 .aboveVideo),
            ]
            return wides.enumerated().map { i, wide in
                let n = String(format: "%02d", i + 1)
                return OGVerticalFeedItem(
                    media: OGMediaItem(urlString: "\(base)/w169-\(n).mp4", title: wide.0)!,
                    posterUrl: URL(string: "\(base)/w169-\(n).jpg"),
                    railActions: [rail(for: i)[0], rail(for: i)[2]],
                    title: wide.0, subtitle: wide.1,
                    textPlacement: wide.2)
            }
        case 3:
            let pairs: [(String, String, String)] = [
                ("01", "04", "Two sources, one page"),
                ("05", "02", "Bottom owns the audio here"),
                ("06", "03", "Bottom follows play/pause"),
            ]
            return pairs.enumerated().map { i, pair in
                OGVerticalFeedItem(
                    media: OGMediaItem(urlString: "\(base)/clip\(pair.0).mp4", title: pair.2)!,
                    secondaryMedia: OGMediaItem(urlString: "\(base)/clip\(pair.1).mp4")!,
                    splitAudioSource: i == 1 ? .secondary : .primary,
                    posterUrl: URL(string: "\(base)/clip\(pair.0).jpg"),
                    railActions: rail(for: i),
                    title: pair.2)
            }
        case 4, 5:
            return (1...3).map { n in
                OGVerticalFeedItem(
                    media: OGMediaItem(urlString: "\(base)/broken-clip0\(n).mp4",
                                       title: "Broken stream \(n)")!,
                    posterUrl: URL(string: "\(base)/clip0\(n).jpg"),
                    title: "Broken stream \(n)")
            }
        default:
            return portraitClips.map { clip in
                let n = String(format: "%02d", clip.2 + 1)
                let sponsored = clip.2 == 2
                return OGVerticalFeedItem(
                    media: OGMediaItem(urlString: sponsored
                        ? "\(base)/ad-ogplayer.mp4" : "\(base)/clip\(n).mp4",
                        title: clip.0)!,
                    // The ad spot has its badge near the frame edge; FIT shows
                    // the full frame on every page ratio (bg matches the feed).
                    contentFit: sponsored ? .fit : nil,
                    posterUrl: URL(string: sponsored
                        ? "\(base)/ad-ogplayer.jpg" : "\(base)/clip\(n).jpg"),
                    railActions: (mode == 1 && !sponsored) ? rail(for: clip.2) : [],
                    title: clip.0, subtitle: clip.1,
                    isSponsored: sponsored)
            }
        }
    }

    private func config(for mode: Int) -> OGVerticalFeedConfig {
        var c = OGVerticalFeedConfig()
        switch mode {
        case 1:
            c.showTitle = true
            c.showSubtitle = true
            c.titleFont = .system(size: 18, weight: .bold, design: .serif)
            c.subtitleFont = .system(size: 14.5, design: .serif)
            c.playIcon = Image(systemName: "play.circle.fill")
            c.progressBarColor = Ink.accent
            c.progressBarTrackColor = Ink.accent.opacity(0.25)
            c.progressBarThickness = 3
        case 2:
            c.showTitle = true
            c.showSubtitle = true
            c.titleFont = .system(size: 21, weight: .bold, design: .serif)
            c.subtitleFont = .system(size: 15.5, design: .serif)
            c.textBandColor = Color(red: 0.078, green: 0.094, blue: 0.129).opacity(0.8)
            c.textBandFraction = 0.36
        case 3, 4, 5:
            c.showTitle = true
        default:
            break
        }
        return c
    }

    private func format(count: Int) -> String {
        switch count {
        case 1_000_000...: return String(format: "%.1fM", Double(count) / 1_000_000)
        case 1_000...: return String(format: "%.1fK", Double(count) / 1_000)
        default: return "\(count)"
        }
    }
}
