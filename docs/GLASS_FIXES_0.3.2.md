# Glass and interaction corrections — 0.3.2

The device screenshots from 0.3.1 showed pale material around an entire footer (including its home-indicator inset) and a disconnected transport-panel box. The material was a noninteractive background UIView; Flutter controls did not acquire UIKit control animations just by being drawn above it.

## Changes

- Restrict native material to the 54-point navigation strip; keep safe areas, the mini player, transport panel and content sheets outside it. Preserve content reservation above the dock.
- Clear UIGlassEffect over an explicit dark/light legibility layer; solid fallback while Reduce Transparency is enabled. Update on accessibility changes. Native platform views are recreated when app brightness changes, so their construction-time appearance cannot become stale.
- Animate selection between tabs without sliding peer screens. Rapid retargeting starts from the current indicator position. Use short transport-icon and pause/resume cover transitions, plus a fade when the track changes. Reduce Motion settles these changes immediately. A rapid A → B → A skip regression keeps one Hero alive while the images fade inside it. No continuous simulated artwork wiggle or generated artwork video.
- Rename switches and explain that video artwork plays locally attached clips. YouTube/JioSaavn still images do not become animated just by enabling the option.

## Verification

Widget regressions exercise enabled glass bounds and home-indicator exclusion, actual intermediate selection/playback frames, rapid retargeting, theme recreation, no-clip still fallback and Reduce Motion. Headless renders use fictional tracks and placeholder covers. The native platform surface is mocked in those tests; its optical material is not proven by the renders.

Local validation: 219 deterministic tests passed, analysis reported no issues, and native cover, branding and packaged-material source guards passed. Swift syntax parsing also passed.

This host has Command Line Tools but no full Xcode or iOS Simulator. CI validates native compilation and packaging. Device checks remain necessary for material compositing, accessibility appearance and frame pacing.

References: [Apple materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials), [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/), [UIGlassEffect interactive behavior](https://developer.apple.com/documentation/uikit/uiglasseffect/isinteractive).

## Published artifact

[Native build 39439105251](https://github.com/Voryn-Labs/Musyn/actions/runs/39439105251) passed analysis, tests, iOS compilation, packaging and publication. Downloaded and verified the regular public 0.3.2 (14) IPA: 12,252,212 bytes, SHA-256 `f9230b64fd6b8821e83dbedecdd5f5942d4a2797e56a14ad762581c1d055cdf4`, bundle `com.vorynlabs.musyn`, display name Musyn, iOS 15 minimum. The packaged credential scan and generated installer metadata checks passed. The shared source update was triggered manually: [39447370076](https://github.com/Voryn-Labs/Voryn-Labs.github.io/actions/runs/39447370076). Native material optics and device frame pacing remain unverified here.
