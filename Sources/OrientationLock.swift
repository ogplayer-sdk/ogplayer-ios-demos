import OGPlayerCore
import SwiftUI
import UIKit

/// App-level orientation control. The SDK owns the fullscreen *button* (a
/// binding on `OGPlayerView`); the host app owns the *presentation* and the
/// device orientation — the app, not the player, holds the orientation locks.
enum OrientationLock {
    /// Read back by `AppDelegate.supportedInterfaceOrientationsFor`.
    static var mask: UIInterfaceOrientationMask = .all

    /// Lock to `mask` and, if the current interface doesn't already satisfy
    /// it, rotate there — so tapping fullscreen rotates into landscape even
    /// while the device is held in portrait (and back again).
    static func apply(_ newMask: UIInterfaceOrientationMask) {
        mask = newMask
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.keyWindow?.rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: newMask)) { _ in }
    }
}

/// Reports the app's currently-allowed orientations to UIKit, and forwards
/// background-download relaunch events to the SDK.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?)
        -> UIInterfaceOrientationMask { OrientationLock.mask }

    /// Downloads finished while the app wasn't running — hand the system's
    /// completion handler to the SDK's background download session.
    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        OGDownloadManager.handleBackgroundEvents(identifier: identifier,
                                                 completionHandler: completionHandler)
    }
}

/// Publishes the *physical* device orientation (from the sensor, independent
/// of any interface lock) so a demo can auto-enter/exit fullscreen on
/// rotation.
@MainActor
final class DeviceRotation: ObservableObject {
    @Published var isLandscape = false

    private var observer: NSObjectProtocol?

    func start() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            let o = UIDevice.current.orientation
            guard o.isPortrait || o.isLandscape else { return } // ignore flat/unknown
            self?.isLandscape = o.isLandscape
        }
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}
