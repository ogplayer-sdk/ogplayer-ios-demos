import SwiftUI
import OGPlayerCore

/// Terminal-style event log: a rolling buffer of timestamped lines rendered
/// as green monospace on a near-black panel, auto-tailing as events stream in.

/// Rolling buffer of log lines (`HH:mm:ss.SSS` + two spaces + message), capped
/// at 300 entries (oldest dropped first).
@MainActor
final class EventLogState: ObservableObject {
    @Published private(set) var entries: [String] = []
    /// Monotonic count of every line ever added. Drives auto-tail and row
    /// identity: `entries.count` pins at the cap (300) once old lines drop,
    /// which would silently stop a count-based onChange and recycle row IDs.
    @Published private(set) var total = 0
    private static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func clear() { entries.removeAll() }

    func add(_ message: String) {
        entries.append("\(Self.timeFormat.string(from: Date()))  \(message)")
        total += 1
        if entries.count > 300 { entries.removeFirst() }
    }
}

/// Registers on an `OGPlayer` and turns every playback, analytics and ad
/// callback into a formatted log line — wire it up with the
/// `attachEventLogging` / `attachAdEventLogging` helpers below.
@MainActor
final class EventLogger: PlaybackListener, OGAnalyticsListener, AdListener {
    private let log: EventLogState
    private let includeProgress: Bool
    private var lastProgressSecond: Int64 = -1
    private var lastAdProgressBucket: Int64 = -1

    init(log: EventLogState, includeProgress: Bool) {
        self.log = log
        self.includeProgress = includeProgress
    }

    // MARK: PlaybackListener
    func onStateChanged(_ state: PlaybackState) { log.add("onStateChanged: \(state)") }
    func onIsPlayingChanged(_ isPlaying: Bool) { log.add("onIsPlayingChanged: \(isPlaying)") }
    func onPlay() { log.add("onPlay") }
    func onPause() { log.add("onPause") }
    func onResume() { log.add("onResume") }
    func onSeekStarted(fromMs: Int64, toMs: Int64) { log.add("onSeekStarted: \(fromMs / 1000)s -> \(toMs / 1000)s") }
    func onSeekCompleted(positionMs: Int64) { log.add("onSeekCompleted: \(positionMs / 1000)s") }
    func onPlaybackCompleted() { log.add("onPlaybackCompleted") }
    func onError(_ error: OGPlayerError) { log.add("onError: \(error)") }
    func onDrmSessionRenewed(_ reason: DrmRenewalReason) { log.add("onDrmSessionRenewed: \(reason)") }
    func onLiveEdgeChanged(atLiveEdge: Bool) { log.add("onLiveEdgeChanged: \(atLiveEdge)") }
    func onProgress(positionMs: Int64, bufferedMs: Int64, durationMs: Int64) {
        guard includeProgress else { return }
        // Throttle to once per whole second.
        let second = positionMs / 1000
        guard second != lastProgressSecond else { return }
        lastProgressSecond = second
        log.add("onProgress: \(second)s / \(durationMs / 1000)s (buffered \(bufferedMs / 1000)s)")
    }

    // MARK: OGAnalyticsListener
    func onEvent(_ event: AnalyticsEvent) { log.add("analytics: \(event)") }

    // MARK: AdListener
    func onAdBreakStarted(_ breakType: AdBreakType, totalAds: Int) {
        log.add("onAdBreakStarted: \(breakType), \(totalAds) ads")
    }
    func onAdStarted(_ ad: AdInfo) { log.add("onAdStarted: \(ad)") }
    func onAdSkipped(_ ad: AdInfo) { log.add("onAdSkipped: \(ad.adId)") }
    func onAdPaused(_ ad: AdInfo) { log.add("onAdPaused: \(ad.adId)") }
    func onAdResumed(_ ad: AdInfo) { log.add("onAdResumed: \(ad.adId)") }
    func onAdCompleted(_ ad: AdInfo) { log.add("onAdCompleted: \(ad.adId)") }
    func onAdBreakCompleted(_ breakType: AdBreakType) { log.add("onAdBreakCompleted: \(breakType)") }
    func onAdProgress(_ ad: AdInfo, positionMs: Int64, durationMs: Int64) {
        // Throttle to one line per 2 seconds of ad playback.
        let bucket = positionMs / 2000
        guard bucket != lastAdProgressBucket else { return }
        lastAdProgressBucket = bucket
        log.add("onAdProgress: \(positionMs)ms / \(durationMs)ms (\(ad.adId))")
    }
    func onAdSkippableStateChanged(_ ad: AdInfo, isSkippable: Bool, skipOffsetMs: Int64) {
        log.add("onAdSkippableStateChanged: \(isSkippable) @\(skipOffsetMs)ms")
    }
    func onAdError(_ error: OGAdError) { log.add("onAdError: \(error)") }
}

/// Create an `EventLogger`, register it for playback + analytics callbacks, and
/// return it (the player retains it while registered).
@MainActor
func attachEventLogging(_ player: OGPlayer, to log: EventLogState,
                        includeProgress: Bool = true) -> EventLogger {
    let logger = EventLogger(log: log, includeProgress: includeProgress)
    player.addListener(logger)
    player.addAnalyticsListener(logger)
    return logger
}

/// Register an `EventLogger` for ad callbacks. Returns the logger so the
/// caller retains it.
@MainActor
func attachAdEventLogging(_ player: OGPlayer, to log: EventLogState) -> EventLogger {
    let logger = EventLogger(log: log, includeProgress: false)
    player.addAdListener(logger)
    return logger
}

/// The green-on-black, auto-tailing log panel.
struct EventLogView: View {
    @ObservedObject var log: EventLogState

    private let background = Color(red: 0x10 / 255, green: 0x14 / 255, blue: 0x18 / 255)
    private let text = Color(red: 0x9C / 255, green: 0xCC / 255, blue: 0x65 / 255)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Absolute line numbers as IDs: stable per line even after the
                // buffer starts dropping its head at the cap.
                let base = log.total - log.entries.count
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(log.entries.enumerated()), id: \.offset) { index, entry in
                        Text(entry)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(base + index)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(background)
            .onChange(of: log.total) { _, total in
                guard total > 0 else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(total - 1, anchor: .bottom)
                }
            }
        }
    }
}
