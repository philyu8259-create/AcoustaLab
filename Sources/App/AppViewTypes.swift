import SwiftUI

enum InputField: Hashable {
    case toneFrequency
    case sweepStart
    case sweepEnd
    case noiseCutoff
    case presetName
}

enum SweepStepTarget: String, CaseIterable, Identifiable, Hashable {
    case start
    case end

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .start:
            return String(localized: "sweep.start")
        case .end:
            return String(localized: "sweep.end")
        }
    }
}

enum RootTab: Hashable {
    case tone
    case sweep
    case noise
    case presets
    case settings

    init(mode: AudioEngineController.SignalMode) {
        switch mode {
        case .single:
            self = .tone
        case .sweep:
            self = .sweep
        case .noise:
            self = .noise
        }
    }

    var signalMode: AudioEngineController.SignalMode? {
        switch self {
        case .tone:
            return .single
        case .sweep:
            return .sweep
        case .noise:
            return .noise
        case .presets, .settings:
            return nil
        }
    }
}
