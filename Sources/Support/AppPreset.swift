import Foundation
import Combine

@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    enum Event: String {
        case presetSaved
        case guidedTestCompleted
        case calibrationCompleted
        case reportExported
    }

    private let defaults: UserDefaults
    private let appVersion: String
    private let now: () -> Date
    private let minimumEventCount: Int
    private let minimumPromptInterval: TimeInterval
    private let lastPromptDateKey = "review_prompt_last_prompt_date"
    private let lastPromptVersionKey = "review_prompt_last_prompt_version"

    init(
        defaults: UserDefaults = .standard,
        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
        now: @escaping () -> Date = Date.init,
        minimumEventCount: Int = 2,
        minimumPromptInterval: TimeInterval = 30 * 24 * 60 * 60
    ) {
        self.defaults = defaults
        self.appVersion = appVersion
        self.now = now
        self.minimumEventCount = minimumEventCount
        self.minimumPromptInterval = minimumPromptInterval
    }

    func record(_ event: Event) -> Bool {
        let eventCountKey = "review_prompt_event_count_\(appVersion)"
        let nextCount = defaults.integer(forKey: eventCountKey) + 1
        defaults.set(nextCount, forKey: eventCountKey)
        defaults.set(now(), forKey: "review_prompt_last_event_\(event.rawValue)")

        guard shouldRequestReview(eventCount: nextCount) else { return false }
        defaults.set(now(), forKey: lastPromptDateKey)
        defaults.set(appVersion, forKey: lastPromptVersionKey)
        return true
    }

    private func shouldRequestReview(eventCount: Int) -> Bool {
        guard eventCount >= minimumEventCount else { return false }
        guard defaults.string(forKey: lastPromptVersionKey) != appVersion else { return false }

        if let lastPromptDate = defaults.object(forKey: lastPromptDateKey) as? Date,
           now().timeIntervalSince(lastPromptDate) < minimumPromptInterval
        {
            return false
        }

        return true
    }
}

struct AppPreset: Identifiable, Codable, Equatable {
    var id: UUID
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
    var sweepRepeatMode: AudioEngineController.SweepRepeatMode
    var sweepRepeatCount: Int
    var sweepDirection: AudioEngineController.SweepDirection
    var sweepLoopInterval: Double

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
        case sweepRepeatMode
        case sweepRepeatCount
        case sweepDirection
        case sweepLoopInterval
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
        sweepRepeatMode: AudioEngineController.SweepRepeatMode = .single,
        sweepRepeatCount: Int = 3,
        sweepDirection: AudioEngineController.SweepDirection = .forward,
        sweepLoopInterval: Double = 0,
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
        self.sweepRepeatMode = sweepRepeatMode
        self.sweepRepeatCount = min(max(sweepRepeatCount, 2), 20)
        self.sweepDirection = sweepDirection
        self.sweepLoopInterval = min(max(sweepLoopInterval, 0), 10)
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
        sweepRepeatMode = try container.decodeIfPresent(AudioEngineController.SweepRepeatMode.self, forKey: .sweepRepeatMode) ?? .single
        sweepRepeatCount = min(max(try container.decodeIfPresent(Int.self, forKey: .sweepRepeatCount) ?? 3, 2), 20)
        sweepDirection = try container.decodeIfPresent(AudioEngineController.SweepDirection.self, forKey: .sweepDirection) ?? .forward
        sweepLoopInterval = min(max(try container.decodeIfPresent(Double.self, forKey: .sweepLoopInterval) ?? 0, 0), 10)
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
