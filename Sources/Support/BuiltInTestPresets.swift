import Foundation

struct BuiltInTestPreset: Identifiable {
    let id: String
    let nameKey: String
    let descriptionKey: String
    let preset: AppPreset
}

enum BuiltInTestPresetCatalog {
    static let presets: [BuiltInTestPreset] = [
        makePreset(
            presetID: "11111111-1111-1111-1111-111111111111",
            id: "built_in_1khz_reference_tone",
            nameKey: "presets.testpack.preset.reference_tone.name",
            descriptionKey: "presets.testpack.preset.reference_tone.description",
            mode: .single,
            frequency: 1000,
            waveform: .sine,
            channelMode: .stereo,
            outputGain: 0.5
        ),
        makePreset(
            presetID: "22222222-2222-2222-2222-222222222222",
            id: "built_in_sine_sweep_speaker_check",
            nameKey: "presets.testpack.preset.sine_sweep_speaker.name",
            descriptionKey: "presets.testpack.preset.sine_sweep_speaker.description",
            mode: .sweep,
            sweepStartFrequency: 20,
            sweepEndFrequency: 20_000,
            sweepDuration: 12,
            sweepCurve: .logarithmic,
            sweepStepMode: .octave,
            channelMode: .stereo,
            outputGain: 0.5
        ),
        makePreset(
            presetID: "33333333-3333-3333-3333-333333333333",
            id: "built_in_pink_noise_room_check",
            nameKey: "presets.testpack.preset.pink_noise_room_check.name",
            descriptionKey: "presets.testpack.preset.pink_noise_room_check.description",
            mode: .noise,
            noiseType: .pink,
            noiseFilterMode: .off,
            channelMode: .stereo,
            outputGain: 0.5
        ),
        makePreset(
            presetID: "44444444-4444-4444-4444-444444444444",
            id: "built_in_white_noise_floor_check",
            nameKey: "presets.testpack.preset.white_noise_floor_check.name",
            descriptionKey: "presets.testpack.preset.white_noise_floor_check.description",
            mode: .noise,
            noiseType: .white,
            channelMode: .stereo,
            outputGain: 0.35
        ),
        makePreset(
            presetID: "55555555-5555-5555-5555-555555555555",
            id: "built_in_left_channel_check",
            nameKey: "presets.testpack.preset.left_channel_check.name",
            descriptionKey: "presets.testpack.preset.left_channel_check.description",
            mode: .single,
            frequency: 1000,
            waveform: .sine,
            channelMode: .left,
            outputGain: 0.45
        ),
        makePreset(
            presetID: "66666666-6666-6666-6666-666666666666",
            id: "built_in_right_channel_check",
            nameKey: "presets.testpack.preset.right_channel_check.name",
            descriptionKey: "presets.testpack.preset.right_channel_check.description",
            mode: .single,
            frequency: 1000,
            waveform: .sine,
            channelMode: .right,
            outputGain: 0.45
        ),
        makePreset(
            presetID: "77777777-7777-7777-7777-777777777777",
            id: "built_in_low_frequency_response_check",
            nameKey: "presets.testpack.preset.low_frequency_response_check.name",
            descriptionKey: "presets.testpack.preset.low_frequency_response_check.description",
            mode: .sweep,
            sweepStartFrequency: 20,
            sweepEndFrequency: 200,
            sweepDuration: 18,
            sweepCurve: .logarithmic,
            sweepStepMode: .thirdOctave,
            channelMode: .stereo,
            outputGain: 0.5
        )
    ]

    private static func makePreset(
        presetID: String,
        id: String,
        nameKey: String,
        descriptionKey: String,
        mode: AudioEngineController.SignalMode,
        frequency: Double = 1000,
        waveform: AudioEngineController.Waveform = .sine,
        sweepStartFrequency: Double = 20,
        sweepEndFrequency: Double = 20_000,
        sweepDuration: Double = 10,
        sweepStepHoldDuration: Double = 1.0,
        sweepCurve: AudioEngineController.SweepCurve = .logarithmic,
        sweepMode: AudioEngineController.SweepMode = .sweep,
        sweepStepMode: FrequencyStepMode = .octave,
        noiseType: AudioEngineController.NoiseType = .white,
        noiseFilterMode: AudioEngineController.FilterMode = .off,
        noiseCutoff: Double = 1000,
        noiseFilterSlope: AudioEngineController.FilterSlope = .twentyFourDecibels,
        noiseBandQ: Double = 4.3,
        channelMode: AudioEngineController.ChannelMode = .stereo,
        outputGain: Double = 0.5,
        safetyFadeEnabled: Bool = true
    ) -> BuiltInTestPreset {
        BuiltInTestPreset(
            id: id,
            nameKey: nameKey,
            descriptionKey: descriptionKey,
            preset: AppPreset(
                id: UUID(uuidString: presetID) ?? UUID(),
                name: nameKey,
                mode: mode,
                frequency: frequency,
                waveform: waveform,
                sweepStartFrequency: sweepStartFrequency,
                sweepEndFrequency: sweepEndFrequency,
                sweepDuration: sweepDuration,
                sweepStepHoldDuration: sweepStepHoldDuration,
                sweepCurve: sweepCurve,
                sweepMode: sweepMode,
                sweepStepMode: sweepStepMode,
                noiseType: noiseType,
                noiseFilterMode: noiseFilterMode,
                noiseCutoff: noiseCutoff,
                noiseFilterSlope: noiseFilterSlope,
                noiseBandQ: noiseBandQ,
                channelMode: channelMode,
                outputGain: outputGain,
                safetyFadeEnabled: safetyFadeEnabled
            )
            )
    }

    static func preset(for presetID: String) -> BuiltInTestPreset? {
        presets.first { $0.id == presetID }
    }
}
