import Foundation

struct AppPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var mode: AudioEngineController.SignalMode

    var frequency: Double
    var waveform: AudioEngineController.Waveform

    var sweepStartFrequency: Double
    var sweepEndFrequency: Double
    var sweepDuration: Double
    var sweepStepHoldDuration: Double
    var sweepCurve: AudioEngineController.SweepCurve
    var sweepMode: AudioEngineController.SweepMode
    var sweepStepMode: FrequencyStepMode

    var noiseType: AudioEngineController.NoiseType
    var noiseFilterMode: AudioEngineController.FilterMode
    var noiseCutoff: Double
    var noiseFilterSlope: AudioEngineController.FilterSlope
    var noiseBandQ: Double

    var channelMode: AudioEngineController.ChannelMode
    var outputGain: Double
    var safetyFadeEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case mode
        case frequency
        case waveform
        case sweepStartFrequency
        case sweepEndFrequency
        case sweepDuration
        case sweepStepHoldDuration
        case sweepCurve
        case sweepMode
        case sweepStepMode
        case noiseType
        case noiseFilterMode
        case noiseCutoff
        case noiseFilterSlope
        case noiseBandQ
        case channelMode
        case outputGain
        case safetyFadeEnabled
    }

    init(
        id: UUID = UUID(),
        name: String,
        mode: AudioEngineController.SignalMode,
        frequency: Double,
        waveform: AudioEngineController.Waveform,
        sweepStartFrequency: Double,
        sweepEndFrequency: Double,
        sweepDuration: Double,
        sweepStepHoldDuration: Double,
        sweepCurve: AudioEngineController.SweepCurve,
        sweepMode: AudioEngineController.SweepMode,
        sweepStepMode: FrequencyStepMode,
        noiseType: AudioEngineController.NoiseType,
        noiseFilterMode: AudioEngineController.FilterMode,
        noiseCutoff: Double,
        noiseFilterSlope: AudioEngineController.FilterSlope,
        noiseBandQ: Double,
        channelMode: AudioEngineController.ChannelMode,
        outputGain: Double,
        safetyFadeEnabled: Bool
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.frequency = frequency
        self.waveform = waveform
        self.sweepStartFrequency = sweepStartFrequency
        self.sweepEndFrequency = sweepEndFrequency
        self.sweepDuration = sweepDuration
        self.sweepStepHoldDuration = sweepStepHoldDuration
        self.sweepCurve = sweepCurve
        self.sweepMode = sweepMode
        self.sweepStepMode = sweepStepMode
        self.noiseType = noiseType
        self.noiseFilterMode = noiseFilterMode
        self.noiseCutoff = noiseCutoff
        self.noiseFilterSlope = noiseFilterSlope
        self.noiseBandQ = noiseBandQ
        self.channelMode = channelMode
        self.outputGain = outputGain
        self.safetyFadeEnabled = safetyFadeEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        mode = try container.decode(AudioEngineController.SignalMode.self, forKey: .mode)
        frequency = try container.decode(Double.self, forKey: .frequency)
        waveform = try container.decode(AudioEngineController.Waveform.self, forKey: .waveform)
        sweepStartFrequency = try container.decode(Double.self, forKey: .sweepStartFrequency)
        sweepEndFrequency = try container.decode(Double.self, forKey: .sweepEndFrequency)
        sweepDuration = try container.decode(Double.self, forKey: .sweepDuration)
        sweepStepHoldDuration = try container.decodeIfPresent(Double.self, forKey: .sweepStepHoldDuration) ?? 1.0
        sweepCurve = try container.decode(AudioEngineController.SweepCurve.self, forKey: .sweepCurve)
        sweepMode = try container.decodeIfPresent(AudioEngineController.SweepMode.self, forKey: .sweepMode) ?? .sweep
        sweepStepMode = try container.decodeIfPresent(FrequencyStepMode.self, forKey: .sweepStepMode) ?? .octave
        noiseType = try container.decode(AudioEngineController.NoiseType.self, forKey: .noiseType)
        noiseFilterMode = try container.decode(AudioEngineController.FilterMode.self, forKey: .noiseFilterMode)
        noiseCutoff = try container.decode(Double.self, forKey: .noiseCutoff)
        noiseFilterSlope = try container.decodeIfPresent(AudioEngineController.FilterSlope.self, forKey: .noiseFilterSlope) ?? .twentyFourDecibels
        noiseBandQ = try container.decodeIfPresent(Double.self, forKey: .noiseBandQ) ?? 4.3
        channelMode = try container.decode(AudioEngineController.ChannelMode.self, forKey: .channelMode)
        outputGain = try container.decode(Double.self, forKey: .outputGain)
        safetyFadeEnabled = try container.decode(Bool.self, forKey: .safetyFadeEnabled)
    }
}

@MainActor
final class PresetStore: ObservableObject {
    @Published private(set) var presets: [AppPreset] = []

    private let defaultsKey = "audio_function_generator_presets"

    init() {
        load()
    }

    func save(_ preset: AppPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.insert(preset, at: 0)
        }
        persist()
    }

    func create(name: String, from controller: AudioEngineController) {
        let preset = controller.makePreset(named: name)
        save(preset)
    }

    func delete(_ preset: AppPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            presets = try JSONDecoder().decode([AppPreset].self, from: data)
        } catch {
            print("Failed to load presets: \(error)")
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            print("Failed to save presets: \(error)")
        }
    }
}
