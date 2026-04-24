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
    @Environment(\.dashboardLayoutMetrics) private var metrics

    var body: some View {
        NavigationStack {
            AdaptiveDashboard(onBackgroundTap: dismissKeyboard) {
                CompactStatusCard(
                    icon: "waveform.path.ecg",
                    title: String(localized: "tab.tone"),
                    value: FrequencyFormatting.displayString(for: audioController.clampedFrequency),
                    badge: audioController.outputRouteName,
                    auxiliary: String(localized: "label.current_frequency")
                ) {
                    EmptyView()
                }

                OutputTransportCard(audioController: audioController, outputGainQuickSteps: outputGainQuickSteps)
                frequencyControlCard
                waveformControlCard
                toneStepCard
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label(String(localized: "tab.tone"), systemImage: "waveform")
        }
    }

    private var frequencyControlCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    SectionTitle(title: String(localized: "tone.frequency_control"))

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("FREQUENCY")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.textSecondary)
                            .tracking(1.6)

                        Text(frequencyReadoutText)
                            .font(.system(size: metrics.primaryReadoutFontSize - 4, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isDangerousFrequency ? AppTheme.danger : AcousticTheme.textPrimary)
                            .shadow(color: isDangerousFrequency ? AppTheme.danger.opacity(0.55) : selectedWaveAccent.opacity(0.22), radius: 7)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                }

                if isDangerousFrequency {
                    Text(String(localized: "tone.high_frequency_warning"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.danger)
                }

                InputRow(
                    field: .toneFrequency,
                    title: String(localized: "label.frequency"),
                    placeholder: String(localized: "placeholder.frequency"),
                    text: $toneFrequencyText,
                    actionTitle: String(localized: "button.apply"),
                    focusedField: focusedField,
                    action: applyToneFrequencyText
                )

                VStack(alignment: .leading, spacing: 3) {
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

    private var waveformControlCard: some View {
        InstrumentCard {
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

    private var toneStepCard: some View {
        InstrumentCard {
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
}
