# AcoustaLab

iOS MVP prototype for a mobile audio signal generator and acoustic test toolkit.

## Current status

v0.2 runnable prototype:
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

## Build

```bash
cd AudioFunctionGenerator
xcodegen generate
xcodebuild -project AudioFunctionGenerator.xcodeproj -scheme AudioFunctionGenerator -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Next

- Improve anti-aliasing for square / saw
- Add stronger fade ramp and parameter smoothing
- Add output device detection and warning UI
- Add preset management
- Add octave / 1-3 octave quick selection logic
