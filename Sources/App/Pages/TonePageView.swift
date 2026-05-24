import SwiftUI

struct TonePageView: View {
    @ObservedObject var audioController: AudioEngineController
    let focusedField: FocusState<InputField?>.Binding
    @Binding var toneFrequencyText: String
    @Binding var toneStepMode: FrequencyStepMode
    @Binding var toneStepExpanded: Bool
    let toneNudgeSteps: [Double]
    let outputGainQuickSteps: [Double]
    let dismissKeyboard: () -> Void
    let applyToneFrequencyText: () -> Void

    var body: some View {
        NavigationStack {
            AdaptiveDashboard(onBackgroundTap: dismissKeyboard) { metrics in
                toneMonitorCard(metrics: metrics)
                waveformControlCard(metrics: metrics)
                toneStepCard(metrics: metrics)
                frequencyControlCard(metrics: metrics)
                OutputTransportCard(
                    audioController: audioController,
                    outputGainQuickSteps: outputGainQuickSteps,
                    minHeight: metrics.toneTransportMinHeight
                )
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label(String(localized: "tab.tone"), systemImage: "waveform")
        }
    }

    private func toneMonitorCard(metrics: DashboardLayoutMetrics) -> some View {
        InstrumentCard(fill: AppTheme.cardStrong, minHeight: metrics.toneMonitorMinHeight) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.accent.opacity(0.16))
                            .frame(width: metrics.statusIconSize, height: metrics.statusIconSize)
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }

                    Spacer(minLength: 0)
                    StatusBadge(title: audioController.outputRouteName, tone: .accent)
                }

                HStack(alignment: .center, spacing: 10) {
                    PrecisionDisplay(
                        value: String(format: "%.1f", audioController.clampedFrequency),
                        unit: "Hz",
                        label: "Oscillator I",
                        accentColor: selectedWaveAccent,
                        valueFontSize: metrics.primaryReadoutFontSize + 8
                    )
                    .frame(maxWidth: .infinity)

                    OscilloscopeDisplay(
                        label: audioController.waveform.localizedTitle,
                        waveType: oscilloscopeWaveType,
                        frequency: audioController.clampedFrequency,
                        isRunning: audioController.isPlaying,
                        accentColor: selectedWaveAccent
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func frequencyControlCard(metrics: DashboardLayoutMetrics) -> some View {
        InstrumentCard(minHeight: metrics.toneFrequencyMinHeight) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        VStack(alignment: .leading, spacing: 0) {
                            SectionTitle(title: String(localized: "tone.frequency_control"))

                            Text(frequencyReadoutText)
                                .font(.system(size: metrics.primaryReadoutFontSize - 12, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(isDangerousFrequency ? AppTheme.danger : AcousticTheme.textPrimary)
                                .shadow(color: isDangerousFrequency ? AppTheme.danger.opacity(0.55) : selectedWaveAccent.opacity(0.22), radius: 6)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }

                        if isDangerousFrequency {
                            Text(String(localized: "tone.high_frequency_warning"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.danger)
                        }

                        compactFrequencyInputRow
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    PrecisionKnob(
                        value: frequencyKnobBinding,
                        title: "Fine Tune",
                        unit: "%",
                        accentColor: selectedWaveAccent,
                        compact: false,
                        medium: true
                    )
                    .frame(width: 98)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(String(localized: "tone.log_slider"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)

                    LogFrequencySlider(
                        frequency: Binding(
                            get: { audioController.clampedFrequency },
                            set: { audioController.setFrequency($0) }
                        ),
                        accentColor: selectedWaveAccent
                    )

                    HStack {
                        Text("1 Hz")
                        Spacer()
                        Text("32 kHz")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func waveformControlCard(metrics: DashboardLayoutMetrics) -> some View {
        InstrumentCard(minHeight: metrics.toneWaveformMinHeight) {
            VStack(alignment: .leading, spacing: 12) {
                HardwareCapsuleSelector(
                    title: String(localized: "label.waveform"),
                    selection: $audioController.waveform,
                    items: AudioEngineController.Waveform.allCases,
                    accentColor: { $0.acousticAccentColor },
                    label: { $0.localizedTitle }
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "tone.nudge"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    LazyVGrid(columns: gridColumns(4), spacing: 10) {
                        ForEach(toneNudgeSteps, id: \.self) { step in
                            Button(stepLabel(for: step)) {
                                audioController.nudgeFrequency(by: step)
                            }
                            .buttonStyle(ChipButtonStyle(isSelected: false))
                        }
                    }
                }
            }
        }
    }

    private var compactFrequencyInputRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(String(localized: "label.frequency"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)

            HStack(spacing: 7) {
                TextField(String(localized: "placeholder.frequency"), text: $toneFrequencyText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .focused(focusedField, equals: .toneFrequency)
                    .submitLabel(.done)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .frame(width: 150)
                    .onSubmit(applyToneFrequencyText)

                Button(String(localized: "button.apply"), action: applyToneFrequencyText)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private func toneStepCard(metrics: DashboardLayoutMetrics) -> some View {
        InstrumentCard(minHeight: metrics.toneStepMinHeight) {
            FrequencyStepSection(
                title: String(localized: "tone.step_mode"),
                mode: $toneStepMode,
                isExpanded: $toneStepExpanded,
                value: audioController.frequency,
                leadingControls: {
                    EmptyView()
                },
                apply: { audioController.setFrequency($0) },
                activeLabel: { FrequencyFormatting.displayString(for: $0) }
            )
        }
    }

    private func stepLabel(for step: Double) -> String {
        if abs(step) < 1 {
            return String(format: "%+.1f Hz", step)
        }
        return String(format: "%+.0f Hz", step)
    }

    private var selectedWaveAccent: Color {
        audioController.waveform.acousticAccentColor
    }

    private var isDangerousFrequency: Bool {
        audioController.clampedFrequency > 15_000
    }

    private var frequencyReadoutText: String {
        String(format: "%.1f Hz", audioController.clampedFrequency)
    }

    private var compactFrequencyValueText: String {
        let frequency = audioController.clampedFrequency
        if frequency >= 1_000 {
            return String(format: "%.1f", frequency / 1_000)
        }
        return String(format: "%.0f", frequency)
    }

    private var frequencyKnobBinding: Binding<Double> {
        Binding(
            get: {
                let logMin = log10(1.0)
                let logMax = log10(32_000.0)
                let logValue = log10(max(1.0, min(audioController.clampedFrequency, 32_000.0)))
                return (logValue - logMin) / (logMax - logMin)
            },
            set: { newValue in
                let clampedValue = max(0, min(1, newValue))
                let logMin = log10(1.0)
                let logMax = log10(32_000.0)
                let frequency = pow(10, logMin + (clampedValue * (logMax - logMin)))
                audioController.setFrequency(frequency)
            }
        )
    }

    private var oscilloscopeWaveType: String {
        switch audioController.waveform {
        case .sine:
            return "sine"
        case .square:
            return "square"
        case .triangle:
            return "triangle"
        case .saw:
            return "saw"
        }
    }
}
