# AcoustaLab

AcoustaLab 1.6 is a local-first acoustic utility for signal generation, speaker and headphone checks, guided test workflows, realtime spectrum analysis, and calibration reporting on iOS and iPadOS.

## Current Status (v1.6)

Signal tools:
- Single tones with sine, square, triangle, and sawtooth waveforms
- Linear and logarithmic sweeps, including step and repeating sweep modes
- White, pink, and brown noise with filter controls
- Logarithmic frequency control from 1 Hz to 32 kHz, fine tuning, and standard frequency shortcuts
- L+R, left-only, and right-only channel routing
- Output gain control, safety fades, screen-awake control, and output-route detection
- Realtime audio generation with smoothed parameter changes and band-limited square/saw oscillator paths

Testing and reporting:
- User presets with local save, load, and delete
- Built-in one-click test presets for reference tone, speaker sweep, noise, channel, and low-frequency checks
- Guided acoustic test workflow with local test history
- Local calibration workflow and realtime spectrum/RTA analysis
- Calibration report export as PDF, CSV, or PNG curve image

Privacy and access:
- No advertisements or third-party advertising SDKs
- No advertising or behavioral tracking, and no App Tracking Transparency request
- No account login required
- 3 days of starter access
- Monthly and yearly auto-renewable Pro subscriptions, plus a one-time lifetime unlock, through Apple In-App Purchase
- Generated audio, microphone measurements, presets, test history, calibration data, and reports remain on device unless the user explicitly exports or shares a file

## Build Commands

```bash
xcodegen generate
xcodebuild -project AudioFunctionGenerator.xcodeproj -scheme AudioFunctionGenerator -resolvePackageDependencies
xcodebuild -project AudioFunctionGenerator.xcodeproj -scheme AudioFunctionGenerator -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project AudioFunctionGenerator.xcodeproj -scheme AudioFunctionGenerator -destination 'platform=iOS Simulator,name=iPhone 17' clean build
```

## Local Privacy Notes

AcoustaLab processes signal generation, microphone measurement, realtime spectrum analysis, routing, presets, test history, and calibration data locally. It does not automatically upload audio, measurements, reports, or usage data to a developer-operated server.

Exported PDF, CSV, and PNG files are created from local calibration data. A file leaves the app only when the user chooses a destination through the system export or share flow.

Apple handles App Store purchase transactions. AcoustaLab reads verified StoreKit entitlements to determine access and does not receive or store payment card details.
