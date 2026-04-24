import Foundation

func bandLimitedSample(
    for waveform: AudioEngineController.Waveform,
    phase: Double,
    phaseIncrement: Double
) -> Double {
    let normalizedPhase = phase

    switch waveform {
    case .sine:
        return sin(normalizedPhase * 2.0 * Double.pi)
    case .square:
        var sample = normalizedPhase < 0.5 ? 1.0 : -1.0
        sample += polyBLEP(t: normalizedPhase, dt: phaseIncrement)
        sample -= polyBLEP(t: fmod(normalizedPhase + 0.5, 1.0), dt: phaseIncrement)
        return sample
    case .triangle:
        let shifted = normalizedPhase - floor(normalizedPhase + 0.5)
        return 4.0 * abs(shifted) - 1.0
    case .saw:
        var sample = (2.0 * normalizedPhase) - 1.0
        sample -= polyBLEP(t: normalizedPhase, dt: phaseIncrement)
        return sample
    }
}

func polyBLEP(t: Double, dt: Double) -> Double {
    guard dt > 0, dt < 1 else { return 0 }

    if t < dt {
        let x = t / dt
        return x + x - x * x - 1.0
    }

    if t > 1.0 - dt {
        let x = (t - 1.0) / dt
        return x * x + x + x + 1.0
    }

    return 0
}

func steppedSweepFrequencies(start: Double, end: Double, stepMode: FrequencyStepMode) -> [Double] {
    let lower = min(start, end)
    let upper = max(start, end)
    var values = stepMode.values.filter { $0 >= lower - 0.0001 && $0 <= upper + 0.0001 }

    if values.isEmpty {
        if abs(start - end) < 0.0001 {
            return [start]
        }
        return [start, end].sorted()
    }

    if abs((values.first ?? lower) - lower) > 0.0001 {
        values.insert(lower, at: 0)
    }
    if abs((values.last ?? upper) - upper) > 0.0001 {
        values.append(upper)
    }

    var deduplicated: [Double] = []
    for value in values {
        guard deduplicated.contains(where: { abs($0 - value) < 0.0001 }) == false else { continue }
        deduplicated.append(value)
    }
    return deduplicated
}

func filterConfiguration(
    sampleRate: Double,
    cutoff: Double,
    mode: AudioEngineController.FilterMode,
    slope: AudioEngineController.FilterSlope,
    q: Double
) -> FilterConfiguration {
    let safeCutoff = min(max(cutoff, 10), sampleRate * 0.45)

    switch mode {
    case .off:
        return .off
    case .lowPass:
        return lowPassConfiguration(sampleRate: sampleRate, cutoff: safeCutoff, slope: slope)
    case .highPass:
        return highPassConfiguration(sampleRate: sampleRate, cutoff: safeCutoff, slope: slope)
    case .bandPass:
        let safeQ = min(max(q, 0.5), 12.0)
        return .bandPass(
            [
                bandPassCoefficients(sampleRate: sampleRate, cutoff: safeCutoff, q: min(max(safeQ * 0.85, 0.5), 12.0)),
                bandPassCoefficients(sampleRate: sampleRate, cutoff: safeCutoff, q: min(max(safeQ * 1.15, 0.5), 12.0))
            ]
        )
    }
}

func lowPassConfiguration(
    sampleRate: Double,
    cutoff: Double,
    slope: AudioEngineController.FilterSlope
) -> FilterConfiguration {
    .lowPass(
        butterworthQValues(for: slope).map {
            lowPassCoefficients(sampleRate: sampleRate, cutoff: cutoff, q: $0)
        }
    )
}

func highPassConfiguration(
    sampleRate: Double,
    cutoff: Double,
    slope: AudioEngineController.FilterSlope
) -> FilterConfiguration {
    .highPass(
        butterworthQValues(for: slope).map {
            highPassCoefficients(sampleRate: sampleRate, cutoff: cutoff, q: $0)
        }
    )
}

func butterworthQValues(for slope: AudioEngineController.FilterSlope) -> [Double] {
    let order: Int

    switch slope {
    case .twelveDecibels:
        order = 2
    case .twentyFourDecibels:
        order = 4
    case .fortyEightDecibels:
        order = 8
    }

    let stageCount = order / 2
    return (1 ... stageCount).map { stage in
        let angle = Double((2 * stage) - 1) * Double.pi / (2.0 * Double(order))
        return 1.0 / (2.0 * cos(angle))
    }
}

func lowPassCoefficients(sampleRate: Double, cutoff: Double, q: Double) -> BiquadCoefficients {
    let omega = 2.0 * Double.pi * cutoff / sampleRate
    let sinOmega = sin(omega)
    let cosOmega = cos(omega)
    let alpha = sinOmega / (2.0 * q)
    let a0 = 1.0 + alpha

    return BiquadCoefficients(
        b0: ((1.0 - cosOmega) * 0.5) / a0,
        b1: (1.0 - cosOmega) / a0,
        b2: ((1.0 - cosOmega) * 0.5) / a0,
        a1: (-2.0 * cosOmega) / a0,
        a2: (1.0 - alpha) / a0
    )
}

func highPassCoefficients(sampleRate: Double, cutoff: Double, q: Double) -> BiquadCoefficients {
    let omega = 2.0 * Double.pi * cutoff / sampleRate
    let sinOmega = sin(omega)
    let cosOmega = cos(omega)
    let alpha = sinOmega / (2.0 * q)
    let a0 = 1.0 + alpha

    return BiquadCoefficients(
        b0: ((1.0 + cosOmega) * 0.5) / a0,
        b1: (-(1.0 + cosOmega)) / a0,
        b2: ((1.0 + cosOmega) * 0.5) / a0,
        a1: (-2.0 * cosOmega) / a0,
        a2: (1.0 - alpha) / a0
    )
}

func bandPassCoefficients(sampleRate: Double, cutoff: Double, q: Double) -> BiquadCoefficients {
    let omega = 2.0 * Double.pi * cutoff / sampleRate
    let sinOmega = sin(omega)
    let cosOmega = cos(omega)
    let alpha = sinOmega / (2.0 * q)
    let a0 = 1.0 + alpha

    return BiquadCoefficients(
        b0: alpha / a0,
        b1: 0,
        b2: -alpha / a0,
        a1: (-2.0 * cosOmega) / a0,
        a2: (1.0 - alpha) / a0
    )
}
