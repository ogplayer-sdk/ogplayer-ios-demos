// OGplayer FreeWheel adapter — ships as SOURCE, not as a package product.
//
// NOTE FOR DEVELOPERS: FreeWheel's AdManager SDK (AdManager.framework) is
// licensed to FreeWheel customers, so OGplayer cannot bundle it — and Swift
// Package Manager cannot compile a target against a framework it isn't
// allowed to ship (there is no `compileOnly` like on Android, where the
// equivalent provider is the published `ogplayer-ads-freewheel` module).
// This adapter is therefore distributed as a source file:
//
//  1. Obtain AdManager.framework from your FreeWheel account (MRM support
//     portal or your FreeWheel account manager).
//  2. Add the framework to your app target (link + embed; device builds
//     only — FreeWheel ships no simulator slice).
//  3. Copy THIS FILE into your app target.
//  4. Set it on the player and pass a `FreewheelConfig` per item:
//     `player.adsProvider = FWAdsProvider()`
//     `OGMediaItem(urlString: url, adBreaks: FreewheelConfig(...))`
//
// The file is gated on canImport(AdManager): in builds without the
// framework (e.g. simulator) it compiles to nothing.
#if canImport(AdManager)
import UIKit
import AVFoundation
import AdManager
import OGPlayerCore

/// FreeWheel AdManager implementation of the OGplayer ads SPI.
///
/// Set it on the player and pass a `FreewheelConfig` as the item's ad breaks:
///
/// ```swift
/// player.adsProvider = FWAdsProvider()
/// let item = OGMediaItem(urlString: url, adBreaks: FreewheelConfig(...))
/// ```
///
/// The SDK owns the complete ad UI (yellow bar, countdown, transport);
/// FreeWheel renders only the ad media itself into the player's ad container.
/// Slot scheduling is driven here: prerolls before content, midrolls off a
/// periodic playhead check (with seek catch-up), postrolls on content end.
@MainActor
final class FWAdsProvider: NSObject, AdsProvider {

    private weak var player: AVPlayer?
    private weak var adContainer: UIView?
    private weak var callbacks: AdsProviderCallbacks?

    private var adManager: FWAdManager?
    private var adContext: FWContext?
    private var config: FreewheelConfig?

    // Slot queues, filled when the request completes.
    private var prerollSlots: [FWSlot] = []
    private var midrollSlots: [FWSlot] = []
    private var postrollSlots: [FWSlot] = []

    private var currentSlot: FWSlot?
    private var currentBreakType: AdBreakType = .preroll
    private var podSize = 0
    private var adIndexInPod = 0
    private var lastAd: AdInfo?

    /// Whether a loaded preroll may start on its own (content autoplay); a
    /// held preroll starts via `startPendingBreak()`.
    private var autostart = true
    private var heldPreroll = false

    private var playErrorsInSlot = 0
    private var slotWatchdog: Task<Void, Never>?

    private var notificationTokens: [NSObjectProtocol] = []
    private var timeObserver: Any?
    private var lastPositionS: Double = 0
    private var backgroundTokens: [NSObjectProtocol] = []
    private var pausedForBackground = false

    // MARK: AdsProvider

    func attach(player: AVPlayer, adContainer: UIView,
                viewController: UIViewController?, callbacks: AdsProviderCallbacks) {
        self.player = player
        self.adContainer = adContainer
        self.callbacks = callbacks

        // FreeWheel has no VMAP timeline: midrolls trigger off the content
        // playhead, checked twice a second.
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 2), queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.checkForMidroll(at: time.seconds)
            }
        }
    }

    func requestAds(_ config: any AdBreakConfig, autostart: Bool) {
        self.autostart = autostart
        // Same contract as the other providers: a config type this provider
        // doesn't understand is reported and content plays ad-free.
        guard let fw = config as? FreewheelConfig else {
            callbacks?.onAdError(OGAdError(
                code: 900, phase: .load,
                message: "FWAdsProvider received \(type(of: config)); expected FreewheelConfig"))
            callbacks?.onContentResumeRequested()
            return
        }
        guard let container = adContainer else { return }
        self.config = fw

        guard let manager = newAdManager(), let context = manager.newContext() else {
            callbacks?.onAdError(OGAdError(
                code: 902, phase: .load, message: "FreeWheel AdManager failed to initialize"))
            callbacks?.onContentResumeRequested()
            return
        }
        manager.setNetworkId(UInt(fw.networkId))
        context.setVideoDisplayBase(container)
        // Renderer start timeout: how long FW waits for a creative's first
        // frame before erroring out (the provider's watchdog sits just above
        // this window).
        context.setParameter("renderer.video.timeoutMillisecondsBeforeStart",
                             withValue: String(fw.adStartTimeoutMs), for: .global)
        self.adManager = manager
        self.adContext = context

        let request = FWRequestConfiguration(
            serverURL: fw.serverURL,
            playerProfile: fw.profile,
            playerDimensions: CGSize(width: fw.requestWidthPx, height: fw.requestHeightPx))
        request.videoAssetConfiguration = FWVideoAssetConfiguration(
            videoAssetId: fw.videoAssetId,
            idType: .custom,
            duration: Double(fw.videoDurationMs) / 1000.0,
            durationType: .exact,
            autoPlayType: .attended)
        request.siteSectionConfiguration = FWSiteSectionConfiguration(
            siteSectionId: fw.siteSectionId, idType: .custom)

        // The provider adds only the per-request randomizers; every consent /
        // identity parameter comes from the host verbatim.
        request.addValue(String(Int.random(in: 0..<1_000_000_000)), forKey: "pvrn")
        request.addValue(String(Int.random(in: 0..<1_000_000_000)), forKey: "vprn")
        for (key, value) in fw.globalParameters {
            request.addValue(value, forKey: key)
        }

        registerNotifications(for: context)
        registerBackgroundHandling(pause: fw.pauseAdsWhenBackgrounded)
        context.submitRequest(with: request, timeout: Double(fw.requestTimeoutMs) / 1000.0)
    }

    func startPendingBreak() -> Bool {
        guard heldPreroll, let slot = prerollSlots.first else { return false }
        heldPreroll = false
        prerollSlots.removeFirst()
        play(slot: slot, breakType: .preroll)
        return true
    }

    func contentDidComplete() {
        adContext?.setVideoState(.completed)
        guard currentSlot == nil, !postrollSlots.isEmpty else { return }
        let slot = postrollSlots.removeFirst()
        play(slot: slot, breakType: .postroll)
    }

    func pause() {
        guard let slot = currentSlot else { return }
        slot.pause()
        if let ad = lastAd { callbacks?.onAdPaused(ad) }
    }

    func resume() {
        guard let slot = currentSlot else { return }
        slot.resume()
        if let ad = lastAd { callbacks?.onAdResumed(ad) }
    }

    func skip() {
        // FreeWheel completes the impression and ends the slot on its own
        // after a programmatic skip.
        currentSlot?.skipCurrentAd()
    }

    func click() {
        // The SDK's "Learn more" routes here; FreeWheel opens the clickthrough
        // (and fires the click beacon) through the ad's renderer controller.
        guard let instance = currentSlot?.currentAdInstance(),
              let renderer = instance.rendererController() else { return }
        renderer.processEvent(FWAdClickEvent, info: nil)
    }

    func destroy() {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
        notificationTokens = []
        backgroundTokens.forEach(NotificationCenter.default.removeObserver)
        backgroundTokens = []
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        timeObserver = nil
        slotWatchdog?.cancel()
        slotWatchdog = nil
        playErrorsInSlot = 0
        adContext?.setVideoState(.stopped)
        adContext = nil
        adManager = nil
        config = nil
        prerollSlots = []
        midrollSlots = []
        postrollSlots = []
        currentSlot = nil
        lastAd = nil
        heldPreroll = false
        autostart = true
        pausedForBackground = false
        lastPositionS = 0
    }

    // MARK: Slot scheduling

    private func play(slot: FWSlot, breakType: AdBreakType) {
        currentSlot = slot
        currentBreakType = breakType
        podSize = slot.adInstances()?.count ?? 0
        adIndexInPod = 0
        playErrorsInSlot = 0
        armWatchdog()
        callbacks?.onContentPauseRequested()
        adContext?.setVideoState(.paused)
        callbacks?.onAdBreakStarted(breakType, totalAds: podSize)
        slot.play()
    }

    private func checkForMidroll(at positionS: Double) {
        guard let cfg = config, currentSlot == nil, !midrollSlots.isEmpty,
              positionS.isFinite else { return }
        defer { lastPositionS = positionS }

        let toleranceS = Double(cfg.midrollToleranceMs) / 1000.0
        let seekThresholdS = Double(cfg.seekThresholdMs) / 1000.0

        // Seek catch-up: a jump past one or more cues plays what the policy says.
        if positionS - lastPositionS > seekThresholdS {
            let crossed = midrollSlots.filter {
                $0.timePosition() > lastPositionS && $0.timePosition() <= positionS
            }
            guard !crossed.isEmpty else { return }
            midrollSlots.removeAll { slot in crossed.contains { $0 === slot } }
            switch cfg.seekCatchUpPolicy {
            case .none:
                return
            case .mostRecent:
                if let latest = crossed.max(by: { $0.timePosition() < $1.timePosition() }) {
                    play(slot: latest, breakType: .midroll)
                }
            case .allMostRecentFirst:
                // Play the most recent now; queue the rest back, most recent
                // first, to chain when the slot ends.
                let ordered = crossed.sorted { $0.timePosition() > $1.timePosition() }
                if let first = ordered.first {
                    midrollSlots.insert(contentsOf: ordered.dropFirst(), at: 0)
                    play(slot: first, breakType: .midroll)
                }
            }
            return
        }

        // Natural playback reaching a cue.
        if let index = midrollSlots.firstIndex(where: { abs($0.timePosition() - positionS) <= toleranceS }) {
            let slot = midrollSlots.remove(at: index)
            play(slot: slot, breakType: .midroll)
        }
    }

    // MARK: FreeWheel notifications

    private func registerNotifications(for context: FWContext) {
        func observe(_ name: Notification.Name, _ handler: @escaping @MainActor (Notification) -> Void) {
            let token = NotificationCenter.default.addObserver(
                forName: name, object: context, queue: .main
            ) { note in
                MainActor.assumeIsolated { handler(note) }
            }
            notificationTokens.append(token)
        }
        observe(NSNotification.Name.FWRequestComplete) { [weak self] in self?.onRequestComplete($0) }
        observe(NSNotification.Name.FWSlotEnded) { [weak self] in self?.onSlotEnded($0) }
        observe(NSNotification.Name.FWAdEvent) { [weak self] in self?.onAdEvent($0) }
        // Content pause/resume are driven explicitly at slot boundaries, so
        // FreeWheel's advisory notifications need no handlers here.
    }

    private func onRequestComplete(_ notification: Notification) {
        if let error = notification.userInfo?[FWInfoKeyError] {
            callbacks?.onAdError(OGAdError(
                code: 901, phase: .load, message: "FreeWheel request failed: \(error)"))
            callbacks?.onContentResumeRequested()
            return
        }
        func slots(_ raw: UInt) -> [FWSlot] {
            (adContext?.getSlotsBy(FWTimePositionClass(rawValue: raw)!) ?? [])
                .compactMap { $0 as? FWSlot }
        }
        prerollSlots = slots(1)
        midrollSlots = slots(2).sorted { $0.timePosition() < $1.timePosition() }
        postrollSlots = slots(3)

        // Cue markers: prerolls at 0, midrolls at their positions, postroll as
        // the negative end-of-content sentinel.
        var cues: [Double] = prerollSlots.isEmpty ? [] : [0]
        cues += midrollSlots.map { $0.timePosition() }
        if !postrollSlots.isEmpty { cues.append(-1) }
        callbacks?.onAdCuePoints(cues)

        if prerollSlots.isEmpty {
            callbacks?.onContentResumeRequested()
        } else if autostart {
            let slot = prerollSlots.removeFirst()
            play(slot: slot, breakType: .preroll)
        } else {
            // A paused load holds the break until play() starts it.
            heldPreroll = true
        }
    }

    private func onSlotEnded(_ notification: Notification) {
        guard currentSlot != nil else { return }
        slotWatchdog?.cancel()
        slotWatchdog = nil
        if let ad = lastAd { callbacks?.onAdCompleted(ad); lastAd = nil }
        currentSlot = nil
        advanceAfterSlot(currentBreakType)
    }

    /// Ends the finished break, then chains the next queued slot or hands
    /// playback back to content. Every slot is its own break, so completed
    /// always fires here — balancing the started fired in `play(slot:)`.
    private func advanceAfterSlot(_ breakType: AdBreakType) {
        callbacks?.onAdBreakCompleted(breakType)
        switch breakType {
        case .preroll where !prerollSlots.isEmpty:
            play(slot: prerollSlots.removeFirst(), breakType: .preroll)
        case .midroll where !midrollSlots.isEmpty && midrollSlots[0].timePosition() <= lastPositionS:
            // Seek catch-up queued another crossed midroll — chain it.
            play(slot: midrollSlots.removeFirst(), breakType: .midroll)
        case .postroll where !postrollSlots.isEmpty:
            play(slot: postrollSlots.removeFirst(), breakType: .postroll)
        default:
            callbacks?.onContentResumeRequested()
            adContext?.setVideoState(.playing)
        }
    }

    /// A slot whose renderer produces no NEW impression within one
    /// renderer-timeout window (plus slack) is dead: FW goes silent after
    /// its last instance fails — no slot-ended, ever. Armed at play,
    /// re-armed per FW error, cancelled by an impression.
    private func armWatchdog() {
        slotWatchdog?.cancel()
        let impressionsAtArm = adIndexInPod
        let windowMs = (config?.adStartTimeoutMs ?? 10_000) + 2_000
        slotWatchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(windowMs) * 1_000_000)
            guard let self, !Task.isCancelled, let slot = self.currentSlot,
                  self.adIndexInPod == impressionsAtArm, self.lastAd == nil else { return }
            self.abandonSlot(slot, reason: "no ad rendered within \(windowMs)ms")
        }
    }

    private func abandonSlot(_ slot: FWSlot, reason: String) {
        slotWatchdog?.cancel()
        slotWatchdog = nil
        callbacks?.onAdError(OGAdError(code: 405, phase: .play,
                                       message: "FreeWheel slot abandoned: \(reason)"))
        slot.stop()
        currentSlot = nil
        lastAd = nil
        advanceAfterSlot(currentBreakType)
    }

    private func onAdEvent(_ notification: Notification) {
        guard let eventName = notification.userInfo?[FWInfoKeyAdEventName] as? String else { return }
        switch eventName {
        case FWAdImpressionEvent:
            // Fires when the renderer actually starts the ad — not at the
            // playback ATTEMPT (pre-init). Until this, the SDK shows its
            // buffering ring, so a stalled creative reads as loading rather
            // than frozen.
            guard currentSlot != nil,
                  let instance = notification.userInfo?[FWInfoKeyAdInstance] as? FWAdInstance
            else { return }
            slotWatchdog?.cancel()
            slotWatchdog = nil
            // A new impression ends the previous ad in the pod (safety net;
            // impression-end normally reported it already).
            if let prev = lastAd { callbacks?.onAdCompleted(prev); lastAd = nil }
            adIndexInPod += 1
            var durationMs = Int64((instance.duration()) * 1000)
            if durationMs <= 0 { durationMs = config?.fallbackAdDurationMs ?? 15_000 }
            let clickURL = (instance.getEventCallbackUrls(
                byEventName: FWAdClickEvent, eventType: FWEventTypeClick) as? [String])?.first
            let info = AdInfo(
                adId: String(instance.adId()),
                positionInPod: adIndexInPod,
                podSize: max(podSize, adIndexInPod),
                breakType: currentBreakType,
                isSkippable: false,
                skipOffsetMs: -1,
                durationMs: durationMs,
                clickThroughURL: clickURL,
                providerRendersUI: false)
            lastAd = info
            callbacks?.onAdStarted(info)
        case FWAdImpressionEndEvent:
            if let ad = lastAd { callbacks?.onAdCompleted(ad); lastAd = nil }
        case FWAdErrorEvent:
            guard let slot = currentSlot else { return }
            let codeStr = (notification.userInfo?[FWInfoKeyErrorCode] as? String) ?? ""
            let info = (notification.userInfo?[FWInfoKeyErrorInfo] as? String) ?? "FreeWheel ad error"
            let mapped = codeStr.uppercased().contains("TIMEOUT") ? 301 : 402
            callbacks?.onAdError(OGAdError(code: mapped, phase: .play,
                                           message: "\(codeStr): \(info)"))
            // Pre-render failure: FW advances to its next instance on its
            // own, but goes silent after the LAST one — abandon once every
            // instance has failed without a render, else give the next
            // instance a fresh watchdog window.
            guard lastAd == nil else { return }
            playErrorsInSlot += 1
            if adIndexInPod == 0, podSize > 0, playErrorsInSlot >= podSize {
                abandonSlot(slot, reason: "all \(podSize) ad instances failed before rendering")
            } else {
                armWatchdog()
            }
        default:
            break
        }
    }

    // MARK: Backgrounding

    private func registerBackgroundHandling(pause: Bool) {
        guard pause, backgroundTokens.isEmpty else { return }
        func observe(_ name: Notification.Name, _ handler: @escaping @MainActor () -> Void) {
            let token = NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { _ in MainActor.assumeIsolated { handler() } }
            backgroundTokens.append(token)
        }
        observe(UIApplication.didEnterBackgroundNotification) { [weak self] in
            guard let self, self.currentSlot != nil else { return }
            self.pausedForBackground = true
            self.pause()
        }
        observe(UIApplication.willEnterForegroundNotification) { [weak self] in
            guard let self, self.pausedForBackground else { return }
            self.pausedForBackground = false
            self.resume()
        }
    }
}
#endif
