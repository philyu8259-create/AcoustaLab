import SwiftUI

struct GuidedTestFlowSheet: View {
    let plans: [GuidedTestPlan]
    @ObservedObject var historyStore: GuidedTestHistoryStore
    let applyPreset: (AppPreset) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var activePlan: GuidedTestPlan?
    @State private var currentStepIndex = 0
    @State private var stepResults: [GuidedTestStepResult] = []
    @State private var stepNotes: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if let activePlan {
                    guidedTestStepsView(for: activePlan)
                } else {
                    planSelectionView
                }
            }
            .navigationTitle(String(localized: "guided_test.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "button.cancel")) {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                if activePlan != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(String(localized: "guided_test.action_exit")) {
                            dismiss()
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private var planSelectionView: some View {
        AdaptiveDashboard {
            SectionTitle(title: String(localized: "guided_test.plan_selection_title"))

            if plans.isEmpty {
                InlineNotice(
                    icon: "exclamationmark.triangle",
                    title: String(localized: "guided_test.plan_selection_empty_title"),
                    message: String(localized: "guided_test.plan_selection_empty_body"),
                    tone: .warning
                ) {
                    EmptyView()
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(plans) { plan in
                        InstrumentCard(fill: AppTheme.cardStrong) {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringKey(plan.nameKey))
                                        .font(.headline.weight(.semibold))

                                    Text(LocalizedStringKey(plan.descriptionKey))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }

                                HStack {
                                    Text(String(format: String(localized: "guided_test.plan_step_count"), plan.steps.count))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textSecondary)

                                    Spacer()

                                    Button(String(localized: "guided_test.action_start_plan")) {
                                        start(plan)
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func guidedTestStepsView(for plan: GuidedTestPlan) -> some View {
        AdaptiveDashboard {
            let currentStep = plan.steps[currentStepIndex]
            let progressValue = Double(currentStepIndex + 1) / Double(plan.steps.count)

            VStack(alignment: .leading, spacing: 12) {
                InstrumentCard(fill: AppTheme.cardStrong) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(LocalizedStringKey(plan.nameKey))
                                    .font(.headline.weight(.semibold))

                                Text(String(localized: "guided_test.step_progress"))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()

                            Text("\(currentStepIndex + 1)/\(plan.steps.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.accent.opacity(0.18))
                                .clipShape(Capsule())
                        }

                        ProgressView(value: progressValue)
                            .tint(AppTheme.accent)
                    }
                }

                InstrumentCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "guided_test.section_current_preset"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(currentPresetName(for: currentStep.preset)))
                                .font(.subheadline.weight(.semibold))

                            Text(summaryText(for: currentStep.preset))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        Button(String(localized: "guided_test.action_apply_preset")) {
                            applyPreset(currentStep.preset)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }

                InstrumentCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "guided_test.section_usage"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(LocalizedStringKey(currentStep.descriptionKey))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        Text(String(localized: "guided_test.section_objective"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.top, 4)

                        Text(LocalizedStringKey(currentStep.objectiveKey))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                InstrumentCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "guided_test.section_note"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        TextEditor(text: Binding(
                            get: { stepNotes[currentStep.id] ?? "" },
                            set: { stepNotes[currentStep.id] = $0 }
                        ))
                        .frame(minHeight: 90)
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                    }
                }

                VStack(spacing: 8) {
                    Text(String(localized: "guided_test.section_result"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: gridColumns(2), spacing: 8) {
                        ForEach(GuidedTestStepResultState.allCases, id: \.self) { state in
                            Button {
                                markStep(state, in: plan)
                            } label: {
                                Label(
                                    LocalizedStringKey(state.localizedKey),
                                    systemImage: icon(for: state)
                                )
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .foregroundStyle(tint(for: state))
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func start(_ plan: GuidedTestPlan) {
        activePlan = plan
        currentStepIndex = 0
        stepResults = []
        stepNotes = [:]
    }

    private func markStep(_ state: GuidedTestStepResultState, in plan: GuidedTestPlan) {
        let step = plan.steps[currentStepIndex]
        let note = stepNotes[step.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNote = note?.isEmpty == true ? nil : note
        let result = GuidedTestStepResult(
            stepID: step.id,
            presetID: step.preset.id,
            presetName: currentPresetName(for: step.preset),
            state: state,
            note: normalizedNote
        )

        if let existingIndex = stepResults.firstIndex(where: { $0.stepID == step.id }) {
            stepResults[existingIndex] = result
        } else {
            stepResults.append(result)
        }

        if currentStepIndex + 1 >= plan.steps.count {
            let orderedResults = plan.steps.compactMap { step in
                stepResults.first(where: { $0.stepID == step.id })
            }
            let run = GuidedTestRun(
                planID: plan.id,
                planNameKey: plan.nameKey,
                stepResults: orderedResults
            )
            historyStore.save(run)
            dismiss()
        } else {
            currentStepIndex += 1
        }
    }

    private func currentPresetName(for preset: AppPreset) -> String {
        return preset.name
    }

    private func summaryText(for preset: AppPreset) -> String {
        switch preset.mode {
        case .single:
            return FrequencyFormatting.displayString(for: preset.frequency)
        case .sweep:
            return "\(FrequencyFormatting.displayString(for: preset.sweepStartFrequency)) - \(FrequencyFormatting.displayString(for: preset.sweepEndFrequency))"
        case .noise:
            return preset.noiseType.localizedTitle
        }
    }

    private func icon(for state: GuidedTestStepResultState) -> String {
        switch state {
        case .pass:
            return "checkmark.circle"
        case .anomaly:
            return "exclamationmark.triangle.fill"
        case .skipped:
            return "pause.circle"
        }
    }

    private func tint(for state: GuidedTestStepResultState) -> Color {
        switch state {
        case .pass:
            return AppTheme.success
        case .anomaly:
            return AppTheme.warning
        case .skipped:
            return AppTheme.textSecondary
        }
    }
}
