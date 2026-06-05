import SwiftUI

struct RealtimeSpectrumAnalyzerCard: View {
    @ObservedObject var analyzer: RealtimeSpectrumAnalyzer

    var body: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionTitle(title: String(localized: "analyzer.title"))
                        Text(String(localized: "analyzer.card_hint"))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    StatusBadge(
                        title: analyzer.statusText,
                        tone: analyzer.isRunning ? .accent : .warning
                    )
                }

                RealtimeBandChart(bands: analyzer.bands)

                LazyVGrid(columns: gridColumns(2), spacing: 10) {
                    DetailTile(
                        title: String(localized: "analyzer.peak_frequency"),
                        value: analyzer.peakFrequency > 0 ? FrequencyFormatting.displayString(for: analyzer.peakFrequency) : String(localized: "analyzer.peak_unknown"),
                        caption: String(localized: "analyzer.peak_hint")
                    )

                    DetailTile(
                        title: String(localized: "analyzer.input_level"),
                        value: String(format: "%.1f dBFS", analyzer.inputLevelDecibels),
                        caption: String(localized: "analyzer.input_level_hint")
                    )
                }

                if analyzer.isRunning {
                    Button(String(localized: "analyzer.stop_button")) {
                        analyzer.stop()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button(String(localized: "analyzer.start_button")) {
                        analyzer.start()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
}

struct RealtimeBandChart: View {
    let bands: [RealtimeSpectrumAnalyzer.Band]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "analyzer.band_chart"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                GeometryReader { geometry in
                    let chartHeight = max(geometry.size.height - 30, 82)
                    HStack(alignment: .bottom, spacing: 7) {
                        ForEach(bands) { band in
                            VStack(spacing: 6) {
                                let normalized = normalizedHeight(for: band.levelDecibels)
                                let barHeight = max(4, chartHeight * normalized)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(barColor(for: band.levelDecibels))
                                    .frame(width: 26, height: barHeight)
                                    .frame(height: chartHeight, alignment: .bottom)

                                Text(bandLabel(for: band.centerFrequency))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Text(String(format: "%.0f", band.levelDecibels))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.92))
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 36)
                        }
                    }
                }
                .frame(width: CGFloat(max(bands.count, 1)) * 43, height: 168)
            }
            .frame(height: 168)
        }
    }

    private func barColor(for levelDb: Double) -> Color {
        if levelDb > -24 {
            return AppTheme.danger
        }
        if levelDb > -40 {
            return AppTheme.warning
        }
        if levelDb > -55 {
            return AppTheme.accent
        }
        return AppTheme.textSecondary.opacity(0.45)
    }

    private func normalizedHeight(for levelDb: Double) -> CGFloat {
        let floor = -120.0
        let ceiling = 6.0
        let clamped = max(floor, min(ceiling, levelDb))
        return CGFloat((clamped - floor) / (ceiling - floor))
    }

    private func bandLabel(for centerFrequency: Double) -> String {
        if centerFrequency >= 1000 {
            let kHz = centerFrequency / 1000.0
            if kHz.truncatingRemainder(dividingBy: 1.0) == 0 {
                return String(format: "%.0fk", kHz)
            }
            return String(format: "%.1fk", kHz)
        }
        return String(format: "%.0f", centerFrequency)
    }
}
