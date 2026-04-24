import SwiftUI

struct SettingsPageView: View {
    @ObservedObject var audioController: AudioEngineController
    let outputGainQuickSteps: [Double]
    let dismissKeyboard: () -> Void
    let resetToDefaults: () -> Void

    var body: some View {
        NavigationStack {
            AdaptiveDashboard(onBackgroundTap: dismissKeyboard) {
                CompactStatusCard(
                    icon: "slider.horizontal.3",
                    title: String(localized: "tab.settings"),
                    value: audioController.isPlaying ? String(localized: "status.playing") : String(localized: "status.stopped"),
                    badge: audioController.outputRouteName,
                    auxiliary: "\(Int(audioController.sampleRate)) Hz"
                ) {
                    EmptyView()
                }

                OutputTransportCard(audioController: audioController, outputGainQuickSteps: outputGainQuickSteps)
                routeOverviewCard
                playbackCard
                calibrationCard
                signalSpecificationsCard
                channelCard
                resetCard
            }
            .navigationTitle(String(localized: "tab.settings"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .tabItem {
            Label(String(localized: "tab.settings"), systemImage: "gearshape")
        }
    }

    private var routeOverviewCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: String(localized: "settings.route_overview"))

                Text(String(localized: "settings.route_overview_body"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        routeBadges
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        routeBadges
                    }
                }

                LazyVGrid(columns: gridColumns(2), spacing: 10) {
                    DetailTile(
                        title: String(localized: "settings.route"),
                        value: audioController.outputRouteName,
                        caption: audioController.outputRouteHint
                    )
                    DetailTile(
                        title: String(localized: "settings.input"),
                        value: audioController.inputRouteName,
                        caption: audioController.inputRouteHint,
                        accentColor: audioController.calibrationInputSuitable ? .white : AppTheme.danger
                    )
                    DetailTile(
                        title: String(localized: "settings.sample_rate"),
                        value: "\(Int(audioController.sampleRate)) Hz"
                    )
                    DetailTile(
                        title: String(localized: "calibration.readiness"),
                        value: audioController.loopbackCalibrationStatus,
                        caption: audioController.loopbackCalibrationStatusDetail,
                        accentColor: calibrationStatusTone.foreground
                    )
                }

                LazyVGrid(columns: gridColumns(2), spacing: 10) {
                    DetailTile(
                        title: String(localized: "settings.route_key_output"),
                        value: audioController.currentOutputRouteKey,
                        caption: String(localized: "settings.route_key_output_body"),
                        monospaced: true,
                        accentColor: AppTheme.accent
                    )
                    DetailTile(
                        title: String(localized: "settings.route_key_input"),
                        value: audioController.currentInputRouteKey,
                        caption: String(localized: "settings.route_key_input_body"),
                        monospaced: true,
                        accentColor: audioController.calibrationInputSuitable ? AppTheme.success : AppTheme.warning
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    SubsectionHeader(title: String(localized: "settings.route_identity"))

                    Text(audioController.calibrationRouteDescriptionText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var playbackCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: String(localized: "settings.playback"))

                Text(String(localized: "settings.playback_body"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Toggle(String(localized: "settings.fade"), isOn: $audioController.safetyFadeEnabled)
                    .tint(AppTheme.accent)

                Toggle(String(localized: "settings.awake"), isOn: $audioController.keepScreenAwake)
                    .tint(AppTheme.accent)

                Divider()
                    .overlay(AppTheme.stroke)

                SubsectionHeader(
                    title: String(localized: "settings.external_high_gain"),
                    caption: externalHighGainStatusText
                )

                Toggle(String(localized: "settings.external_high_gain"), isOn: $audioController.extendedExternalGainEnabled)
                    .tint(AppTheme.accent)
                    .disabled(!audioController.supportsExtendedExternalGain)
            }
        }
    }

    private var calibrationCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: String(localized: "calibration.title"))

                Text(String(localized: "calibration.body"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        calibrationBadges
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        calibrationBadges
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SubsectionHeader(
                        title: String(localized: "calibration.readiness"),
                        caption: String(localized: "calibration.readiness_body")
                    )

                    DetailTile(
                        title: String(localized: "calibration.active_status"),
                        value: audioController.loopbackCalibrationStatus,
                        caption: audioController.loopbackCalibrationStatusDetail,
                        accentColor: calibrationStatusTone.foreground
                    )

                    if audioController.isLoopbackCalibrationRunning {
                        VStack(alignment: .leading, spacing: 10) {
                            LazyVGrid(columns: gridColumns(2), spacing: 10) {
                                DetailTile(
                                    title: String(localized: "calibration.active_step"),
                                    value: String(
                                        format: String(localized: "calibration.active_step_value"),
                                        audioController.loopbackCalibrationCurrentStepNumber,
                                        max(audioController.loopbackCalibrationTotalSteps, 1)
                                    ),
                                    caption: audioController.loopbackCalibrationCurrentFrequency > 0
                                        ? FrequencyFormatting.displayString(for: audioController.loopbackCalibrationCurrentFrequency)
                                        : String(localized: "calibration.running_progress"),
                                    monospaced: true,
                                    accentColor: AppTheme.accent
                                )
                                DetailTile(
                                    title: String(localized: "calibration.phase_label"),
                                    value: audioController.loopbackCalibrationPhaseTitle,
                                    caption: audioController.loopbackCalibrationStatusDetail,
                                    accentColor: calibrationStatusTone.foreground
                                )
                                DetailTile(
                                    title: String(localized: "calibration.remaining_label"),
                                    value: audioController.loopbackCalibrationRemainingText,
                                    caption: String(localized: "calibration.remaining_body"),
                                    monospaced: true,
                                    accentColor: AppTheme.accent
                                )
                                DetailTile(
                                    title: String(localized: "calibration.plan_label"),
                                    value: audioController.calibrationStepMode.localizedTitle,
                                    caption: audioController.loopbackCalibrationPlanSummaryText,
                                    accentColor: .white
                                )
                            }

                            ProgressView(value: audioController.loopbackCalibrationProgress)
                                .tint(AppTheme.accent)

                            Text(
                                String(
                                    format: String(localized: "calibration.progress_value"),
                                    Int((audioController.loopbackCalibrationProgress * 100).rounded())
                                )
                            )
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                        }
                    } else if audioController.hasActiveCalibrationProfile {
                        DetailTile(
                            title: String(localized: "calibration.result_summary_label"),
                            value: audioController.activeCalibrationProfileDisplayName,
                            caption: audioController.calibrationResultSummaryText,
                            accentColor: AppTheme.success
                        )
                    }

                    if shouldShowFailureNotice {
                        InlineNotice(
                            icon: "exclamationmark.octagon",
                            title: String(localized: "calibration.failure_notice_title"),
                            message: audioController.loopbackCalibrationStatusDetail,
                            tone: .danger
                        ) {
                            if shouldShowPreferExternalAction {
                                Button(String(localized: "calibration.input_switch_auto")) {
                                    audioController.selectPreferredExternalCalibrationInput()
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            } else {
                                EmptyView()
                            }
                        }
                    } else if shouldShowInputGuidanceNotice {
                        InlineNotice(
                            icon: "arrow.triangle.branch",
                            title: String(localized: "calibration.input_attention_title"),
                            message: String(localized: "calibration.input_attention_body"),
                            tone: .warning
                        ) {
                            Button(String(localized: "calibration.input_switch_auto")) {
                                audioController.selectPreferredExternalCalibrationInput()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(audioController.isLoopbackCalibrationRunning)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        SubsectionHeader(
                            title: String(localized: "calibration.input_switch"),
                            caption: String(localized: "calibration.input_switch_body")
                        )
                        Spacer()
                        Button(String(localized: "calibration.input_switch_auto")) {
                            audioController.selectPreferredExternalCalibrationInput()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(audioController.isLoopbackCalibrationRunning)
                    }

                    if !audioController.availableCalibrationInputs.isEmpty {
                        LazyVGrid(columns: gridColumns(2), spacing: 10) {
                            ForEach(audioController.availableCalibrationInputs) { input in
                                calibrationInputButton(for: input)
                            }
                        }
                    } else {
                        Text(String(localized: "calibration.input_switch_empty"))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SubsectionHeader(
                        title: String(localized: "calibration.profile_section"),
                        caption: String(localized: "calibration.profile_section_body")
                    )

                    LazyVGrid(columns: gridColumns(2), spacing: 10) {
                        DetailTile(
                            title: String(localized: "calibration.profile_label"),
                            value: audioController.activeCalibrationProfileDisplayName,
                            caption: audioController.hasActiveCalibrationProfile ? audioController.calibrationProfileSummaryText : nil,
                            accentColor: audioController.hasActiveCalibrationProfile ? AppTheme.success : AppTheme.warning
                        )
                        DetailTile(
                            title: String(localized: "calibration.updated_label"),
                            value: audioController.calibrationProfileUpdatedText,
                            monospaced: true
                        )
                    }

                    LazyVGrid(columns: gridColumns(2), spacing: 10) {
                        DetailTile(
                            title: String(localized: "calibration.route_binding"),
                            value: audioController.currentOutputRouteKey,
                            caption: String(localized: "calibration.route_binding_body"),
                            monospaced: true,
                            accentColor: AppTheme.accent
                        )
                        DetailTile(
                            title: String(localized: "calibration.profile_inventory"),
                            value: String(
                                format: String(localized: "calibration.profile_inventory_value"),
                                audioController.currentRouteCalibrationProfiles.count
                            ),
                            caption: String(localized: "calibration.profile_inventory_body"),
                            accentColor: audioController.currentRouteCalibrationProfiles.isEmpty ? AppTheme.warning : AppTheme.success
                        )
                    }

                    if let analysis = activeCalibrationAnalysis {
                        if let activeProfile = audioController.activeCalibrationProfile {
                            CalibrationCurveView(profile: activeProfile, analysis: analysis)
                        }

                        LazyVGrid(columns: gridColumns(2), spacing: 10) {
                            DetailTile(
                                title: String(localized: "calibration.coverage_label"),
                                value: frequencyRangeText(
                                    start: analysis.coverageStart,
                                    end: analysis.coverageEnd
                                ),
                                caption: String(localized: "calibration.coverage_body"),
                                accentColor: .white
                            )
                            DetailTile(
                                title: String(localized: "calibration.correction_range_label"),
                                value: correctionRangeText(for: analysis),
                                caption: String(
                                    format: String(localized: "calibration.average_offset_body"),
                                    magnitudeDecibelText(analysis.averageAbsoluteCorrection)
                                ),
                                accentColor: AppTheme.accent
                            )
                            DetailTile(
                                title: String(localized: "calibration.hotspot_label"),
                                value: hotspotText(for: analysis.strongestCorrectionPoint),
                                caption: String(localized: "calibration.hotspot_body"),
                                accentColor: analysis.hasStrongHotspot ? AppTheme.warning : .white
                            )
                            DetailTile(
                                title: String(localized: "calibration.reference_anchor_label"),
                                value: anchorText(for: analysis.referencePoint),
                                caption: String(localized: "calibration.reference_anchor_body"),
                                accentColor: AppTheme.success
                            )
                        }

                        if analysis.shouldWarn {
                            InlineNotice(
                                icon: "waveform.badge.exclamationmark",
                                title: String(localized: "calibration.insight_notice_title"),
                                message: insightNoticeMessage(for: analysis),
                                tone: .warning
                            ) {
                                EmptyView()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "calibration.profile_name"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        TextField(
                            String(localized: "calibration.profile_name_placeholder"),
                            text: $audioController.calibrationProfileDraftName
                        )
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .disabled(audioController.isLoopbackCalibrationRunning)

                        if audioController.hasActiveCalibrationProfile,
                           audioController.calibrationProfileDraftName.trimmingCharacters(in: .whitespacesAndNewlines) != audioController.activeCalibrationProfileDisplayName
                        {
                            Button(String(localized: "calibration.rename_button")) {
                                audioController.renameActiveCalibrationProfile(to: audioController.calibrationProfileDraftName)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(audioController.isLoopbackCalibrationRunning)
                        }
                    }

                    if !audioController.currentRouteCalibrationProfiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "calibration.saved_profiles"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)

                            LazyVGrid(columns: gridColumns(2), spacing: 10) {
                                ForEach(audioController.currentRouteCalibrationProfiles) { profile in
                                    Button(profile.displayName) {
                                        audioController.selectCalibrationProfile(profile.id)
                                    }
                                    .buttonStyle(ChipButtonStyle(isSelected: audioController.activeCalibrationProfile?.id == profile.id))
                                    .disabled(audioController.isLoopbackCalibrationRunning)
                                }
                            }
                        }
                    }

                    Toggle(
                        String(localized: "calibration.enable_compensation"),
                        isOn: Binding(
                            get: { audioController.isCalibrationCompensationEnabled },
                            set: { audioController.setCalibrationCompensationEnabled($0) }
                        )
                    )
                    .tint(AppTheme.accent)
                    .disabled(!audioController.hasActiveCalibrationProfile || audioController.isLoopbackCalibrationRunning)

                    if audioController.hasActiveCalibrationProfile,
                       audioController.selectedMode != .noise,
                       audioController.isCalibrationCompensationEnabled
                    {
                        Text(String(format: String(localized: "calibration.current_compensation"), audioController.currentCompensationDecibels))
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SubsectionHeader(
                        title: String(localized: "calibration.setup_section"),
                        caption: String(localized: "calibration.setup_section_body")
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "calibration.step_mode"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        LazyVGrid(columns: gridColumns(2), spacing: 10) {
                            ForEach(FrequencyStepMode.allCases) { mode in
                                Button(mode.localizedTitle) {
                                    audioController.calibrationStepMode = mode
                                }
                                .buttonStyle(ChipButtonStyle(isSelected: audioController.calibrationStepMode == mode))
                                .disabled(audioController.isLoopbackCalibrationRunning)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(localized: "calibration.reference_frequency"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)

                        LazyVGrid(columns: gridColumns(3), spacing: 10) {
                            ForEach(audioController.calibrationReferenceOptions, id: \.self) { reference in
                                Button(FrequencyFormatting.displayString(for: reference)) {
                                    audioController.calibrationReferenceFrequency = reference
                                }
                                .buttonStyle(ChipButtonStyle(isSelected: abs(audioController.calibrationReferenceFrequency - reference) < 0.0001))
                                .disabled(audioController.isLoopbackCalibrationRunning)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    SubsectionHeader(
                        title: String(localized: "calibration.actions_section"),
                        caption: String(localized: "calibration.actions_section_body")
                    )

                    HStack(spacing: 10) {
                        Button(audioController.isLoopbackCalibrationRunning ? String(localized: "calibration.stop_button") : String(localized: "calibration.start_button")) {
                            if audioController.isLoopbackCalibrationRunning {
                                audioController.cancelLoopbackCalibration()
                            } else {
                                audioController.startLoopbackCalibration()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        if audioController.hasActiveCalibrationProfile {
                            Button(String(localized: "calibration.delete_button"), role: .destructive) {
                                audioController.deleteCurrentCalibrationProfile()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(audioController.isLoopbackCalibrationRunning)
                        }
                    }
                }
            }
        }
    }

    private var signalSpecificationsCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: String(localized: "settings.specifications"))

                SignalSpecificationRow(
                    name: String(localized: "signal_spec.white_noise.name"),
                    standard: String(localized: "signal_spec.white_noise.standard"),
                    metric: String(localized: "signal_spec.white_noise.metric")
                )
                SignalSpecificationRow(
                    name: String(localized: "signal_spec.pink_noise.name"),
                    standard: String(localized: "signal_spec.pink_noise.standard"),
                    metric: String(localized: "signal_spec.pink_noise.metric")
                )
                SignalSpecificationRow(
                    name: String(localized: "signal_spec.brown_noise.name"),
                    standard: String(localized: "signal_spec.brown_noise.standard"),
                    metric: String(localized: "signal_spec.brown_noise.metric")
                )
                SignalSpecificationRow(
                    name: String(localized: "signal_spec.tone.name"),
                    standard: String(localized: "signal_spec.tone.standard"),
                    metric: String(localized: "signal_spec.tone.metric")
                )
                SignalSpecificationRow(
                    name: String(localized: "signal_spec.sweep.name"),
                    standard: String(localized: "signal_spec.sweep.standard"),
                    metric: String(localized: "signal_spec.sweep.metric")
                )

                Text(String(localized: "settings.specifications_hint"))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var channelCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: String(localized: "settings.channel"))
                HardwareCapsuleSelector(
                    title: String(localized: "label.channel"),
                    selection: $audioController.channelMode,
                    items: AudioEngineController.ChannelMode.allCases,
                    accentColor: { $0.acousticAccentColor },
                    label: { $0.localizedTitle }
                )
            }
        }
    }

    private var resetCard: some View {
        InstrumentCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: String(localized: "settings.reset"))
                Button(String(localized: "button.reset_defaults"), action: resetToDefaults)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var routeBadges: some View {
        StatusBadge(
            title: audioController.isExternalOutputRoute
                ? String(localized: "settings.badge_external_route")
                : String(localized: "settings.badge_device_route"),
            tone: audioController.isExternalOutputRoute ? .accent : .neutral,
            icon: audioController.isExternalOutputRoute ? "cable.connector" : "speaker.wave.2"
        )

        StatusBadge(
            title: audioController.calibrationInputSuitable
                ? String(localized: "settings.badge_loopback_ready")
                : String(localized: "settings.badge_input_attention"),
            tone: audioController.calibrationInputSuitable ? .success : .warning,
            icon: audioController.calibrationInputSuitable ? "checkmark.circle" : "exclamationmark.triangle"
        )

        if audioController.supportsExtendedExternalGain {
            StatusBadge(
                title: String(localized: "settings.badge_high_gain"),
                tone: .accent,
                icon: "arrow.up.circle"
            )
        }
    }

    @ViewBuilder
    private var calibrationBadges: some View {
        StatusBadge(
            title: calibrationStatusBadgeTitle,
            tone: calibrationStatusTone,
            icon: calibrationStatusIcon
        )

        StatusBadge(
            title: audioController.hasActiveCalibrationProfile
                ? String(localized: "calibration.status_badge_profile")
                : String(localized: "calibration.status_badge_no_profile"),
            tone: audioController.hasActiveCalibrationProfile ? .success : .warning,
            icon: audioController.hasActiveCalibrationProfile ? "checkmark.circle" : "tray"
        )
    }

    private func calibrationInputButton(for input: AudioEngineController.CalibrationInputOption) -> some View {
        let isSelected = audioController.selectedCalibrationInputID == input.id
        let isDisabled = audioController.isLoopbackCalibrationRunning

        return Button {
            audioController.selectCalibrationInput(input.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(input.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.86) : .white)
                        .lineLimit(2)

                    Spacer(minLength: 6)

                    if input.isLoopbackCapable {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.7) : AppTheme.success)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.black.opacity(0.7) : AppTheme.warning)
                    }
                }

                Text(input.detail)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.black.opacity(0.7) : AppTheme.textSecondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? AppTheme.accent.opacity(isDisabled ? 0.72 : 1)
                    : Color.white.opacity(isDisabled ? 0.05 : 0.08)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? AppTheme.accent.opacity(0.32)
                            : (input.isLoopbackCapable ? AppTheme.stroke : AppTheme.warning.opacity(0.34)),
                        lineWidth: 1
                    )
            )
        }
        .disabled(isDisabled)
    }

    private var calibrationStatusTone: StatusBadgeTone {
        if audioController.isLoopbackCalibrationRunning {
            return .accent
        }
        if shouldShowFailureNotice {
            return .danger
        }
        if !audioController.calibrationInputSuitable {
            return .warning
        }
        if audioController.hasActiveCalibrationProfile {
            return .success
        }
        return .accent
    }

    private var calibrationStatusBadgeTitle: String {
        if audioController.isLoopbackCalibrationRunning {
            return String(localized: "calibration.status_badge_running")
        }
        if shouldShowFailureNotice {
            return String(localized: "calibration.status_badge_failed")
        }
        if !audioController.calibrationInputSuitable {
            return String(localized: "calibration.status_badge_attention")
        }
        if audioController.hasActiveCalibrationProfile {
            return String(localized: "calibration.status_badge_complete")
        }
        return String(localized: "calibration.status_badge_ready")
    }

    private var calibrationStatusIcon: String {
        if audioController.isLoopbackCalibrationRunning {
            return "waveform"
        }
        if shouldShowFailureNotice {
            return "xmark.octagon"
        }
        if !audioController.calibrationInputSuitable {
            return "exclamationmark.triangle"
        }
        if audioController.hasActiveCalibrationProfile {
            return "checkmark.circle"
        }
        return "slider.horizontal.3"
    }

    private var externalHighGainStatusText: String {
        if audioController.supportsExtendedExternalGain {
            return String(format: String(localized: "settings.external_high_gain_body"), Int(audioController.extendedOutputGainMaximumDecibels))
        }

        if audioController.isExternalOutputRoute {
            return String(localized: "settings.external_high_gain_limited")
        }

        return String(localized: "settings.external_high_gain_unavailable")
    }

    private var shouldShowFailureNotice: Bool {
        let failureStatus = String(localized: "calibration.status_failed")
        let failureDetails = [
            String(localized: "calibration.status_permission_denied"),
            String(localized: "calibration.status_failed_builtin_input"),
            String(localized: "calibration.status_failed_no_signal")
        ]

        return audioController.loopbackCalibrationStatus == failureStatus
            || failureDetails.contains(audioController.loopbackCalibrationStatusDetail)
    }

    private var shouldShowInputGuidanceNotice: Bool {
        !audioController.isLoopbackCalibrationRunning
            && !shouldShowFailureNotice
            && !audioController.calibrationInputSuitable
    }

    private var shouldShowPreferExternalAction: Bool {
        !audioController.isLoopbackCalibrationRunning
            && !audioController.availableCalibrationInputs.isEmpty
    }

    private var activeCalibrationAnalysis: CalibrationProfileAnalysis? {
        audioController.activeCalibrationProfile?.analysis
    }

    private func frequencyRangeText(start: Double, end: Double) -> String {
        "\(FrequencyFormatting.displayString(for: start)) - \(FrequencyFormatting.displayString(for: end))"
    }

    private func correctionRangeText(for analysis: CalibrationProfileAnalysis) -> String {
        "\(signedDecibelText(analysis.minCorrectionPoint.compensationDecibels)) to \(signedDecibelText(analysis.maxCorrectionPoint.compensationDecibels))"
    }

    private func hotspotText(for point: CalibrationPoint) -> String {
        "\(signedDecibelText(point.compensationDecibels)) @ \(FrequencyFormatting.displayString(for: point.frequency))"
    }

    private func anchorText(for point: CalibrationPoint) -> String {
        "\(FrequencyFormatting.displayString(for: point.frequency)) / \(signedDecibelText(point.compensationDecibels))"
    }

    private func signedDecibelText(_ value: Double) -> String {
        String(format: "%+.1f dB", value)
    }

    private func magnitudeDecibelText(_ value: Double) -> String {
        String(format: "%.1f dB", abs(value))
    }

    private func insightNoticeMessage(for analysis: CalibrationProfileAnalysis) -> String {
        var messages: [String] = []

        if analysis.hasWideCorrectionSpan {
            messages.append(
                String(
                    format: String(localized: "calibration.insight_notice_span"),
                    magnitudeDecibelText(analysis.correctionSpread)
                )
            )
        }

        if analysis.hasStrongHotspot {
            messages.append(
                String(
                    format: String(localized: "calibration.insight_notice_hotspot"),
                    signedDecibelText(analysis.strongestCorrectionPoint.compensationDecibels),
                    FrequencyFormatting.displayString(for: analysis.strongestCorrectionPoint.frequency)
                )
            )
        }

        return messages.joined(separator: "\n")
    }
}
