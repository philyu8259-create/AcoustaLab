# AcoustaLab

AcoustaLab 1.4 is a local acoustic utility for tone generation, sweep generation, noise testing, presets, and headphone/speaker validation workflows on iOS.

## Current Status (v1.4)

Core features:
- Single Tone page
- Sweep page
- Noise page
- Sine / Square / Triangle / Saw waveforms
- Linear / Log sweep
- Repeat / Siren sweep loop
- White / Pink / Brown noise
- Low-pass / High-pass filter
- Frequency text inputs
- Logarithmic frequency slider (1 Hz - 32 kHz)
- Fine-tune buttons
- Standard frequency shortcuts
- Channel routing: L+R / L / R
- Output gain control
- Play / Stop
- AVAudioSourceNode-based realtime generation
- Basic gain smoothing for start / stop and parameter changes
- Output route detection (speaker / headphones / bluetooth)
- Keep-screen-awake and safety fade settings
- PolyBLEP band-limited square / saw oscillator path
- Local preset save / load / delete
- Built-in test pack for acoustic workflow quick checks
- Built-in calibration report and local test history support
- Local export of calibration report, test log, and settings-related outputs

Privacy and monetization:
- No advertisements, no ad SDKs
- No tracking for ad profiling, ad SDK telemetry, or user behavior ads analytics
- No account login required
- One-time Apple In-App Purchase for full access (no subscriptions)
- All generated audio, presets, test history, and calibration artifacts are stored on device first

## Build Commands

```bash
xcodegen generate
xcodebuild -project AudioFunctionGenerator.xcodeproj -scheme AudioFunctionGenerator -resolvePackageDependencies
xcodebuild -project AudioFunctionGenerator.xcodeproj -scheme AudioFunctionGenerator -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project AudioFunctionGenerator.xcodeproj -scheme AudioFunctionGenerator -destination 'platform=iOS Simulator,name=iPhone 17' clean build
```

## Local Privacy Notes

AcoustaLab is designed as a local-first tool. By default, the app keeps signal generation data, routes, calibration state, tone/sweep/noise presets, test history, and export files on-device.

### 1.4 Scope in Practice

- Route check and test status pages are for in-app guidance only.
- Calibration report export and test history can be shared locally by the user.
