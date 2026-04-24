import SwiftUI

/// Professional acoustic UI design tokens used across the app shell and controls.
struct AcousticTheme {
    static let backgroundBase = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let backgroundElevated = Color(red: 0.07, green: 0.08, blue: 0.10)
    static let panelBackground = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let panelBackgroundStrong = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let controlBackground = Color(red: 0.15, green: 0.15, blue: 0.18)

    static let sineAccent = Color.cyan
    static let squareAccent = Color.orange
    static let triangleAccent = Color(red: 0.28, green: 0.90, blue: 0.58)
    static let sawAccent = Color(red: 0.98, green: 0.84, blue: 0.24)
    static let noiseAccent = Color(red: 0.74, green: 0.50, blue: 0.98)
    static let warningRed = Color(red: 1.0, green: 0.31, blue: 0.34)

    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.55)
    static let stroke = Color.white.opacity(0.08)
    static let glow = Color.white.opacity(0.18)
}

struct HardwarePanelModifier: ViewModifier {
    var fill: Color = AcousticTheme.panelBackground
    var cornerRadius: CGFloat = 18
    var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.03 : 0.08), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(isPressed ? 0.32 : 0.0), lineWidth: 2)
                    .blur(radius: 2)
                    .offset(x: 1, y: 1)
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            )
            .shadow(
                color: .black.opacity(isPressed ? 0.45 : 0.78),
                radius: isPressed ? 4 : 12,
                x: 0,
                y: isPressed ? 2 : 7
            )
    }
}

extension View {
    func hardwarePanel(
        fill: Color = AcousticTheme.panelBackground,
        cornerRadius: CGFloat = 18,
        isPressed: Bool = false
    ) -> some View {
        modifier(HardwarePanelModifier(fill: fill, cornerRadius: cornerRadius, isPressed: isPressed))
    }
}

extension AudioEngineController.Waveform {
    var acousticAccentColor: Color {
        switch self {
        case .sine:
            return AcousticTheme.sineAccent
        case .square:
            return AcousticTheme.squareAccent
        case .triangle:
            return AcousticTheme.triangleAccent
        case .saw:
            return AcousticTheme.sawAccent
        }
    }
}

extension AudioEngineController.SweepMode {
    var acousticAccentColor: Color {
        switch self {
        case .sweep:
            return AcousticTheme.sineAccent
        case .steppedSine:
            return AcousticTheme.triangleAccent
        }
    }
}

extension AudioEngineController.SweepCurve {
    var acousticAccentColor: Color {
        switch self {
        case .linear:
            return AcousticTheme.squareAccent
        case .logarithmic:
            return AcousticTheme.sineAccent
        }
    }
}

extension AudioEngineController.NoiseType {
    var acousticAccentColor: Color {
        switch self {
        case .white:
            return AcousticTheme.textPrimary
        case .pink:
            return AcousticTheme.noiseAccent
        case .brown:
            return AcousticTheme.squareAccent
        }
    }
}

extension AudioEngineController.FilterMode {
    var acousticAccentColor: Color {
        switch self {
        case .off:
            return AcousticTheme.textSecondary
        case .lowPass:
            return AcousticTheme.triangleAccent
        case .highPass:
            return AcousticTheme.sawAccent
        case .bandPass:
            return AcousticTheme.sineAccent
        }
    }
}

extension AudioEngineController.FilterSlope {
    var acousticAccentColor: Color {
        switch self {
        case .twelveDecibels:
            return AcousticTheme.sineAccent
        case .twentyFourDecibels:
            return AcousticTheme.triangleAccent
        case .fortyEightDecibels:
            return AcousticTheme.warningRed
        }
    }
}

extension AudioEngineController.ChannelMode {
    var acousticAccentColor: Color {
        switch self {
        case .stereo:
            return AcousticTheme.sineAccent
        case .left:
            return AcousticTheme.triangleAccent
        case .right:
            return AcousticTheme.sawAccent
        }
    }
}
