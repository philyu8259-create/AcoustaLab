import SwiftUI

/// Professional acoustic UI design tokens used across the app shell and controls.
struct AcousticTheme {
    static let backgroundBase = Color(hex: 0x090B12)
    static let backgroundElevated = Color(hex: 0x111722)
    static let panelBackground = Color(hex: 0x222633)
    static let panelBackgroundStrong = Color(hex: 0x313848)
    static let controlBackground = Color(hex: 0x373A47)
    static let controlBackgroundPressed = Color(hex: 0x2C303B)
    static let displayGlass = Color(hex: 0x080A0F)

    static let sineAccent = Color(red: 0.38, green: 0.82, blue: 0.96)
    static let squareAccent = Color(red: 0.98, green: 0.61, blue: 0.28)
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
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                fill.opacity(isPressed ? 0.92 : 1),
                                fill.opacity(isPressed ? 0.78 : 0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isPressed ? 0.04 : 0.10), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.02 : 0.18),
                                Color.white.opacity(0.02),
                                Color.black.opacity(isPressed ? 0.38 : 0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(isPressed ? 0.46 : 0.20), lineWidth: isPressed ? 2 : 1)
                    .blur(radius: isPressed ? 2 : 1.2)
                    .offset(x: 1, y: 1.2)
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
            .acousticGrain(opacity: isPressed ? 0.006 : 0.010)
            .shadow(
                color: AcousticTheme.backgroundBase.opacity(isPressed ? 0.50 : 0.72),
                radius: isPressed ? 4 : 13,
                x: 0,
                y: isPressed ? 2 : 8
            )
            .shadow(
                color: Color.white.opacity(isPressed ? 0.01 : 0.035),
                radius: 1,
                x: 0,
                y: -0.5
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
