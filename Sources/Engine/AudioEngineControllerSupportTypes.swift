import AVFoundation
import Foundation

enum AudioSessionRole {
    case playback
    case calibration
}

enum FilterConfiguration {
    case off
    case lowPass([BiquadCoefficients])
    case highPass([BiquadCoefficients])
    case bandPass([BiquadCoefficients])
}

struct BiquadCoefficients {
    let b0: Double
    let b1: Double
    let b2: Double
    let a1: Double
    let a2: Double
}

struct BiquadState {
    var z1: Double = 0
    var z2: Double = 0

    mutating func process(_ input: Double, coefficients: BiquadCoefficients) -> Double {
        let output = (coefficients.b0 * input) + z1
        let nextZ1 = (coefficients.b1 * input) - (coefficients.a1 * output) + z2
        let nextZ2 = (coefficients.b2 * input) - (coefficients.a2 * output)

        guard output.isFinite, nextZ1.isFinite, nextZ2.isFinite else {
            reset()
            return 0
        }

        z1 = nextZ1
        z2 = nextZ2
        return output
    }

    mutating func reset() {
        z1 = 0
        z2 = 0
    }
}

final class LoopbackCalibrationRun {
    enum Phase {
        case idle
        case preparing
        case settling
        case measuring
        case pausing
        case completed
    }

    struct StepMeasurement {
        let frequency: Double
        let decibels: Double
    }

    struct RenderState {
        let stepNumber: Int?
        let frequency: Double?
        let phase: Phase
        let progress: Double
        let stepProgress: Double
        let remainingDuration: Double

        var isToneActive: Bool {
            phase == .settling || phase == .measuring
        }

        var isMeasuring: Bool {
            phase == .measuring
        }
    }

    let id = UUID()
    let profileName: String
    let routeKey: String
    let routeName: String
    let routeDetail: String
    let startedAt: CFTimeInterval
    let sampleRate: Double
    let referenceFrequency: Double
    let stepMode: FrequencyStepMode
    let frequencies: [Double]
    let startDelay: Double
    let settleDuration: Double
    let measureDuration: Double
    let pauseDuration: Double

    private var accumulators: [Double: RMSAccumulator]
    private let lock = NSLock()

    init(
        profileName: String,
        routeKey: String,
        routeName: String,
        routeDetail: String,
        startedAt: CFTimeInterval,
        sampleRate: Double,
        referenceFrequency: Double,
        stepMode: FrequencyStepMode,
        frequencies: [Double],
        startDelay: Double,
        settleDuration: Double,
        measureDuration: Double,
        pauseDuration: Double
    ) {
        self.profileName = profileName
        self.routeKey = routeKey
        self.routeName = routeName
        self.routeDetail = routeDetail
        self.startedAt = startedAt
        self.sampleRate = sampleRate
        self.referenceFrequency = referenceFrequency
        self.stepMode = stepMode
        self.frequencies = frequencies
        self.startDelay = startDelay
        self.settleDuration = settleDuration
        self.measureDuration = measureDuration
        self.pauseDuration = pauseDuration
        self.accumulators = Dictionary(uniqueKeysWithValues: frequencies.map { ($0, RMSAccumulator()) })
    }

    var stepDuration: Double {
        settleDuration + measureDuration + pauseDuration
    }

    var totalDuration: Double {
        startDelay + (Double(frequencies.count) * stepDuration)
    }

    func renderState(at elapsed: Double) -> RenderState {
        guard elapsed >= startDelay else {
            return RenderState(
                stepNumber: nil,
                frequency: nil,
                phase: .preparing,
                progress: 0,
                stepProgress: 0,
                remainingDuration: totalDuration
            )
        }

        let activeElapsed = elapsed - startDelay
        let rawIndex = Int(activeElapsed / stepDuration)
        guard frequencies.indices.contains(rawIndex) else {
            return RenderState(
                stepNumber: nil,
                frequency: nil,
                phase: .completed,
                progress: 1,
                stepProgress: 1,
                remainingDuration: 0
            )
        }

        let stepElapsed = activeElapsed - (Double(rawIndex) * stepDuration)
        let frequency = frequencies[rawIndex]
        let progress = min(max(elapsed / totalDuration, 0), 1)
        let remainingDuration = max(totalDuration - elapsed, 0)
        let phase: Phase

        if stepElapsed < settleDuration {
            phase = .settling
        } else if stepElapsed < (settleDuration + measureDuration) {
            phase = .measuring
        } else {
            phase = .pausing
        }

        let stepProgress = min(max(stepElapsed / stepDuration, 0), 1)
        return RenderState(
            stepNumber: rawIndex + 1,
            frequency: frequency,
            phase: phase,
            progress: progress,
            stepProgress: stepProgress,
            remainingDuration: remainingDuration
        )
    }

    func record(buffer: AVAudioPCMBuffer, elapsed: Double) {
        let state = renderState(at: elapsed)
        guard state.isMeasuring, let frequency = state.frequency else { return }
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = max(Int(buffer.format.channelCount), 1)
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }

        var sumSquares: Double = 0
        var sampleCount: Int = 0
        for frame in 0 ..< frameLength {
            var sample: Double = 0
            for channel in 0 ..< channelCount {
                sample += Double(channelData[channel][frame])
            }
            sample /= Double(channelCount)
            sumSquares += sample * sample
            sampleCount += 1
        }

        lock.lock()
        var accumulator = accumulators[frequency] ?? RMSAccumulator()
        accumulator.sumSquares += sumSquares
        accumulator.sampleCount += sampleCount
        accumulators[frequency] = accumulator
        lock.unlock()
    }

    func measuredPoints(minimumSamples: Int) -> [StepMeasurement] {
        lock.lock()
        let snapshot = accumulators
        lock.unlock()

        return frequencies.compactMap { frequency in
            guard let accumulator = snapshot[frequency], accumulator.sampleCount >= minimumSamples else { return nil }
            let rms = sqrt(accumulator.sumSquares / Double(accumulator.sampleCount))
            guard rms > 0.000_000_1 else { return nil }
            return StepMeasurement(frequency: frequency, decibels: 20.0 * log10(rms))
        }
    }
}

struct RMSAccumulator {
    var sumSquares: Double = 0
    var sampleCount: Int = 0
}

struct PersistedState: Codable {
    let selectedMode: AudioEngineController.SignalMode
    let frequency: Double
    let waveform: AudioEngineController.Waveform
    let channelMode: AudioEngineController.ChannelMode
    let sweepStartFrequency: Double
    let sweepEndFrequency: Double
    let sweepDuration: Double
    let sweepStepHoldDuration: Double
    let sweepCurve: AudioEngineController.SweepCurve
    let sweepMode: AudioEngineController.SweepMode
    let sweepStepMode: FrequencyStepMode
    let noiseType: AudioEngineController.NoiseType
    let noiseFilterMode: AudioEngineController.FilterMode
    let noiseCutoff: Double
    let noiseFilterSlope: AudioEngineController.FilterSlope
    let noiseBandQ: Double
    let outputGain: Double
    let safetyFadeEnabled: Bool
    let keepScreenAwake: Bool
    let extendedExternalGainEnabled: Bool
    let calibrationStepMode: FrequencyStepMode
    let calibrationReferenceFrequency: Double
    let calibrationProfileDraftName: String

    enum CodingKeys: String, CodingKey {
        case selectedMode
        case frequency
        case waveform
        case channelMode
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
        case outputGain
        case safetyFadeEnabled
        case keepScreenAwake
        case extendedExternalGainEnabled
        case calibrationStepMode
        case calibrationReferenceFrequency
        case calibrationProfileDraftName
    }

    init(
        selectedMode: AudioEngineController.SignalMode,
        frequency: Double,
        waveform: AudioEngineController.Waveform,
        channelMode: AudioEngineController.ChannelMode,
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
        outputGain: Double,
        safetyFadeEnabled: Bool,
        keepScreenAwake: Bool,
        extendedExternalGainEnabled: Bool,
        calibrationStepMode: FrequencyStepMode,
        calibrationReferenceFrequency: Double,
        calibrationProfileDraftName: String
    ) {
        self.selectedMode = selectedMode
        self.frequency = frequency
        self.waveform = waveform
        self.channelMode = channelMode
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
        self.outputGain = outputGain
        self.safetyFadeEnabled = safetyFadeEnabled
        self.keepScreenAwake = keepScreenAwake
        self.extendedExternalGainEnabled = extendedExternalGainEnabled
        self.calibrationStepMode = calibrationStepMode
        self.calibrationReferenceFrequency = calibrationReferenceFrequency
        self.calibrationProfileDraftName = calibrationProfileDraftName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedMode = try container.decode(AudioEngineController.SignalMode.self, forKey: .selectedMode)
        frequency = try container.decode(Double.self, forKey: .frequency)
        waveform = try container.decode(AudioEngineController.Waveform.self, forKey: .waveform)
        channelMode = try container.decode(AudioEngineController.ChannelMode.self, forKey: .channelMode)
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
        outputGain = try container.decode(Double.self, forKey: .outputGain)
        safetyFadeEnabled = try container.decode(Bool.self, forKey: .safetyFadeEnabled)
        keepScreenAwake = try container.decode(Bool.self, forKey: .keepScreenAwake)
        extendedExternalGainEnabled = try container.decodeIfPresent(Bool.self, forKey: .extendedExternalGainEnabled) ?? false
        calibrationStepMode = try container.decodeIfPresent(FrequencyStepMode.self, forKey: .calibrationStepMode) ?? .thirdOctave
        calibrationReferenceFrequency = try container.decodeIfPresent(Double.self, forKey: .calibrationReferenceFrequency) ?? 1000
        calibrationProfileDraftName = try container.decodeIfPresent(String.self, forKey: .calibrationProfileDraftName) ?? ""
    }
}
