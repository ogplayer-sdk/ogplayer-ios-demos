import SwiftUI
import OGPlayerCore
import OGPlayerUI

/// Custom error messages.
/// The host maps the SDK's stable error codes (2000 network · 3000 source ·
/// 4000 DRM · 5000 renderer · 6000 live · 9000 unknown) to its own copy in any
/// language via `OGUIConfig.errorMessageProvider`. This screen loads
/// a stream URL that doesn't exist, so playback always fails — type
/// a message and reload to see yours on the error overlay. The raw
/// OGPlayerError still reaches onError unchanged.
private let missingStream = "https://media.ogplayer.tv/tos/does-not-exist.m3u8"

/// Bridges the live input text into the @Sendable provider closure.
private final class MessageBox: @unchecked Sendable {
    var text = ""
}

struct ErrorMessagesDemo: View {
    @StateObject private var player = OGPlayer()
    @State private var isFullscreen = false
    @State private var message = ""
    /// Retry demo modes: the SDK button as-is, a relabeled one, or none at
    /// all — the app draws its own button and calls player.retry().
    // 0=SDK, 1=label, 2=none, 3=custom overlay, 4=branded (0.13.1 theming)
    @State private var retryMode =
        ProcessInfo.processInfo.environment["OG_ERR_BRANDED"] == "1" ? 4 : 0
    private let box = MessageBox()

    private var config: OGUIConfig {
        var c = OGUIConfig()
        c.showRetryButton = retryMode != 2
        if retryMode == 1 { c.retryButtonLabel = "Probeer opnieuw" }
        let box = box
        c.errorMessageProvider = { error in
            let text = box.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return text.replacingOccurrences(of: "{code}", with: String(error.code))
        }
        if retryMode == 4 {
            // 0.13.1: the error overlay is themeable — serif text + a blue
            // button prove the SDK look is not baked in.
            c.errorTextFont = .system(size: 16, design: .serif)
            c.errorTextColor = .white
            c.retryButtonBackgroundColor = Color(red: 0.24, green: 0.43, blue: 0.96)
            c.retryButtonForegroundColor = .white
            c.retryButtonFont = .system(size: 14, weight: .semibold, design: .serif)
        }
        return c
    }

    var body: some View {
        Group {
            if isFullscreen {
                // Fullscreen means the player and nothing else.
                OGPlayerView(player: player, isFullscreen: $isFullscreen, config: config,
                             errorOverlay: hostErrorOverlay)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                embedded
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.background.ignoresSafeArea())
        .onChange(of: retryMode) { _, _ in reload() }
        .onAppear {
            box.text = message
            reload()
        }
        .onChange(of: message) { _, newValue in box.text = newValue }
        .onDisappear { player.pause() }
    }

    /// 100% host-owned error UI for the "Custom overlay" mode — deliberately
    /// styled unlike the SDK chrome to make clear whose design language it is.
    private var hostErrorOverlay: ((OGPlayerError, @escaping () -> Void) -> AnyView)? {
        guard retryMode == 3 else { return nil }
        return { error, retry in
            AnyView(
                ZStack {
                    Color(red: 0.07, green: 0.075, blue: 0.09).opacity(0.92)
                    VStack(spacing: 6) {
                        Text("😕").font(.largeTitle)
                        Text("Something broke on our side")
                            .font(.headline).foregroundColor(.white)
                        Text("Error \(error.code) — and this whole panel is the demo app's UI.")
                            .font(.footnote).foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Button(action: retry) {
                            Text("Try again").fontWeight(.semibold)
                                .padding(.horizontal, 22).padding(.vertical, 9)
                                .background(Color(red: 0.96, green: 0.77, blue: 0.27))
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                    .padding(26)
                    .background(RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.114, green: 0.122, blue: 0.141)))
                }
            )
        }
    }

    private var embedded: some View {
        VStack(spacing: 0) {
            OGPlayerView(player: player, isFullscreen: $isFullscreen, config: config,
                         errorOverlay: hostErrorOverlay)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                TextField("Your error message ({code} = error code)", text: $message)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                Button("Reload") { reload() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.96, green: 0.77, blue: 0.27))
                    .foregroundColor(.black)
            }
            .padding(12)
            HStack(spacing: 8) {
                chip("SDK Retry", selected: retryMode == 0) { retryMode = 0 }
                chip("Custom label", selected: retryMode == 1) { retryMode = 1 }
                chip("No retry button", selected: retryMode == 2) { retryMode = 2 }
                chip("Custom overlay", selected: retryMode == 3) { retryMode = 3 }
                chip("Branded style", selected: retryMode == 4) { retryMode = 4 }
            }
            .padding(.horizontal, 12)
            Text(retryMode == 3
                ? "errorOverlay slot — the panel is 100% app UI, rendered by the "
                    + "SDK on the player surface with the error and retry() handed in."
                : retryMode == 2
                ? "showRetryButton = false — the overlay shows only your message; "
                    + "recovery is your app's call."
                : retryMode == 1
                ? "config.retryButtonLabel = \"Probeer opnieuw\" — the SDK's Retry "
                    + "button, your text, any language."
                : "This screen loads a missing stream URL, so it always fails — your "
                    + "text (any language) replaces the SDK's default error overlay "
                    + "via errorMessageProvider.")
                .font(.footnote)
                .foregroundColor(Ink.description)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 18)
            Spacer()
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

    private func reload() {
        box.text = message
        if let item = OGMediaItem(urlString: missingStream, title: "Custom error demo") {
            player.load(item)
        }
    }
}
