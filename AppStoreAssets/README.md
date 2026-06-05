# App Store Screenshot Asset Guide (v1.4+)

Status: Actual App Store screenshot images are not committed in this workstream.
This folder only stores the specification and expected filenames so the screenshot workflow can be reproduced consistently.

## Screenshot source and layout

- Keep source screenshots in `AppStoreAssets/source/` and provide local paths for review.
- Prefer **PNG** exports only, with no decorative overlays or watermark.
- One screenshot should be captured per required scene and device family before packaging.

## Recommended portrait sizes

- iPhone 6.7": `1284x2778` (recommended) and/or `1290x2796`
- iPhone 6.5": `1242x2688`
- iPhone 5.5": `1242x2208`
- iPad 12.9" / 11" (portrait): `2732x2048` and `2388x1668`

## Naming convention

Use stable names to keep export scripts deterministic:

`v1.4.{scene}.{device}.{format}.png`

- `v1.4`: App version tag used in current PR
- `scene`: `single-tone`, `sweep`, `noise`, `preset-pack`, `calibration-report`, `settings-privacy`
- `device`: `iphone_6.7`, `iphone_6.5`, `ipados`
- `format`: `source` for capture file, `final` for App Store review submission

## Required scene list for 1.4 and later

- `single-tone` — single tone signal generation screen (core differentiator)
- `sweep` — sweep generation and parameter controls
- `noise` — noise source controls and playback state
- `preset-pack` — built-in preset or preset pack browsing and one-tap use
- `calibration-report` — calibration workflow result/report page
- `settings-privacy` — settings page that shows support/privacy access

## Placeholder checklist

No placeholder images are generated in this repo. Track the real captures manually:

- [ ] `v1.4.single-tone.iphone_6.7.source.png`
- [ ] `v1.4.sweep.iphone_6.7.source.png`
- [ ] `v1.4.noise.iphone_6.7.source.png`
- [ ] `v1.4.preset-pack.iphone_6.7.source.png`
- [ ] `v1.4.calibration-report.iphone_6.7.source.png`
- [ ] `v1.4.settings-privacy.iphone_6.7.source.png`
