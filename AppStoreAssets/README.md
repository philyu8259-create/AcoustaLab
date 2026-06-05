# App Store Screenshot Asset Guide (v1.5 ASO)

Status: The v1.5 ASO screenshot assets are committed here so App Store Connect
uploads can be reproduced consistently.

## Screenshot source and layout

- `source/asc/` contains the current App Store Connect screenshots downloaded
  from Apple CDN as source material.
- `final-premium/` contains the upload-ready v1.5 ASO screenshots.
- Prefer **PNG** exports only, with no watermark.

## Recommended portrait sizes

- iPhone 6.7": `1284x2778` (recommended) and/or `1290x2796`
- iPhone 6.5": `1242x2688`
- iPhone 5.5": `1242x2208`
- iPad 12.9" / 11" (portrait): `2732x2048` and `2388x1668`

## Naming convention

Use stable names to keep upload order deterministic:

`{locale}-{index}-{scene}.png`

- `locale`: `zh` or `en`
- `index`: display order in App Store Connect
- `scene`: short ASO scene label

## v1.5 ASO scene order

- `01-speaker-test` — speaker/audio test value proposition
- `02-sweep` — sweep testing and abnormal frequency positioning
- `03-noise` — white/pink noise environment checks
- `04-report` — calibration report export from the Settings calibration card
- `05-privacy` — local processing and privacy reassurance
- `06-presets` — one-click built-in test presets

## Current ASO copy

Chinese:

- App name: `声测工坊-音频测试工具`
- Subtitle: `扫频噪声与扬声器检查`
- Keywords: `音频,声学,扫频,粉噪,白噪,扬声器,喇叭,校准,频率,信号,分贝,测试`

English:

- App name: `AcoustaLab: Tone Generator`
- Subtitle: `Sweep, Noise & Speaker Tests`
- Keywords: `tone,generator,frequency,sweep,pink,white,noise,speaker,calibration,sine,wave,hz,audio,test`
