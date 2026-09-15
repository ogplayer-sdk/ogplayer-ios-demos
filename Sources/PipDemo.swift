import SwiftUI
import OGPlayerCore
import OGPlayerUI

/// Picture-in-picture: no button anywhere — the developer decides.
/// `pipEnabled: true` is the switch; leaving the app (Home / app switch)
/// while playing auto-enters PiP, and "back to app" runs through the
/// restore hook (logged, completes immediately here). Host requirement:
/// `UIBackgroundModes: audio` in Info.plist.
struct PipDemo: View {
    @StateObject private var player = OGPlayer()
    @StateObject private var log = EventLogState()
    @State private var pipActive = false
    @State private var autoEnter = true
    @State private var logger: EventLogger?

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                OGPlayerView(player: player,
                             pipEnabled: true,
                             isPipActive: $pipActive,
                             autoEnterPipOnBackground: autoEnter,
                             onPipRestoreUserInterface: { complete in
                                 log.add("pip: restore user interface")
                                 complete()
                             })
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.width * 9 / 16)
                controls
                EventLogView(log: log).frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.background.ignoresSafeArea())
        .onChange(of: pipActive) { _, active in
            log.add("pip: \(active ? "entered" : "exited")")
        }
        .onAppear {
            if logger == nil { logger = attachEventLogging(player, to: log, includeProgress: false) }
            guard let item = OGMediaItem(
                urlString: "https://demo.unified-streaming.com/k8s/features/stable/video/"
                    + "tears-of-steel/tears-of-steel.ism/.m3u8",
                title: "Tears of Steel"
            ) else { return }
            player.load(item, autoplay: true)
        }
        .onDisappear { player.pause() }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                Button(action: { autoEnter.toggle() }) {
                    HStack(spacing: 8) {
                        Image(systemName: autoEnter ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundStyle(autoEnter ? Ink.accent : Ink.description)
                        Text("Auto-enter on leave")
                            .font(.system(size: 15)).foregroundStyle(Ink.title)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Text("Press Home (or swipe up) while playing — PiP enters "
                 + "automatically. The in-app surface shows a status layer while "
                 + "the little window plays; \"back to app\" runs the restore "
                 + "hook — all logged below.")
                .font(.system(size: 12)).foregroundStyle(Ink.description)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}
