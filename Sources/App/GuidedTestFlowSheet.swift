import SwiftUI

struct GuidedTestFlowSheet: View {
    private enum PlaybackState {
        case ready
        case playing
        case paused
        case awaitingResult
    }

    let plans: [GuidedTestPlan]
    @ObservedObject var historyStore: GuidedTestHistoryStore
    @ObservedObject var audioController: AudioEngineController
    let requestReviewAfterMeaningfulAction: (ReviewPromptCoordinator.Event) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var activePlan: GuidedTestPlan?
    @State private var currentStepIndex = 0
    @State private var stepResults: [GuidedTestStepResult] = []
    @State private var stepNotes: [String: String] = [:]
    @State private var playbackState: PlaybackState = .ready
    @State private var remainingSeconds = 0
    @State private var playbackRunID: UUID?
    @State private var completedRun: GuidedTestRun?

    var body: some View {
        NavigationStack {
            Group {
                if let completedRun {
                    completionView(for: completedRun)
                } else if let activePlan {
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
                        close()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .task(id: playbackRunID) {
            guard let runID = playbackRunID else { return }
            await runCountdown(for: runID)
        }
        .onDisappear {
            stopPlayback()
        }
    }

    private var planSelectionView: some View {
        AdaptiveDashboard {
            SectionTitle(title: String(localized: "guided_test.plan_selection_title"))

            InlineNotice(
                icon: "speaker.wave.2.fill",
                title: String(localized: "guided_test.safety_title"),
                message: String(localized: "guided_test.safety_body"),
                tone: .warning
            ) {
                EmptyView()
            }

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
                                    Label(
                                        String(format: String(localized: "guided_test.plan_step_count"), plan.steps.count),
                                        systemImage: "list.number"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textSecondary)

                                    Spacer()

                                    Button(String(localized: "guided_test.action_start_plan")) {
                                        start(plan)
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
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
                                .font(.caption.weight(.semibold).monospacedDigit())
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
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "guided_test.section_current_preset"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)

                                Text(LocalizedStringKey(currentPresetName(for: currentStep.preset)))
                                    .font(.headline.weight(.semibold))

                                Text(summaryText(for: currentStep.preset))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer()

                            playbackStatus(for: currentStep)
                        }

                        ProgressView(
                            value: Double(max(0, Int(currentStep.playbackDuration) - remainingSeconds)),
                            total: max(1, currentStep.playbackDuration)
                        )
                        .tint(playbackState == .awaitingResult ? AppTheme.success : AppTheme.accent)

                        HStack(spacing: 10) {
                            Button {
                                togglePlayback(for: currentStep)
                            } label: {
                                Label(playbackActionTitle, systemImage: playbackActionIcon)
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            Button {
                                beginPlayback(for: currentStep, resetCountdown: true)
                            } label: {
                                Label(String(localized: "guided_test.action_retest"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
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
                        .frame(minHeight: 76)
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                    }
                }

                VStack(spacing: 8) {
                    Text(String(localized: "guided_test.section_result"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(GuidedTestStepResultState.allCases, id: \.self) { state in
                            Button {
                                markStep(state, in: plan)
                            } label: {
                                Label(LocalizedStringKey(state.localizedKey), systemImage: icon(for: state))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .foregroundStyle(tint(for: state))
                        }
                    }
                }
            }
        }
    }

    private func completionView(for run: GuidedTestRun) -> some View {
        AdaptiveDashboard {
            InstrumentCard(fill: AppTheme.cardStrong) {
                VStack(spacing: 16) {
                    Image(systemName: run.anomalyCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(run.anomalyCount == 0 ? AppTheme.success : AppTheme.warning)

                    VStack(spacing: 6) {
                        Text(String(localized: "guided_test.completion_title"))
                            .font(.title3.weight(.bold))
                        Text(String(
                            format: String(localized: "guided_test.history_summary"),
                            run.passCount,
                            run.anomalyCount,
                            run.skippedCount
                        ))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    }

                    HStack(spacing: 8) {
                        resultMetric(value: run.passCount, key: "guided_test.step_result.pass", color: AppTheme.success)
                        resultMetric(value: run.anomalyCount, key: "guided_test.step_result.anomaly", color: AppTheme.warning)
                        resultMetric(value: run.skippedCount, key: "guided_test.step_result.skipped", color: AppTheme.textSecondary)
                    }

                    HStack(spacing: 10) {
                        ShareActionButton {
                            try GuidedTestShareRenderer.sharePayload(for: run)
                        } label: {
                            Label(String(localized: "guided_test.share_result"), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button(String(localized: "button.done")) {
                            close()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
        }
    }

    private func resultMetric(value: Int, key: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(LocalizedStringKey(key))
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func playbackStatus(for step: GuidedTestStep) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(playbackStatusTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(playbackState == .awaitingResult ? AppTheme.success : AppTheme.accent)
            Text(String(format: String(localized: "guided_test.playback_seconds"), remainingSeconds))
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: String(localized: "guided_test.playback_accessibility"), playbackStatusTitle, remainingSeconds))
    }

    private var playbackActionTitle: String {
        playbackState == .playing
            ? String(localized: "guided_test.action_pause")
            : String(localized: "guided_test.action_resume")
    }

    private var playbackActionIcon: String {
        playbackState == .playing ? "pause.fill" : "play.fill"
    }

    private var playbackStatusTitle: String {
        switch playbackState {
        case .ready:
            return String(localized: "guided_test.playback_ready")
        case .playing:
            return String(localized: "guided_test.playback_playing")
        case .paused:
            return String(localized: "guided_test.playback_paused")
        case .awaitingResult:
            return String(localized: "guided_test.playback_complete")
        }
    }

    private func start(_ plan: GuidedTestPlan) {
        guard let firstStep = plan.steps.first else { return }
        activePlan = plan
        currentStepIndex = 0
        stepResults = []
        stepNotes = [:]
        completedRun = nil
        beginPlayback(for: firstStep, resetCountdown: true)
    }

    private func togglePlayback(for step: GuidedTestStep) {
        if playbackState == .playing {
            audioController.stop()
            playbackRunID = nil
            playbackState = .paused
        } else {
            beginPlayback(for: step, resetCountdown: playbackState == .awaitingResult)
        }
    }

    private func beginPlayback(for step: GuidedTestStep, resetCountdown: Bool) {
        stopPlayback()
        audioController.applyPreset(step.preset)
        if resetCountdown || remainingSeconds <= 0 {
            remainingSeconds = max(1, Int(ceil(step.playbackDuration)))
        }
        playbackState = .playing
        playbackRunID = UUID()
        audioController.start()
        if !audioController.isPlaying {
            playbackRunID = nil
            remainingSeconds = 0
            playbackState = .awaitingResult
        }
    }

    private func runCountdown(for runID: UUID) async {
        while !Task.isCancelled, playbackRunID == runID, remainingSeconds > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, playbackRunID == runID else { return }
            remainingSeconds -= 1
        }

        guard !Task.isCancelled, playbackRunID == runID, remainingSeconds == 0 else { return }
        playbackState = .awaitingResult
        audioController.stop()
        playbackRunID = nil
    }

    private func stopPlayback() {
        playbackRunID = nil
        audioController.stop()
    }

    private func close() {
        stopPlayback()
        dismiss()
    }

    private func markStep(_ state: GuidedTestStepResultState, in plan: GuidedTestPlan) {
        stopPlayback()
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
            let orderedResults = plan.steps.compactMap { plannedStep in
                stepResults.first(where: { $0.stepID == plannedStep.id })
            }
            let run = GuidedTestRun(
                planID: plan.id,
                planNameKey: plan.nameKey,
                stepResults: orderedResults
            )
            historyStore.save(run)
            completedRun = run
            playbackState = .ready
            requestReviewAfterMeaningfulAction(.guidedTestCompleted)
        } else {
            currentStepIndex += 1
            let nextStep = plan.steps[currentStepIndex]
            beginPlayback(for: nextStep, resetCountdown: true)
        }
    }

    private func currentPresetName(for preset: AppPreset) -> String {
        preset.name
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
            return "forward.end.circle"
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
