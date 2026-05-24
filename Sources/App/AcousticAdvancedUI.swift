import SwiftUI

extension View {
    func acousticGrain(opacity: Double = 0.012) -> some View {
        overlay(
            Canvas { context, size in
                let step: CGFloat = 3
                for x in stride(from: CGFloat.zero, through: size.width, by: step) {
                    for y in stride(from: CGFloat.zero, through: size.height, by: step) {
                        let seed = abs(sin((Double(x) * 12.9898) + (Double(y) * 78.233))) * 43_758.5453
                        let grain = seed - floor(seed)
                        guard grain > 0.86 else { continue }
                        let alpha = opacity * (0.35 + (grain * 0.65))
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 0.7, height: 0.7)),
                            with: .color(Color.white.opacity(alpha))
                        )
                    }
                }
            }
            .blendMode(.screen)
            .allowsHitTesting(false)
        )
    }

    func instrumentGlow(color: Color, radius: CGFloat = 8) -> some View {
        shadow(color: color.opacity(0.34), radius: radius * 0.5)
            .shadow(color: color.opacity(0.18), radius: radius)
    }

    func oledScreen(cornerRadius: CGFloat = 14, accentColor: Color) -> some View {
        modifier(OLEDScreenModifier(cornerRadius: cornerRadius, accentColor: accentColor))
    }
}

private struct OLEDScreenModifier: ViewModifier {
    let cornerRadius: CGFloat
    let accentColor: Color

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.98),
                                AcousticTheme.displayGlass.opacity(0.98),
                                Color.black.opacity(0.82)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.02),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .blendMode(.screen)
            )
            .overlay(
                Canvas { context, size in
                    let lineStep: CGFloat = 4
                    for y in stride(from: CGFloat.zero, through: size.height, by: lineStep) {
                        let rect = CGRect(x: 0, y: y, width: size.width, height: 0.45)
                        context.fill(Path(rect), with: .color(accentColor.opacity(0.014)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.88), lineWidth: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                accentColor.opacity(0.20),
                                Color.black.opacity(0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.62), radius: 6, x: 0, y: 4)
            .shadow(color: accentColor.opacity(0.11), radius: 14)
    }
}

struct PrecisionDisplay: View {
    let value: String
    let unit: String
    let label: String
    let accentColor: Color
    var valueFontSize: CGFloat = 32

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(4.2)
                .foregroundStyle(Color.white.opacity(0.58))
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.system(size: max(valueFontSize, 42), weight: .light, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(accentColor)
                    .instrumentGlow(color: accentColor, radius: 13)
                    .lineLimit(1)
                    .minimumScaleFactor(0.34)

                Text(unit)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(accentColor.opacity(0.82))
                    .instrumentGlow(color: accentColor, radius: 7)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76, alignment: .leading)
            .oledScreen(cornerRadius: 18, accentColor: accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OscilloscopeDisplay: View {
    let label: String
    let waveType: String
    let frequency: Double
    let isRunning: Bool
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .tracking(4.2)
                .foregroundStyle(Color.white.opacity(0.52))
                .lineLimit(1)

            AcousticOscilloscope(
                waveType: waveType,
                frequency: frequency,
                isRunning: isRunning,
                accentColor: accentColor
            )
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 76, maxHeight: 76)
            .oledScreen(cornerRadius: 18, accentColor: accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AcousticOscilloscope: View {
    let waveType: String
    let frequency: Double
    let isRunning: Bool
    let accentColor: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let phase = isRunning ? timeline.date.timeIntervalSinceReferenceDate * min(max(frequency / 180, 0.4), 20) : 0
                var path = Path()
                let points = 96

                for index in 0...points {
                    let progress = Double(index) / Double(points)
                    let x = size.width * progress
                    let y = size.height * (0.5 - 0.34 * sample((progress * visibleCycles) + phase))

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                let midline = Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height / 2))
                    path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                }
                context.stroke(midline, with: .color(Color.white.opacity(0.07)), lineWidth: 1)
                context.stroke(path, with: .color(accentColor.opacity(0.24)), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(accentColor.opacity(0.45)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                context.stroke(path, with: .color(accentColor), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func sample(_ value: Double) -> Double {
        let phase = value - floor(value)

        switch waveType {
        case "square":
            return phase < 0.5 ? 1 : -1
        case "triangle":
            return 1 - abs((phase * 4).truncatingRemainder(dividingBy: 4) - 2)
        case "saw":
            return (phase * 2) - 1
        default:
            return sin(phase * .pi * 2)
        }
    }

    private var visibleCycles: Double {
        let minimumFrequency = 1.0
        let maximumFrequency = 32_000.0
        let clampedFrequency = max(minimumFrequency, min(maximumFrequency, frequency))
        let normalized = log10(clampedFrequency / minimumFrequency) / log10(maximumFrequency / minimumFrequency)
        return 1.05 + (normalized * 3.35)
    }
}

struct PrecisionKnob: View {
    @Binding var value: Double
    let title: String
    let unit: String
    let accentColor: Color
    var compact = false
    var medium = false

    var body: some View {
        VStack(spacing: compact ? 5 : 7) {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.34), lineWidth: side * 0.07)
                        .frame(width: side * 0.92, height: side * 0.92)
                        .blur(radius: 0.2)

                    ForEach(0..<tickCount, id: \.self) { index in
                        let progress = Double(index) / Double(tickCount - 1)
                        let angle = tickAngle(for: progress)
                        let radius = side * 0.43

                        Circle()
                            .fill(progress <= clampedValue ? accentColor : Color.white.opacity(0.14))
                            .frame(width: tickSize, height: tickSize)
                            .position(
                                x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius
                            )
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color(red: 0.16, green: 0.18, blue: 0.23),
                                    Color.black.opacity(0.72)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: side * 0.42
                            )
                        )
                        .frame(width: side * 0.62, height: side * 0.62)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.42), radius: 8, x: 0, y: 5)

                    Capsule()
                        .fill(accentColor)
                        .frame(width: 5, height: side * 0.22)
                        .offset(y: -side * 0.18)
                        .rotationEffect(.radians(pointerRadians))
                        .instrumentGlow(color: accentColor, radius: 6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            updateValue(from: gesture.location, in: center)
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .lineLimit(1)
                    .textCase(.uppercase)
                Text("\(percentText)\(unit)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(accentColor)
                    .lineLimit(1)
            }
        }
    }

    private var clampedValue: Double {
        max(0, min(1, value))
    }

    private var tickCount: Int {
        medium ? 18 : 16
    }

    private var tickSize: CGFloat {
        medium ? 5.5 : 4.8
    }

    private var pointerRadians: Double {
        tickAngle(for: clampedValue) + (.pi / 2)
    }

    private var percentText: String {
        "\(Int((clampedValue * 100).rounded()))"
    }

    private func tickAngle(for progress: Double) -> Double {
        let degrees = -140 + (max(0, min(1, progress)) * 280)
        return (degrees - 90) * .pi / 180
    }

    private func updateValue(from location: CGPoint, in center: CGPoint) {
        let vector = CGVector(dx: location.x - center.x, dy: location.y - center.y)
        var degrees = atan2(vector.dy, vector.dx) * 180 / .pi + 90
        if degrees < -140 {
            degrees += 360
        }
        value = max(0, min(1, (degrees + 140) / 280))
    }
}
