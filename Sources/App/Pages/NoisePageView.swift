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
            VStack(alignment: .leading, spacing: 8) {
                ChipGrid(
                    title: String(localized: "noise.type"),
                    selection: $audioController.noiseType,
                    items: AudioEngineController.NoiseType.allCases,
                    columns: 3,
                    label: { $0.localizedTitle }
                )

                ChipGrid(
                    title: String(localized: "noise.filter"),
                    selection: $audioController.noiseFilterMode,
                    items: AudioEngineController.FilterMode.allCases,
                    columns: 2,
                    label: { $0.localizedTitle }
                )
            }
        }
    }

    private var noiseCutoffCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 8) {
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

                Slider(
                    value: Binding(
                        get: { LogFrequencyScale.sliderValue(for: audioController.noiseCutoff) },
                        set: { audioController.setNoiseCutoff(LogFrequencyScale.frequency(for: $0)) }
                    ),
                    in: 0 ... 1
                )
                .tint(AppTheme.accent)

                if audioController.noiseFilterMode == .lowPass || audioController.noiseFilterMode == .highPass {
                    ChipGrid(
                        title: String(localized: "noise.filter_slope"),
                        selection: $audioController.noiseFilterSlope,
                        items: AudioEngineController.FilterSlope.allCases,
                        columns: 2,
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
                        .tint(AppTheme.accent)
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
}
