import SwiftUI
import OGPlayerCore
import OGPlayerUI

/// FairPlay DRM showcase using EZDRM's public FairPlay test asset — two
/// scenarios:
///
/// - "FairPlay (open)": plain `FairPlayConfig`, static config only. The SDK
///   runs the SPC → CKC handshake via `AVContentKeySession`; the host supplies
///   the app certificate + KSM (license) endpoint.
/// - "Token header": same stream, but the config carries a `tokenProvider`
///   invoked fresh on EVERY license request (watch the log) — the mechanism
///   that fixes the classic frozen-token/resume-after-pause failure. Here it
///   just mints a demo header; real hosts fetch/refresh auth.
///
/// NOTE: FairPlay content keys require real device hardware — protected
/// playback does NOT work on the iOS Simulator (you'll see a decode/DRM
/// error there). Verify on a device.
struct DrmDemo: View {
    /// Which license scenario is loaded.
    private enum DrmStream: String, CaseIterable {
        case open = "FairPlay (open)"
        case token = "Token header"
        case multiDrm = "Multi-DRM (shared)"
    }

    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @State private var stream: DrmStream = .open
    @State private var isFullscreen = false
    @State private var logger: EventLogger?

    /// DRM demo config: no AirPlay button (not relevant to this scenario).
    private var drmConfig: OGUIConfig {
        var c = OGUIConfig()
        c.showAirPlayButton = false
        return c
    }

    var body: some View {
        Group {
            if isFullscreen {
                OGPlayerView(player: player, isFullscreen: $isFullscreen, config: drmConfig)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    OGPlayerView(player: player, isFullscreen: $isFullscreen, config: drmConfig)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(DrmStream.allCases, id: \.rawValue) { s in
                                chip(s.rawValue, selected: stream == s) { stream = s }
                            }
                        }
                        Text("FairPlay Streaming — EZDRM public test asset. The SDK fetches "
                             + "the app certificate, builds the SPC, calls the KSM and installs "
                             + "the CKC via AVContentKeySession. The token chip adds a per-request "
                             + "tokenProvider — watch it log on every license call.")
                            .font(.system(size: 12)).foregroundStyle(Ink.description)
                        Text("Requires a real device — FairPlay keys don't work on the Simulator.")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.accent)
                        if let err = player.error {
                            Text("Error \(err.code): \(err.message)")
                                .font(.system(size: 11)).foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    // Green event log — watch DrmKeysLoaded arrive as the
                    // SPC → CKC handshake completes.
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
        .onChange(of: stream) { _, _ in reload() }
        .onAppear {
            OrientationLock.apply(.all)
            if logger == nil { logger = attachEventLogging(player, to: log, includeProgress: false) }
            reload()
        }
        .onDisappear { player.pause(); OrientationLock.apply(.portrait) }
    }

    /// Capsule scenario chip — same look as the ads demo's picker.
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

    /// (Re)load the selected scenario.
    private func reload() {
        log.add("— loading \(stream.rawValue) —")
        // The provider closure is @Sendable and runs off the main actor, so
        // capture only the (MainActor-isolated, hence Sendable) log object —
        // not the view struct.
        let log = log
        let drm: FairPlayConfig?
        switch stream {
        case .open:
            drm = FairPlayConfig(
                certificateURLString: certificateURL,
                licenseServerURLString: licenseURL,
                requestFormat: .binary)
        case .token:
            drm = FairPlayConfig(
                certificateURLString: certificateURL,
                licenseServerURLString: licenseURL,
                requestFormat: .binary,
                tokenProvider: { request in
                    // Called fresh on EVERY license request (incl. renewals)
                    // — fetch/refresh a real token here. EZDRM's public KSM
                    // ignores the extra header, so playback still works.
                    let token = "demo-\(Int(Date().timeIntervalSince1970))"
                    await log.add("tokenProvider: issued token for \(request.licenseURL)")
                    return ["X-Demo-Token": token]
                })
        case .multiDrm:
            // The SAME encrypted stream (and keys) the Android and web demos
            // play — FairPlay flavor here, Widevine there. One content
            // pipeline, three platforms, identical DrmKeysLoaded logs.
            drm = FairPlayConfig(
                certificateURLString: axinomCertificateURL,
                licenseServerURLString: axinomLicenseURL,
                licenseHeaders: ["X-AxDRM-Message": axinomToken],
                requestFormat: .binary)
        }
        let isShared = stream == .multiDrm
        guard let drm,
              let item = OGMediaItem(
                  urlString: isShared
                      ? "https://media.axprod.net/TestVectors/Cmaf/protected_1080p_h264_cbcs/manifest.m3u8"
                      : "https://fps.ezdrm.com/demo/video/ezdrm.m3u8",
                  title: isShared ? "Multi-DRM demo (encrypted)" : "FairPlay (EZDRM)",
                  drm: drm)
        else { return }
        player.load(item, autoplay: false)
    }
}

// EZDRM public FairPlay test endpoints (same asset for both chips — only the
// license-request credentials differ).
private let certificateURL = "https://fps.ezdrm.com/demo/video/eleisure.cer"
private let licenseURL =
    "https://fps.ezdrm.com/api/licenses/09cc0377-6dd4-40cb-b09d-b582236e70fe"

// Axinom public multi-DRM test vector — the shared cross-platform DRM demo
// stream (Widevine on Android/web, FairPlay here). Public test credentials.
private let axinomCertificateURL = "https://tools.axinom.com/FPScert/fairplay.cer"
private let axinomLicenseURL = "https://drm-fairplay-licensing.axprod.net/AcquireLicense"
private let axinomToken =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ewogICJ2ZXJzaW9uIjogMSwKICAiY29tX2tleV9pZCI6ICI2OWU1NDA4OC1lOWUwLTQ1MzAtOGMxYS0xZWI2ZGNkMGQxNGUiLAogICJtZXNzYWdlIjogewogICAgInR5cGUiOiAiZW50aXRsZW1lbnRfbWVzc2FnZSIsCiAgICAidmVyc2lvbiI6IDIsCiAgICAibGljZW5zZSI6IHsKICAgICAgImFsbG93X3BlcnNpc3RlbmNlIjogdHJ1ZQogICAgfSwKICAgICJjb250ZW50X2tleXNfc291cmNlIjogewogICAgICAiaW5saW5lIjogWwogICAgICAgIHsKICAgICAgICAgICJpZCI6ICIzMDJmODBkZC00MTFlLTQ4ODYtYmNhNS1iYjFmODAxOGEwMjQiLAogICAgICAgICAgImVuY3J5cHRlZF9rZXkiOiAicm9LQWcwdDdKaTFpNDNmd3YremZ0UT09IiwKICAgICAgICAgICJ1c2FnZV9wb2xpY3kiOiAiUG9saWN5IEEiCiAgICAgICAgfQogICAgICBdCiAgICB9LAogICAgImNvbnRlbnRfa2V5X3VzYWdlX3BvbGljaWVzIjogWwogICAgICB7CiAgICAgICAgIm5hbWUiOiAiUG9saWN5IEEiLAogICAgICAgICJwbGF5cmVhZHkiOiB7CiAgICAgICAgICAibWluX2RldmljZV9zZWN1cml0eV9sZXZlbCI6IDE1MCwKICAgICAgICAgICJwbGF5X2VuYWJsZXJzIjogWwogICAgICAgICAgICAiNzg2NjI3RDgtQzJBNi00NEJFLThGODgtMDhBRTI1NUIwMUE3IgogICAgICAgICAgXQogICAgICAgIH0KICAgICAgfQogICAgXQogIH0KfQ._NfhLVY7S6k8TJDWPeMPhUawhympnrk6WAZHOVjER6M"
