import SwiftUI
import UIKit

struct LogFrequencySlider: View {
    @Binding var frequency: Double
    var range: ClosedRange<Double> = 1.0 ... 32_000.0
    var accentColor: Color = AcousticTheme.sineAccent

    @State private var feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    @Environment(\.dashboardLayoutMetrics) private var metrics

    var body: some View {
        GeometryReader { geometry in
            let trackHeight = metrics.sliderTrackHeight
            let thumbSize = metrics.sliderThumbSize
            let thumbPosition = valueToPosition(
                frequency,
                width: geometry.size.width,
                thumbSize: thumbSize
            )

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.42),
                                AcousticTheme.controlBackgroundPressed.opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: trackHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                            .stroke(Color.black.opacity(0.45), lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.42), accentColor.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(thumbSize, thumbPosition), height: trackHeight)
                    .shadow(color: accentColor.opacity(0.42), radius: 6, x: 0, y: 0)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.76)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.96), lineWidth: 1)
                    )
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.52), radius: 5, x: 0, y: 2)
                    .position(x: thumbPosition, y: geometry.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newValue = positionToValue(
                                    value.location.x,
                                    width: geometry.size.width,
                                    thumbSize: thumbSize
                                )

                                if Int(log10(max(frequency, range.lowerBound))) != Int(log10(max(newValue, range.lowerBound))) {
                                    feedbackGenerator.impactOccurred()
                                    feedbackGenerator.prepare()
                                }

                                frequency = newValue
                            }
                    )
            }
        }
        .frame(height: metrics.sliderThumbSize + 8)
        .onAppear {
            feedbackGenerator.prepare()
        }
    }

    private func valueToPosition(_ value: Double, width: CGFloat, thumbSize: CGFloat) -> CGFloat {
        let clampedValue = max(range.lowerBound, min(value, range.upperBound))
        let logMin = log10(range.lowerBound)
        let logMax = log10(range.upperBound)
        let logValue = log10(clampedValue)
        let percentage = (logValue - logMin) / (logMax - logMin)
        let usableWidth = max(width - thumbSize, 1)
        return (thumbSize / 2) + (CGFloat(percentage) * usableWidth)
    }

    private func positionToValue(_ position: CGFloat, width: CGFloat, thumbSize: CGFloat) -> Double {
        let usableWidth = max(width - thumbSize, 1)
        let clampedPosition = min(max(position - (thumbSize / 2), 0), usableWidth)
        let percentage = Double(clampedPosition / usableWidth)
        let logMin = log10(range.lowerBound)
        let logMax = log10(range.upperBound)
        let logValue = logMin + percentage * (logMax - logMin)
        return pow(10, logValue)
    }
}

struct HardwareCapsuleSelector<Item: Identifiable & Hashable>: View {
    let title: String
    @Binding var selection: Item
    let items: [Item]
    let accentColor: (Item) -> Color
    let label: (Item) -> String

    @Namespace private var animation
    @Environment(\.dashboardLayoutMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(0.2)
                .foregroundStyle(AcousticTheme.textPrimary)

            HStack(spacing: 6) {
                ForEach(items) { item in
                    let isSelected = item == selection

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                            selection = item
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Text(label(item))
                            .font(.system(size: metrics.selectorFontSize, weight: .bold))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.86) : AcousticTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, metrics.selectorVerticalPadding)
                            .background(
                                ZStack {
                                    if isSelected {
                                        Capsule()
                                            .fill(accentColor(item))
                                            .matchedGeometryEffect(id: "selector", in: animation)
                                            .instrumentGlow(color: accentColor(item), radius: 8)
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .hardwarePanel(fill: AcousticTheme.controlBackground, cornerRadius: 24)
        }
    }
}
