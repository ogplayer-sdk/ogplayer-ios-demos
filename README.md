# OGPlayer — iOS demo app

Integration demos for the [OGPlayer](https://ogplayer.tv) iOS SDK: VOD,
live & DVR, FairPlay DRM, Google IMA ads, subtitles & audio tracks, AirPlay,
content ratings, watermarks, custom error handling — each demo is a small,
readable SwiftUI screen you can lift code from.

## Run it

Open `OGPlayerDemos.xcodeproj` in Xcode and press Run. The SDK resolves from
Swift Package Manager automatically:

```
https://github.com/ogplayer-sdk/ogplayer-swift
```

Requires iOS 18+ · Xcode 16+. For a physical device, select your signing
team (Signing & Capabilities), or regenerate the project with
`DEVELOPMENT_TEAM=<your team id> xcodegen generate`.

Docs: https://ogplayer.tv/docs · Live web demo: https://ogplayer.tv

## Notes

- **FreeWheel:** FreeWheel's AdManager SDK is licensed to FreeWheel
  customers and not bundled — the FreeWheel demo shows setup steps until
  you add your `AdManager.framework` to the project and fill in
  `Sources/DemoFwConfig.swift`. The OGPlayer adapter it uses is vendored in
  `FreeWheelAdapter/` (the canonical copy ships with the SDK package).
- **Licensing:** this demo code is MIT. The OGPlayer SDK itself is a
  commercial product — free to evaluate with a watermark; production use
  requires a license. See https://ogplayer.tv/terms/
- **Read-only repository:** issues and pull requests are closed —
  questions and reports are welcome at hello@ogplayer.tv.

Demo content: Tears of Steel — (CC) Blender Foundation · mango.blender.org
