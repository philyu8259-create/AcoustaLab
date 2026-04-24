import SwiftUI

func gridColumns(_ count: Int) -> [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
}

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
    }
}

enum StatusBadgeTone {
    case neutral
    case accent
    case success
    case warning
    case danger

    var foreground: Color {
        switch self {
        case .neutral:
            return .white
        case .accent:
            return AppTheme.accent
        case .success:
            return AppTheme.success
        case .warning:
            return AppTheme.warning
        case .danger:
            return AppTheme.danger
        }
    }

    var background: Color {
        foreground.opacity(0.14)
    }

    var stroke: Color {
        foreground.opacity(0.24)
    }
}

struct StatusBadge: View {
    let title: String
    let tone: StatusBadgeTone
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }

            Text(title)
                .lineLimit(1)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(tone.background)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(tone.stroke, lineWidth: 1)
        )
    }
}

struct SubsectionHeader: View {
    let title: String
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

struct DetailTile: View {
    let title: String
    let value: String
    var caption: String? = nil
    var monospaced: Bool = false
    var accentColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            Group {
                if monospaced {
                    Text(value)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                } else {
                    Text(value)
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(accentColor)
            .lineLimit(2)
            .minimumScaleFactor(0.8)

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }
}

struct InlineNotice<Actions: View>: View {
    let icon: String
    let title: String
    let message: String
    let tone: StatusBadgeTone
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tone.foreground)
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            actions
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(tone.background)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(tone.stroke, lineWidth: 1)
        )
    }
}

struct CalibrationCurveView: View {
    let profile: CalibrationProfile
    let analysis: CalibrationProfileAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "calibration.curve_label"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(String(localized: "calibration.curve_body"))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Text(curveRangeText)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppTheme.accent)
            }

            chartCanvas
                .frame(height: 150)

            HStack {
                Text(FrequencyFormatting.displayString(for: analysis.coverageStart))
                Spacer()
                Text(String(localized: "calibration.curve_zero_line"))
                Spacer()
                Text(FrequencyFormatting.displayString(for: analysis.coverageEnd))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private var chartCanvas: some View {
        Canvas { context, size in
            let plotRect = CGRect(
                x: 10,
                y: 10,
                width: max(size.width - 20, 1),
                height: max(size.height - 20, 1)
            )
            let sortedPoints = profile.points.sorted { $0.frequency < $1.frequency }
            guard !sortedPoints.isEmpty else { return }

            let yBounds = correctionBounds
            drawGrid(in: &context, plotRect: plotRect, yBounds: yBounds)

            var curve = Path()
            for (index, point) in sortedPoints.enumerated() {
                let mapped = mappedPoint(point, in: plotRect, yBounds: yBounds)
                if index == 0 {
                    curve.move(to: mapped)
                } else {
                    curve.addLine(to: mapped)
                }
            }
            context.stroke(curve, with: .color(AppTheme.accent), lineWidth: 2.2)

            for point in sortedPoints {
                let mapped = mappedPoint(point, in: plotRect, yBounds: yBounds)
                let isHotspot = point.frequency == analysis.strongestCorrectionPoint.frequency
                let radius = isHotspot ? 4.0 : 2.7
                let markerRect = CGRect(
                    x: mapped.x - radius,
                    y: mapped.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: markerRect),
                    with: .color(isHotspot ? AppTheme.warning : .white.opacity(0.88))
                )
            }
        }
    }

    private var curveRangeText: String {
        "\(signedDecibelText(analysis.minCorrectionPoint.compensationDecibels)) ... \(signedDecibelText(analysis.maxCorrectionPoint.compensationDecibels))"
    }

    private var correctionBounds: (min: Double, max: Double) {
        var lower = min(analysis.minCorrectionPoint.compensationDecibels, 0)
        var upper = max(analysis.maxCorrectionPoint.compensationDecibels, 0)
        if abs(upper - lower) < 2 {
            lower -= 1
            upper += 1
        }

        let padding = max((upper - lower) * 0.16, 1)
        return (lower - padding, upper + padding)
    }

    private func mappedPoint(
        _ point: CalibrationPoint,
        in plotRect: CGRect,
        yBounds: (min: Double, max: Double)
    ) -> CGPoint {
        let minLog = log(max(analysis.coverageStart, 1))
        let maxLog = log(max(analysis.coverageEnd, analysis.coverageStart + 1))
        let frequencyLog = log(max(point.frequency, 1))
        let xProgress = (frequencyLog - minLog) / max(maxLog - minLog, 0.000_001)
        let yProgress = (point.compensationDecibels - yBounds.min) / max(yBounds.max - yBounds.min, 0.000_001)

        return CGPoint(
            x: plotRect.minX + (plotRect.width * min(max(xProgress, 0), 1)),
            y: plotRect.maxY - (plotRect.height * min(max(yProgress, 0), 1))
        )
    }

    private func drawGrid(
        in context: inout GraphicsContext,
        plotRect: CGRect,
        yBounds: (min: Double, max: Double)
    ) {
        let horizontalFractions = [0.0, 0.5, 1.0]
        for fraction in horizontalFractions {
            let y = plotRect.minY + (plotRect.height * fraction)
            var line = Path()
            line.move(to: CGPoint(x: plotRect.minX, y: y))
            line.addLine(to: CGPoint(x: plotRect.maxX, y: y))
            context.stroke(line, with: .color(AppTheme.stroke), lineWidth: 1)
        }

        let zeroProgress = (0 - yBounds.min) / max(yBounds.max - yBounds.min, 0.000_001)
        if zeroProgress >= 0, zeroProgress <= 1 {
            let y = plotRect.maxY - (plotRect.height * zeroProgress)
            var zeroLine = Path()
            zeroLine.move(to: CGPoint(x: plotRect.minX, y: y))
            zeroLine.addLine(to: CGPoint(x: plotRect.maxX, y: y))
            context.stroke(zeroLine, with: .color(AppTheme.success.opacity(0.7)), lineWidth: 1.4)
        }

        let verticalFractions = [0.0, 0.25, 0.5, 0.75, 1.0]
        for fraction in verticalFractions {
            let x = plotRect.minX + (plotRect.width * fraction)
            var line = Path()
            line.move(to: CGPoint(x: x, y: plotRect.minY))
            line.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(line, with: .color(AppTheme.stroke.opacity(0.62)), lineWidth: 1)
        }
    }

    private func signedDecibelText(_ value: Double) -> String {
        String(format: "%+.1f dB", value)
    }
}

struct AdaptiveDashboard<Content: View>: View {
    var onBackgroundTap: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { geometry in
            let metrics = DashboardLayoutMetrics(size: geometry.size)
            let contentMinHeight = max(
                geometry.size.height
                    - metrics.topPadding
                    - metrics.bottomPadding,
                1
            )

            ZStack {
                LinearGradient(
                    colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(AppTheme.accent.opacity(0.12))
                    .frame(width: geometry.size.width >= 700 ? 340 : 240, height: geometry.size.width >= 700 ? 340 : 240)
                    .blur(radius: 40)
                    .offset(x: geometry.size.width * 0.28, y: -geometry.size.height * 0.18)

                Circle()
                    .fill(AppTheme.accentSoft.opacity(0.10))
                    .frame(width: geometry.size.width >= 700 ? 320 : 220, height: geometry.size.width >= 700 ? 320 : 220)
                    .blur(radius: 44)
                    .offset(x: -geometry.size.width * 0.25, y: geometry.size.height * 0.22)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: metrics.cardSpacing) {
                        content
                    }
                    .frame(maxWidth: .infinity, minHeight: contentMinHeight, alignment: .top)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.top, metrics.topPadding)
                    .padding(.bottom, metrics.bottomPadding)
                }
                .environment(\.dashboardLayoutMetrics, metrics)
                .scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(TapGesture().onEnded {
                    onBackgroundTap?()
                })
            }
        }
    }
}

struct DashboardLayoutMetrics {
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let cardSpacing: CGFloat
    let cardPadding: CGFloat
    let cardCornerRadius: CGFloat
    let statusIconSize: CGFloat
    let statusValueFontSize: CGFloat
    let primaryReadoutFontSize: CGFloat
    let sliderTrackHeight: CGFloat
    let sliderThumbSize: CGFloat
    let selectorVerticalPadding: CGFloat
    let selectorFontSize: CGFloat

    init(size: CGSize) {
        let width = size.width
        let height = size.height

        if width >= 700 {
            horizontalPadding = 24
            topPadding = 16
            bottomPadding = 28
            cardSpacing = 12
            cardPadding = 10
            cardCornerRadius = 22
            statusIconSize = 34
            statusValueFontSize = 20
            primaryReadoutFontSize = 36
            sliderTrackHeight = 11
            sliderThumbSize = 26
            selectorVerticalPadding = 11
            selectorFontSize = 13
        } else if width >= 430 || height >= 900 {
            horizontalPadding = 18
            topPadding = 10
            bottomPadding = 118
            cardSpacing = 9
            cardPadding = 9
            cardCornerRadius = 21
            statusIconSize = 34
            statusValueFontSize = 20
            primaryReadoutFontSize = 34
            sliderTrackHeight = 10
            sliderThumbSize = 25
            selectorVerticalPadding = 10
            selectorFontSize = 12
        } else if width >= 390 {
            horizontalPadding = 14
            topPadding = 8
            bottomPadding = 108
            cardSpacing = 8
            cardPadding = 9
            cardCornerRadius = 20
            statusIconSize = 33
            statusValueFontSize = 19
            primaryReadoutFontSize = 32
            sliderTrackHeight = 10
            sliderThumbSize = 24
            selectorVerticalPadding = 9
            selectorFontSize = 12
        } else {
            horizontalPadding = 10
            topPadding = 6
            bottomPadding = 98
            cardSpacing = 8
            cardPadding = 9
            cardCornerRadius = 20
            statusIconSize = 31
            statusValueFontSize = 18
            primaryReadoutFontSize = 30
            sliderTrackHeight = 10
            sliderThumbSize = 24
            selectorVerticalPadding = 8
            selectorFontSize = 11
        }
    }
}

private struct DashboardLayoutMetricsKey: EnvironmentKey {
    static let defaultValue = DashboardLayoutMetrics(size: CGSize(width: 402, height: 874))
}

extension EnvironmentValues {
    var dashboardLayoutMetrics: DashboardLayoutMetrics {
        get { self[DashboardLayoutMetricsKey.self] }
        set { self[DashboardLayoutMetricsKey.self] = newValue }
    }
}

struct DashboardColumn<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

struct InstrumentCard<Content: View>: View {
    var fill: Color = AppTheme.card
    @ViewBuilder let content: Content
    @Environment(\.dashboardLayoutMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .hardwarePanel(fill: fill, cornerRadius: metrics.cardCornerRadius)
    }
}

struct CompactStatusCard<Extra: View>: View {
    let icon: String
    let title: String
    let value: String
    let badge: String
    let auxiliary: String
    @ViewBuilder let extra: Extra
    @Environment(\.dashboardLayoutMetrics) private var metrics

    var body: some View {
        InstrumentCard(fill: AppTheme.cardStrong) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppTheme.accent.opacity(0.16))
                            .frame(width: metrics.statusIconSize, height: metrics.statusIconSize)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(value)
                            .font(.system(size: metrics.statusValueFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer(minLength: 8)

                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    Text(auxiliary)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }

                extra
            }
        }
    }
}

struct SettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}

struct InputRow: View {
    let field: InputField
    let title: String
    let placeholder: String
    @Binding var text: String
    let actionTitle: String
    let focusedField: FocusState<InputField?>.Binding
    let action: () -> Void
    @Environment(\.dashboardLayoutMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused(focusedField, equals: field)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .padding(.vertical, metrics.cardPadding)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: .infinity)
                    .onSubmit(action)
                Button(actionTitle, action: action)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

struct CompactInputCard: View {
    let field: InputField
    let title: String
    @Binding var text: String
    let focusedField: FocusState<InputField?>.Binding
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                TextField(String(localized: "placeholder.frequency"), text: $text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused(focusedField, equals: field)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(maxWidth: .infinity)
                    .onSubmit(action)
                Button(String(localized: "button.apply"), action: action)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChipGrid<T: Identifiable & Hashable>: View {
    let title: String
    @Binding var selection: T
    let items: [T]
    let columns: Int
    let label: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            LazyVGrid(columns: gridColumns(columns), spacing: 10) {
                ForEach(items) { item in
                    Button(label(item)) {
                        selection = item
                    }
                    .buttonStyle(ChipButtonStyle(isSelected: selection == item))
                }
            }
        }
    }
}

struct FrequencyStepSection<LeadingControls: View>: View {
    let title: String
    @Binding var mode: FrequencyStepMode
    @Binding var isExpanded: Bool
    let value: Double
    @ViewBuilder let leadingControls: LeadingControls
    let apply: (Double) -> Void
    let activeLabel: (Double) -> String

    var body: some View {
        let values = mode.values

        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(title: title)

            leadingControls

            ChipGrid(
                title: String(localized: "label.step_series"),
                selection: $mode,
                items: FrequencyStepMode.allCases,
                columns: 2,
                label: { $0.localizedTitle }
            )

            HStack(spacing: 8) {
                Button(String(localized: "button.previous_step")) {
                    apply(mode.previousValue(from: value))
                }
                .buttonStyle(SecondaryButtonStyle())

                Text(activeLabel(value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)

                Button(String(localized: "button.next_step")) {
                    apply(mode.nextValue(from: value))
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(isExpanded ? String(localized: "button.collapse_frequency_list") : String(localized: "button.expand_frequency_list"))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
            }
            .buttonStyle(SecondaryButtonStyle())

            if isExpanded {
                LazyVGrid(columns: gridColumns(4), spacing: 8) {
                    ForEach(values, id: \.self) { stepValue in
                        Button(FrequencyFormatting.stepLabelString(for: stepValue)) {
                            apply(stepValue)
                        }
                        .buttonStyle(ChipButtonStyle(isSelected: abs(value - stepValue) < 0.0001))
                    }
                }
            }
        }
    }
}

struct OutputMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SignalSpecificationRow: View {
    let name: String
    let standard: String
    let metric: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(standard)
                    .font(.caption2.monospaced())
                    .foregroundStyle(AppTheme.accent)
            }

            Text(metric)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

struct OutputTransportCard: View {
    @ObservedObject var audioController: AudioEngineController
    let outputGainQuickSteps: [Double]

    var body: some View {
        InstrumentCard(fill: AppTheme.cardStrong) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioController.outputRouteName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(audioController.outputRouteHint)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(2)
                }

                if audioController.isPlaying, audioController.selectedMode != .noise {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "output_metrics.title"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        HStack(spacing: 10) {
                            OutputMetricPill(
                                title: String(localized: "output_metrics.peak"),
                                value: digitalAmplitudeText(audioController.outputDigitalPeak)
                            )
                            OutputMetricPill(
                                title: String(localized: "output_metrics.rms"),
                                value: digitalAmplitudeText(audioController.outputDigitalRMS)
                            )
                            OutputMetricPill(
                                title: "dBFS",
                                value: digitalAmplitudeDecibelText(audioController.outputDigitalRMS)
                            )
                        }

                        Text(String(localized: "output_metrics.caption"))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(String(localized: "label.output_gain"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(outputGainValueText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.accent)
                    }

                    Slider(
                        value: Binding(
                            get: { audioController.outputGainDecibels },
                            set: { audioController.setOutputGain(decibels: $0) }
                        ),
                        in: audioController.minimumOutputGainDisplayDecibels ... audioController.maximumOutputGainDisplayDecibels
                    )
                    .tint(AppTheme.accent)

                    HStack {
                        Text("−∞ dB")
                        Spacer()
                        Text(String(format: "%+.0f dB", audioController.maximumOutputGainDisplayDecibels))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)

                    LazyVGrid(columns: gridColumns(4), spacing: 10) {
                        ForEach(outputGainQuickSteps, id: \.self) { step in
                            Button(outputGainQuickStepTitle(for: step)) {
                                adjustOutputGain(byDecibels: step)
                            }
                            .buttonStyle(ChipButtonStyle(isSelected: false))
                        }
                    }

                    if audioController.outputGainDecibels > 0.05 {
                        Text(String(localized: "output_gain.warning"))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if audioController.extendedExternalGainEnabled && audioController.supportsExtendedExternalGain {
                        Text(String(format: String(localized: "output_gain.expert_mode"), Int(audioController.extendedOutputGainMaximumDecibels)))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accent)
                    }

                    if audioController.selectedMode != .noise,
                       audioController.hasActiveCalibrationProfile,
                       audioController.isCalibrationCompensationEnabled
                    {
                        Text(String(format: String(localized: "calibration.current_compensation"), audioController.currentCompensationDecibels))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accent)
                    }

                    if audioController.outputClipWarningActive {
                        Text(String(localized: "output_gain.clip_warning"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.danger)
                    }
                }

                Button {
                    audioController.togglePlayback()
                } label: {
                    Label(transportButtonTitle, systemImage: transportButtonIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(TransportButtonStyle(background: transportButtonColor))
            }
        }
    }

    private var transportButtonTitle: String {
        audioController.isPlaying ? String(localized: "button.stop") : String(localized: "button.play")
    }

    private var transportButtonIcon: String {
        audioController.isPlaying ? "stop.fill" : "play.fill"
    }

    private var transportButtonColor: Color {
        audioController.isPlaying ? AppTheme.danger : AppTheme.success
    }

    private var outputGainValueText: String {
        if audioController.outputGainDecibels <= audioController.minimumOutputGainDisplayDecibels + 0.05 {
            return "−∞ dB"
        }

        let decibel = audioController.outputGainDecibels
        return abs(decibel) < 0.05 ? "0.0 dB" : String(format: "%+.1f dB", decibel)
    }

    private func outputGainQuickStepTitle(for step: Double) -> String {
        switch step {
        case -3:
            return String(localized: "button.output_gain_minus_3db")
        case -1:
            return String(localized: "button.output_gain_minus_1db")
        case 1:
            return String(localized: "button.output_gain_plus_1db")
        case 3:
            return String(localized: "button.output_gain_plus_3db")
        default:
            return String(format: "%+.0f dB", step)
        }
    }

    private func adjustOutputGain(byDecibels delta: Double) {
        audioController.setOutputGain(decibels: audioController.outputGainDecibels + delta)
    }

    private func digitalAmplitudeText(_ value: Double) -> String {
        String(format: "%.4f FS", value)
    }

    private func digitalAmplitudeDecibelText(_ value: Double) -> String {
        guard value > 0.0000001 else { return "−∞" }
        return String(format: "%.1f", 20.0 * log10(value))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 84)
            .background(AppTheme.accent.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AppTheme.accent.opacity(configuration.isPressed ? 0.14 : 0.26), radius: 8, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct TransportButtonStyle: ButtonStyle {
    let background: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(Color.black.opacity(0.88))
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(background.opacity(configuration.isPressed ? 0.84 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(AcousticTheme.controlBackground.opacity(configuration.isPressed ? 0.90 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.32), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 3)
    }
}

struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? Color.black.opacity(0.86) : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                isSelected
                    ? AppTheme.accent.opacity(configuration.isPressed ? 0.84 : 1)
                    : AcousticTheme.controlBackground.opacity(configuration.isPressed ? 0.92 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent.opacity(0.3) : AppTheme.stroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.18 : 0.26), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 3)
    }
}
