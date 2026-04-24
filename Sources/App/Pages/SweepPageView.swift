import SwiftUI

struct SweepPageView: View {
    @ObservedObject var audioController: AudioEngineController
    let focusedField: FocusState<InputField?>.Binding
    @Binding var sweepStartText: String
    @Binding var sweepEndText: String
    @Binding var sweepStepTarget: SweepStepTarget
    @Binding var sweepStepExpanded: Bool
    let outputGainQuickSteps: [Double]
    let dismissKeyboard: () -> Void
    let applySweepStartText: () -> Void
    let applySweepEndText: () -> Void
    let applySweepStepValue: (Double) -> Void

    var body: some View {
        NavigationStack {
            AdaptiveDashboard(onBackgroundTap: dismissKeyboard) {
                CompactStatusCard(
                    icon: "dot.radiowaves.left.and.right",
                    title: String(localized: "tab.sweep"),
                    value: FrequencyFormatting.displayString(for: audioController.currentSweepFrequency),
                    badge: audioController.sweepMode.localizedTitle,
                    auxiliary: String(format: String(localized: "sweep.progress_compact"), Int(audioController.sweepProgress * 100))
                ) {
                    ProgressView(value: audioController.sweepProgress)
                        .tint(AppTheme.accent)
                }

                OutputTransportCard(audioController: audioController, outputGainQuickSteps: outputGainQuickSteps)
                sweepRangeCard
                sweepBehaviorCard
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label(String(localized: "tab.sweep"), systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
        }
    }

    private var sweepRangeCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: String(localized: "sweep.range"))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        CompactInputCard(
                            field: .sweepStart,
                            title: String(localized: "sweep.start"),
                            text: $sweepStartText,
                            focusedField: focusedField,
                            action: applySweepStartText
                        )
                        CompactInputCard(
                            field: .sweepEnd,
                            title: String(localized: "sweep.end"),
                            text: $sweepEndText,
                            focusedField: focusedField,
                            action: applySweepEndText
                        )
                    }
                    VStack(spacing: 12) {
                        CompactInputCard(
                            field: .sweepStart,
                            title: String(localized: "sweep.start"),
                            text: $sweepStartText,
                            focusedField: focusedField,
                            action: applySweepStartText
                        )
                        CompactInputCard(
                            field: .sweepEnd,
                            title: String(localized: "sweep.end"),
                            text: $sweepEndText,
                            focusedField: focusedField,
                            action: applySweepEndText
                        )
                    }
                }
                FrequencyStepSection(
                    title: String(localized: "sweep.step_mode"),
                    mode: $audioController.sweepStepMode,
                    isExpanded: $sweepStepExpanded,
                    value: currentSweepTargetValue,
                    leadingControls: {
                        ChipGrid(
                            title: String(localized: "sweep.step_target"),
                            selection: $sweepStepTarget,
                            items: SweepStepTarget.allCases,
                            columns: 2,
                            label: { $0.localizedTitle }
                        )
                    },
                    apply: applySweepStepValue,
                    activeLabel: { FrequencyFormatting.displayString(for: $0) }
                )
            }
        }
    }

    private var sweepBehaviorCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: String(localized: "sweep.behavior"))

                ChipGrid(
                    title: String(localized: "sweep.mode"),
                    selection: $audioController.sweepMode,
                    items: AudioEngineController.SweepMode.allCases,
                    columns: 2,
                    label: { $0.localizedTitle }
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(sweepDurationTitle)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(sweepDurationValueText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.accent)
                    }
                    if audioController.sweepMode == .sweep {
                        Slider(value: $audioController.sweepDuration, in: 1 ... 60, step: 1)
                            .tint(AppTheme.accent)
                    } else {
                        Slider(value: $audioController.sweepStepHoldDuration, in: 0.2 ... 10, step: 0.1)
                            .tint(AppTheme.accent)
                    }
                }

                if audioController.sweepMode == .sweep {
                    ChipGrid(
                        title: String(localized: "sweep.curve"),
                        selection: $audioController.sweepCurve,
                        items: AudioEngineController.SweepCurve.allCases,
                        columns: 2,
                        label: { $0.localizedTitle }
                    )
                }
            }
        }
    }

    private var currentSweepTargetValue: Double {
        sweepStepTarget == .start ? audioController.sweepStartFrequency : audioController.sweepEndFrequency
    }

    private var sweepDurationTitle: String {
        audioController.sweepMode == .sweep ? String(localized: "sweep.duration") : String(localized: "sweep.step_hold_duration")
    }

    private var sweepDurationValueText: String {
        if audioController.sweepMode == .sweep {
            return String(format: "%.0f s", audioController.sweepDuration)
        }
        return String(format: "%.1f s", audioController.sweepStepHoldDuration)
    }
}
