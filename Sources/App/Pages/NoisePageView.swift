import SwiftUI

struct NoisePageView: View {
    @ObservedObject var audioController: AudioEngineController
    let focusedField: FocusState<InputField?>.Binding
    @Binding var noiseCutoffText: String
    @Binding var noiseStepMode: FrequencyStepMode
    @Binding var noiseStepExpanded: Bool
    let outputGainQuickSteps: [Double]
    let dismissKeyboard: () -> Void
    let applyNoiseCutoffText: () -> Void

    var body: some View {
        NavigationStack {
            AdaptiveDashboard(onBackgroundTap: dismissKeyboard) {
                CompactStatusCard(
                    icon: "speaker.wave.3.fill",
                    title: String(localized: "tab.noise"),
                    value: audioController.noiseType.localizedTitle,
                    badge: audioController.noiseFilterMode.localizedTitle,
                    auxiliary: String(localized: "label.noise_mode")
                ) {
                    EmptyView()
                }

                OutputTransportCard(audioController: audioController, outputGainQuickSteps: outputGainQuickSteps)
                noiseModeCard
                noiseCutoffCard
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label(String(localized: "tab.noise"), systemImage: "aqi.medium")
        }
    }

    private var noiseModeCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 12) {
                HardwareCapsuleSelector(
                    title: String(localized: "noise.type"),
                    selection: $audioController.noiseType,
                    items: AudioEngineController.NoiseType.allCases,
                    accentColor: { $0.acousticAccentColor },
                    label: { $0.localizedTitle }
                )

                HardwareCapsuleSelector(
                    title: String(localized: "noise.filter"),
                    selection: $audioController.noiseFilterMode,
                    items: AudioEngineController.FilterMode.allCases,
                    accentColor: { $0.acousticAccentColor },
                    label: { $0.localizedTitle }
                )
            }
        }
    }

    private var noiseCutoffCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: noiseFrequencySectionTitle)
                InputRow(
                    field: .noiseCutoff,
                    title: noiseFrequencyInputTitle,
                    placeholder: String(localized: "placeholder.frequency"),
                    text: $noiseCutoffText,
                    actionTitle: String(localized: "button.apply"),
                    focusedField: focusedField,
                    action: applyNoiseCutoffText
                )

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(String(localized: "tone.log_slider"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(FrequencyFormatting.displayString(for: audioController.noiseCutoff))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(noiseAccentColor)
                    }

                    LogFrequencySlider(
                        frequency: Binding(
                            get: { audioController.noiseCutoff },
                            set: { audioController.setNoiseCutoff($0) }
                        ),
                        accentColor: noiseAccentColor
                    )

                    HStack {
                        Text("1 Hz")
                        Spacer()
                        Text("32 kHz")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
                }

                if audioController.noiseCutoff > 15_000 {
                    Text(String(localized: "noise.high_frequency_warning"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.danger)
                }

                if audioController.noiseFilterMode == .lowPass || audioController.noiseFilterMode == .highPass {
                    HardwareCapsuleSelector(
                        title: String(localized: "noise.filter_slope"),
                        selection: $audioController.noiseFilterSlope,
                        items: AudioEngineController.FilterSlope.allCases,
                        accentColor: { $0.acousticAccentColor },
                        label: { $0.localizedTitle }
                    )
                }

                if audioController.noiseFilterMode == .bandPass {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(String(localized: "noise.band_q"))
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(String(format: "Q %.1f", audioController.noiseBandQ))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.accent)
                        }
                        Slider(
                            value: Binding(
                                get: { audioController.noiseBandQ },
                                set: { audioController.setNoiseBandQ($0) }
                            ),
                            in: 0.5 ... 12.0
                        )
                        .tint(noiseAccentColor)
                    }
                }

                InstrumentCard {
                    FrequencyStepSection(
                        title: String(localized: "noise.step_mode"),
                        mode: $noiseStepMode,
                        isExpanded: $noiseStepExpanded,
                        value: audioController.noiseCutoff,
                        leadingControls: {
                            EmptyView()
                        },
                        apply: { audioController.setNoiseCutoff($0) },
                        activeLabel: { FrequencyFormatting.displayString(for: $0) }
                    )
                }
            }
        }
    }

    private var noiseFrequencySectionTitle: String {
        audioController.noiseFilterMode == .bandPass ? String(localized: "noise.center_frequency") : String(localized: "noise.cutoff")
    }

    private var noiseFrequencyInputTitle: String {
        audioController.noiseFilterMode == .bandPass ? String(localized: "noise.center_input") : String(localized: "noise.cutoff_input")
    }

    private var noiseAccentColor: Color {
        audioController.noiseFilterMode == .off ? audioController.noiseType.acousticAccentColor : audioController.noiseFilterMode.acousticAccentColor
    }
}
