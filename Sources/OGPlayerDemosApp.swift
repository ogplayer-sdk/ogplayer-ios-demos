import SwiftUI

@main
struct OGPlayerDemosApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            // Test hook: SIMCTL_CHILD_OG_DEMO=orientation|live jumps straight
            // into a demo so behavior can be verified headlessly.
            switch ProcessInfo.processInfo.environment["OG_DEMO"] {
            case "verticalfeed": VerticalFeedDemo()
            case "playlist": PlaylistDemo()
            case "orientation": OrientationDemo()
            case "controls": ControlsDemo()
            case "customactions": CustomActionsDemo()
            case "drm": DrmDemo()
            case "downloads": DownloadsDemo()
            case "ratings": RatingsDemo()
            case "tracks": TracksDemo()
            case "ads": AdsDemo()
            case "freewheel": FreewheelDemo()
            case "watermarks": WatermarksDemo()
            case "live": LivePlayerDemo()
            case "startfullscreen": StartFullscreenDemo()
            case "errormessages": ErrorMessagesDemo()
            default: LauncherView()
            }
        }
    }
}
