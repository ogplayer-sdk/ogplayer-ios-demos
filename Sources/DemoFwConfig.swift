import UIKit
import OGPlayerCore

/// FreeWheel demo configuration — fill in with YOUR network's values.
///
/// Everything below comes from your FreeWheel (MRM) account; your FreeWheel
/// account manager can provide all of it:
///
///  - **Network id** — your MRM network id (a number).
///  - **Ad server URL** — your network's ad server including the request
///    path, e.g. `https://<hash>.v.fwmrm.net/ad/p/1`.
///  - **Player profile** — usually `<networkId>:<profile_name>`, one per
///    platform (FreeWheel provisions e.g. `..._ios_live`).
///  - **Site section id** — the placement of this player in your app, as
///    registered in MRM.
///  - **Video asset id** — the content's id as ingested in MRM; ad rules
///    (pre/mid/postroll schedule) are configured against it, and its exact
///    duration must be passed so midroll positions resolve.
///
/// Consent & identity parameters (`_fw_gdpr`, `_fw_gdpr_consent`,
/// `_fw_did_idfa`, custom key-values…) are the app's responsibility and go
/// into `globalParameters` verbatim — OGPlayer never fabricates consent or
/// device identifiers. The provider adds only `pvrn`/`vprn` randomizers.
enum DemoFwConfig {

    private static let networkId = 0 /* put your FreeWheel network id here */
    private static let serverURL = "" /* put your ad server URL here */
    private static let profile = "" /* put your player profile here */
    private static let siteSectionId = "" /* put your site section id here */
    private static let videoAssetId = "" /* put your MRM video asset id here */

    /// Exact duration (ms) of the asset behind `videoAssetId`.
    private static let videoDurationMs: Int64 = 0 /* put your asset duration here */

    /// True once the placeholders above have been filled in.
    static var isConfigured: Bool {
        networkId > 0 && !serverURL.isEmpty && !profile.isEmpty
            && !siteSectionId.isEmpty && !videoAssetId.isEmpty && videoDurationMs > 0
    }

    static func build() -> FreewheelConfig {
        FreewheelConfig(
            serverURL: serverURL,
            networkId: networkId,
            profile: profile,
            siteSectionId: siteSectionId,
            videoAssetId: videoAssetId,
            videoDurationMs: videoDurationMs,
            /* put your consent / identity / targeting key-values here, e.g.:
               globalParameters: [
                   "_fw_gdpr": "1",
                   "_fw_gdpr_consent": "<your TCF consent string>",
                   "_fw_did_idfa": "<IDFA, or empty without ATT consent>",
               ] */
            globalParameters: [:])
    }
}
