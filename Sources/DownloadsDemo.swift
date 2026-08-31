import SwiftUI
import OGPlayerCore
import OGPlayerUI

/// Download-to-go: queue a stream for offline playback, watch progress, then
/// play it with networking OFF (airplane mode) — including the DRM'd stream,
/// whose persistent FairPlay licence was fetched at download time and is
/// restored at playback with no licence request and no token call.
///
/// - "Clear (ToS)": the Tears of Steel ladder from media.ogplayer.tv.
/// - "FairPlay": the Axinom test vector the DRM demo shares with Android and
///   web — its entitlement explicitly allows licence persistence
///   (`allow_persistence: true`), so it demonstrates the full offline-DRM
///   lifecycle incl. "Renew licence".
///
/// Playing a download needs no special code — `player.load` of the same URL
/// automatically picks up the local copy. NOTE: FairPlay keys require real
/// device hardware; the DRM'd download fails up front on the Simulator.
struct DownloadsDemo: View {
    /// Which scenario the Download/Play buttons act on.
    private enum DownloadStream: String, CaseIterable {
        case clear = "Clear (ToS)"
        case fairplay = "FairPlay"
    }

    @StateObject private var player = OGPlayer()
    /// The process-wide download manager — `downloads` is `@Published`, so
    /// the rows below re-render on every state/progress change.
    @ObservedObject private var manager: OGDownloadManager = .shared
    @StateObject private var log = EventLogState()
    @StateObject private var rotation = DeviceRotation()
    @State private var stream: DownloadStream = .clear
    @State private var isFullscreen = false
    @State private var logger: EventLogger?
    @State private var downloadLogger: DownloadEventLogger?
    /// URL of the download currently loaded into the player, so completion
    /// events don't re-load (and restart) an already-loaded item.
    @State private var loadedDownloadURL: URL?

    var body: some View {
        Group {
            if isFullscreen {
                OGPlayerView(player: player, isFullscreen: $isFullscreen)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if loadedDownloadURL != nil {
                        OGPlayerView(player: player, isFullscreen: $isFullscreen)
                            .aspectRatio(16.0 / 9.0, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    } else {
                        // Pre-download placeholder where the player will
                        // appear — returns after Delete (RN-demo parity).
                        ZStack {
                            Color.black
                            Text("Download below — the finished download loads here.")
                                .font(.system(size: 12))
                                .foregroundStyle(Ink.description)
                        }
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        // One download at a time: while anything is downloaded or in
                        // flight, the stream chooser and Download button give way to
                        // the download's own row — Delete brings the choices back.
                        // A COMPLETED download auto-loads into the player above, so
                        // its own play button is the only play control (no extra
                        // buttons; the row keeps just Delete).
                        if manager.downloads.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(DownloadStream.allCases, id: \.rawValue) { s in
                                    chip(s.rawValue, selected: stream == s) { stream = s }
                                }
                            }
                            HStack(spacing: 8) {
                                actionButton("Download") { download() }
                            }
                        }
                        ForEach(manager.downloads) { d in
                            downloadRow(d)
                        }
                        Text("Download, then toggle airplane mode and press play on the "
                             + "player — both streams keep playing. The DRM stream restores "
                             + "its persistent licence with no network and no token call.")
                            .font(.system(size: 12)).foregroundStyle(Ink.description)
                        Text("FairPlay requires a real device — the DRM'd download fails on the Simulator.")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.accent)
                        if let err = player.error {
                            Text("Error \(err.code): \(err.message)")
                                .font(.system(size: 11)).foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    // Green event log — download lifecycle + playback events.
                    EventLogView(log: log).frame(maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.background.ignoresSafeArea())
        .toolbar(isFullscreen ? .hidden : .visible, for: .navigationBar)
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .onChange(of: isFullscreen) { _, fs in
            OrientationLock.apply(fs ? .landscape : .portrait)
        }
        // Physical rotation → enter/exit fullscreen.
        .onChange(of: rotation.isLandscape) { _, landscape in
            if landscape != isFullscreen { isFullscreen = landscape }
        }
        .onAppear {
            rotation.start()
            OrientationLock.apply(.all)
            if logger == nil { logger = attachEventLogging(player, to: log, includeProgress: false) }
            if downloadLogger == nil {
                let dl = DownloadEventLogger(log: log)
                manager.addListener(dl)
                downloadLogger = dl
            }
            loadCompletedDownloadIfNeeded()
        }
        // A finished download goes straight into the player — its play button
        // is the demo's play control from here on. Use the PUBLISHED value:
        // @Published emits during willSet, so reading manager.downloads here
        // still sees the OLD array — the completion publish is the last one,
        // and reading stale state here means never loading at all.
        .onReceive(manager.$downloads) { downloads in
            loadCompletedDownloadIfNeeded(in: downloads)
        }
        .onDisappear {
            player.pause(); rotation.stop(); OrientationLock.apply(.portrait)
            // Demo hygiene: leaving the screen deletes the downloads (FairPlay
            // keys erase locally — no server round-trip, so no item needed).
            // The SDK itself keeps downloads until told otherwise.
            manager.downloads.forEach { manager.removeDownload(url: $0.url) }
            if let dl = downloadLogger { manager.removeListener(dl); downloadLogger = nil }
        }
    }

    // MARK: Rows

    private func downloadRow(_ d: OGDownload) -> some View {
        HStack(spacing: 8) {
            Text(summary(of: d))
                .font(.system(size: 11)).foregroundStyle(Ink.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            switch d.state {
            case .downloading, .queued:
                actionButton("Pause") { manager.pause(url: d.url) }
            case .paused, .failed:
                actionButton("Resume") { manager.resume(url: d.url) }
            case .completed, .removing:
                EmptyView()
            }
            actionButton("Delete") { manager.removeDownload(url: d.url) }
        }
    }

    /// "title · state · percent · licence info" — mirrors the Android demo row.
    private func summary(of d: OGDownload) -> String {
        var text = "\(d.title ?? d.url.absoluteString) · \(d.state.rawValue)"
        if d.progressPercent >= 0 { text += " \(Int(d.progressPercent))%" }
        if let lic = d.license {
            if let expires = lic.expiresAt {
                text += " · licence " + (lic.isExpired ? "EXPIRED " : "until ")
                    + expires.formatted(date: .abbreviated, time: .shortened)
            } else {
                text += " · licence unlimited"
            }
        }
        return text
    }

    // MARK: Actions

    private func download() {
        guard let item = item(for: stream) else { return }
        log.add("— queueing \(stream.rawValue) (720p cap) —")
        manager.add(item, config: OGDownloadConfig(maxVideoHeight: 720))
    }

    /// Load the completed download into the player (paused) exactly once, so
    /// the player's own play button plays it — offline pickup is keyed by
    /// URL, no special code. Deleting the download resets the latch.
    private func loadCompletedDownloadIfNeeded(in downloads: [OGDownload]? = nil) {
        let list = downloads ?? manager.downloads
        guard let d = list.first(where: { $0.state == .completed }) else {
            // Delete → back to the pre-download placeholder; pause so a
            // playing item can't keep sounding behind it.
            if list.isEmpty, loadedDownloadURL != nil {
                player.pause()
                loadedDownloadURL = nil
            }
            return
        }
        guard loadedDownloadURL != d.url else { return }
        let s = downloadedStream(of: d)
        guard let item = item(for: s) else { return }
        loadedDownloadURL = d.url
        log.add("— \(s.rawValue) downloaded, loading into the player (plays offline) —")
        player.load(item, autoplay: false)
    }

    /// The scenario a download corresponds to — offline pickup is keyed by URL.
    private func downloadedStream(of d: OGDownload) -> DownloadStream {
        d.url.absoluteString == fairplayStreamURL ? .fairplay : .clear
    }

    /// The media item for a scenario — the SAME item for Download and Play;
    /// offline pickup is keyed by URL.
    private func item(for stream: DownloadStream) -> OGMediaItem? {
        switch stream {
        case .clear:
            return OGMediaItem(
                urlString: "https://media.ogplayer.tv/tos/master.m3u8",
                title: "Tears of Steel",
                posterUrl: URL(string: "https://media.ogplayer.tv/posters/tos-mech.jpg"),
                thumbnailTrack: URL(string: "https://media.ogplayer.tv/tos/storyboard/storyboard.vtt"))
        case .fairplay:
            // The Axinom multi-DRM test vector from DrmDemo — the token's
            // entitlement carries allow_persistence: true, so the offline
            // (persistent) FairPlay licence can be acquired at download time.
            return OGMediaItem(
                urlString: fairplayStreamURL,
                title: "Multi-DRM demo (encrypted)",
                posterUrl: URL(string: "https://media.ogplayer.tv/posters/tos-mech.jpg"),
                drm: FairPlayConfig(
                    certificateURLString: axinomCertificateURL,
                    licenseServerURLString: axinomLicenseURL,
                    licenseHeaders: ["X-AxDRM-Message": axinomPersistentToken],
                    requestFormat: .binary))
        }
    }

    // MARK: Chrome

    /// Capsule scenario chip — same look as the DRM demo's picker.
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

    /// Small capsule action button (unselected-chip look).
    private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Ink.title)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Ink.rowSurface, in: Capsule())
                .overlay(Capsule().stroke(Ink.rowBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Logs download lifecycle callbacks into the green event log — the
/// callback-style `OGDownloadListener`; the rows themselves are driven by
/// the manager's `@Published downloads`.
@MainActor
private final class DownloadEventLogger: OGDownloadListener {
    private let log: EventLogState

    init(log: EventLogState) { self.log = log }

    func onDownloadStateChanged(_ download: OGDownload) {
        log.add("download \(download.state.rawValue): \(download.title ?? download.url.lastPathComponent)")
    }

    func onDownloadFailed(_ download: OGDownload, error: OGPlayerError) {
        // Include the message — a bare code like "7100" hides e.g. an offline
        // device behind an opaque number.
        log.add("download FAILED \(error.code): \(error.message)")
    }
}

/// The FairPlay scenario's stream URL — download rows are matched back to
/// their scenario by URL.
private let fairplayStreamURL =
    "https://media.axprod.net/TestVectors/Cmaf/protected_1080p_h264_cbcs/manifest.m3u8"

// Axinom public multi-DRM test vector — the same certificate, licence server
// and JWT DrmDemo's "Multi-DRM (shared)" chip uses. Public test credentials;
// the entitlement message allows licence persistence.
private let axinomCertificateURL = "https://tools.axinom.com/FPScert/fairplay.cer"
private let axinomLicenseURL = "https://drm-fairplay-licensing.axprod.net/AcquireLicense"
private let axinomPersistentToken =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ewogICJ2ZXJzaW9uIjogMSwKICAiY29tX2tleV9pZCI6ICI2OWU1NDA4OC1lOWUwLTQ1MzAtOGMxYS0xZWI2ZGNkMGQxNGUiLAogICJtZXNzYWdlIjogewogICAgInR5cGUiOiAiZW50aXRsZW1lbnRfbWVzc2FnZSIsCiAgICAidmVyc2lvbiI6IDIsCiAgICAibGljZW5zZSI6IHsKICAgICAgImFsbG93X3BlcnNpc3RlbmNlIjogdHJ1ZQogICAgfSwKICAgICJjb250ZW50X2tleXNfc291cmNlIjogewogICAgICAiaW5saW5lIjogWwogICAgICAgIHsKICAgICAgICAgICJpZCI6ICIzMDJmODBkZC00MTFlLTQ4ODYtYmNhNS1iYjFmODAxOGEwMjQiLAogICAgICAgICAgImVuY3J5cHRlZF9rZXkiOiAicm9LQWcwdDdKaTFpNDNmd3YremZ0UT09IiwKICAgICAgICAgICJ1c2FnZV9wb2xpY3kiOiAiUG9saWN5IEEiCiAgICAgICAgfQogICAgICBdCiAgICB9LAogICAgImNvbnRlbnRfa2V5X3VzYWdlX3BvbGljaWVzIjogWwogICAgICB7CiAgICAgICAgIm5hbWUiOiAiUG9saWN5IEEiLAogICAgICAgICJwbGF5cmVhZHkiOiB7CiAgICAgICAgICAibWluX2RldmljZV9zZWN1cml0eV9sZXZlbCI6IDE1MCwKICAgICAgICAgICJwbGF5X2VuYWJsZXJzIjogWwogICAgICAgICAgICAiNzg2NjI3RDgtQzJBNi00NEJFLThGODgtMDhBRTI1NUIwMUE3IgogICAgICAgICAgXQogICAgICAgIH0KICAgICAgfQogICAgXQogIH0KfQ._NfhLVY7S6k8TJDWPeMPhUawhympnrk6WAZHOVjER6M"
