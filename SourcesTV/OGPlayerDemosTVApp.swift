import SwiftUI

/// Apple TV demo app: the same SDK on the Siri Remote chrome. On tvOS the
/// remote chrome IS the chrome — no switch to flip; `OGPlayerView` walks its
/// controls with the D-pad, seeks with Left/Right on the scrub bar, and hands
/// the Menu button to the navigation stack once its own chrome is down.
@main
struct OGPlayerDemosTVApp: App {
    var body: some Scene {
        WindowGroup {
            // Test hook: SIMCTL_CHILD_OG_DEMO=<route> jumps straight into a
            // screen (same contract as the iOS demos).
            if let route = ProcessInfo.processInfo.environment["OG_DEMO"], route != "menu" {
                NavigationStack { TvPlayerScreen(route: route) }
            } else {
                TvLauncherView()
            }
        }
    }
}
