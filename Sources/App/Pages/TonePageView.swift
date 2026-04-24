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
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: String(localized: "tone.frequency_control"))
                InputRow(
                    field: .toneFrequency,
                    title: String(localized: "label.frequency"),
                    placeholder: String(localized: "placeholder.frequency"),
                    text: $toneFrequencyText,
                    actionTitle: String(localized: "button.apply"),
                    focusedField: focusedField,
                    action: applyToneFrequencyText
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "tone.log_slider"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Slider(
                        value: Binding(
                            get: { LogFrequencyScale.sliderValue(for: audioController.clampedFrequency) },
                            set: { audioController.setFrequency(LogFrequencyScale.frequency(for: $0)) }
                        ),
                        in: 0 ... 1
                    )
                    .tint(AppTheme.accent)
                    HStack {
                        Text("1 Hz")
                        Spacer()
                        Text("32 kHz")
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var waveformControlCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 8) {
                ChipGrid(
                    title: String(localized: "label.waveform"),
                    selection: $audioController.waveform,
                    items: AudioEngineController.Waveform.allCases,
                    columns: 4,
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
}
