import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum AppTheme {
    static let backgroundTop = AcousticTheme.backgroundElevated
    static let backgroundBottom = AcousticTheme.backgroundBase
    static let card = AcousticTheme.panelBackground
    static let cardStrong = AcousticTheme.panelBackgroundStrong
    static let stroke = AcousticTheme.stroke
    static let accent = AcousticTheme.sineAccent
    static let accentSoft = AcousticTheme.noiseAccent
    static let success = Color(hex: 0x32D5A4)
    static let warning = Color(hex: 0xF8C34A)
    static let danger = AcousticTheme.warningRed
    static let textSecondary = AcousticTheme.textSecondary
}

extension AudioEngineController.SignalMode {
    var localizedTitle: String {
        switch self {
        case .single: return String(localized: "mode.single")
        case .sweep: return String(localized: "mode.sweep")
        case .noise: return String(localized: "mode.noise")
        }
    }
}

extension AudioEngineController.Waveform {
    var localizedTitle: String {
        switch self {
        case .sine: return String(localized: "waveform.sine")
        case .square: return String(localized: "waveform.square")
        case .triangle: return String(localized: "waveform.triangle")
        case .saw: return String(localized: "waveform.saw")
        }
    }
}

extension AudioEngineController.ChannelMode {
    var localizedTitle: String {
        switch self {
        case .stereo: return String(localized: "channel.stereo")
        case .left: return String(localized: "channel.left")
        case .right: return String(localized: "channel.right")
        }
    }
}

extension AudioEngineController.SweepCurve {
    var localizedTitle: String {
        switch self {
        case .linear: return String(localized: "sweep_curve.linear")
        case .logarithmic: return String(localized: "sweep_curve.logarithmic")
        }
    }
}

extension AudioEngineController.SweepMode {
    var localizedTitle: String {
        switch self {
        case .sweep: return String(localized: "sweep_mode.sweep")
        case .steppedSine: return String(localized: "sweep_mode.stepped_sine")
        }
    }
}

extension AudioEngineController.NoiseType {
    var localizedTitle: String {
        switch self {
        case .white: return String(localized: "noise.white")
        case .pink: return String(localized: "noise.pink")
        case .brown: return String(localized: "noise.brown")
        }
    }
}

extension AudioEngineController.FilterMode {
    var localizedTitle: String {
        switch self {
        case .off: return String(localized: "filter.off")
        case .lowPass: return String(localized: "filter.lowpass")
        case .highPass: return String(localized: "filter.highpass")
        case .bandPass: return String(localized: "filter.bandpass")
        }
    }
}

extension AudioEngineController.FilterSlope {
    var localizedTitle: String {
        switch self {
        case .twelveDecibels: return String(localized: "filter_slope.12db")
        case .twentyFourDecibels: return String(localized: "filter_slope.24db")
        case .fortyEightDecibels: return String(localized: "filter_slope.48db")
        }
    }
}

extension LoopbackCalibrationRun.Phase {
    var localizedTitle: String {
        switch self {
        case .idle:
            return String(localized: "calibration.phase_idle")
        case .preparing:
            return String(localized: "calibration.phase_preparing")
        case .settling:
            return String(localized: "calibration.phase_settling")
        case .measuring:
            return String(localized: "calibration.phase_measuring")
        case .pausing:
            return String(localized: "calibration.phase_pausing")
        case .completed:
            return String(localized: "calibration.phase_completed")
        }
    }
}
