import SwiftUI

/// A single demo entry in the launcher list.
struct Demo: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let systemImage: String
    var tag: String? = nil
    let destination: () -> AnyView
}

struct DemoGroup: Identifiable {
    let id = UUID()
    let header: String
    let demos: [Demo]
}

enum Ink {
    static let background = Color(red: 0x0E/255, green: 0x0E/255, blue: 0x10/255)
    static let accent = Color(red: 0xF6/255, green: 0xC4/255, blue: 0x45/255)
    static let rowSurface = Color.white.opacity(0.045)
    static let rowBorder = Color.white.opacity(0.07)
    static let title = Color.white
    static let description = Color.white.opacity(0.48)
    static let groupHeader = Color.white.opacity(0.38)
    static let chevron = Color.white.opacity(0.30)
    static let tagBg = Color.white.opacity(0.09)
    static let iconTile = Color(red: 0xF6/255, green: 0xC4/255, blue: 0x45/255).opacity(0.12)
}

let demoGroups: [DemoGroup] = [
    DemoGroup(header: "PLAYBACK", demos: [
        Demo(title: "Orientation & fullscreen",
             description: "Rotation, embedded ⇄ fullscreen, insets and cutouts.",
             systemImage: "rotate.right") { AnyView(OrientationDemo()) },
        Demo(title: "Controls on/off",
             description: "Default chrome, per-control hide, fully headless.",
             systemImage: "slider.horizontal.3") { AnyView(ControlsDemo()) },
        Demo(title: "Custom action icons",
             description: "Up to 8 host icons inline in the controls, with callbacks.",
             systemImage: "plus.circle") { AnyView(CustomActionsDemo()) },
        Demo(title: "Picture-in-picture",
             description: "Auto-enter on Home, restore hook.",
             systemImage: "pip") { AnyView(PipDemo()) },
        Demo(title: "Starts in fullscreen",
             description: "Opens directly in fullscreen; host-intercepted exit.",
             systemImage: "arrow.up.left.and.arrow.down.right") { AnyView(StartFullscreenDemo()) },
        Demo(title: "Playlist & up next",
             description: "Queue clips that auto-advance, with a themeable countdown card.",
             systemImage: "text.line.first.and.arrowtriangle.forward") { AnyView(PlaylistDemo()) },
        Demo(title: "Vertical feed",
             description: "Swipeable portrait feed: preloaded neighbours, split layouts, sponsored items.",
             systemImage: "rectangle.portrait.on.rectangle.portrait") { AnyView(VerticalFeedDemo()) },
        Demo(title: "Custom error messages",
             description: "Your copy, your language, on our stable error codes.",
             systemImage: "exclamationmark.bubble") { AnyView(ErrorMessagesDemo()) },
    ]),
    DemoGroup(header: "STREAMING", demos: [
        Demo(title: "Live & DVR",
             description: "Live edge, seekable window, behind-edge state.",
             systemImage: "dot.radiowaves.left.and.right") { AnyView(LivePlayerDemo()) },
        Demo(title: "DRM",
             description: "FairPlay key exchange (device only).",
             systemImage: "lock", tag: "FairPlay") { AnyView(DrmDemo()) },
        Demo(title: "Offline downloads",
             description: "Download-to-go with a persistent FairPlay licence — plays in airplane mode.",
             systemImage: "arrow.down.circle") { AnyView(DownloadsDemo()) },
    ]),
    DemoGroup(header: "TRACKS & DEVICES", demos: [
        Demo(title: "Subtitles & audio",
             description: "Track selection, styling, positioned VTT cues.",
             systemImage: "captions.bubble") { AnyView(TracksDemo()) },
    ]),
    DemoGroup(header: "MONETISATION", demos: [
        Demo(title: "Ads",
             description: "Pre/mid/post-roll pods, skip, cue markers.",
             systemImage: "megaphone", tag: "IMA") { AnyView(AdsDemo()) },
        Demo(title: "FreeWheel",
             description: "Native slot provider, SDK ad chrome. Bring your own FreeWheel SDK.",
             systemImage: "circle.grid.cross", tag: "FW") { AnyView(FreewheelDemo()) },
    ]),
    DemoGroup(header: "OVERLAYS", demos: [
        Demo(title: "Watermarks",
             description: "A watermark in any of nine slots, live.",
             systemImage: "drop") { AnyView(WatermarksDemo()) },
        Demo(title: "Content ratings",
             description: "Age + descriptor icons at program start.",
             systemImage: "shield.lefthalf.filled", tag: "Kijkwijzer") { AnyView(RatingsDemo()) },
    ]),
]
