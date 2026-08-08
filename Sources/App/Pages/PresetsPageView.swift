import SwiftUI
import UniformTypeIdentifiers

struct PresetsPageView: View {
    @ObservedObject var audioController: AudioEngineController
    @ObservedObject var presetStore: PresetStore
    @ObservedObject var guidedTestHistoryStore: GuidedTestHistoryStore
    let focusedField: FocusState<InputField?>.Binding
    @Binding var presetName: String
    let dismissKeyboard: () -> Void
    let savePreset: () -> Void
    let loadPreset: (AppPreset) -> Void
    let deletePreset: (AppPreset) -> Void
    let builtInPresets: [BuiltInTestPreset]
    let guidedTestPlans: [GuidedTestPlan]
    let requestReviewAfterMeaningfulAction: (ReviewPromptCoordinator.Event) -> Void

    @State private var isGuidedTestSheetPresented = false
    @State private var isPresetImporterPresented = false
    @State private var presetImportMessage: String?
    private static let historyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            AdaptiveDashboard(onBackgroundTap: dismissKeyboard) {
                CompactStatusCard(
                    icon: "square.stack.3d.up.fill",
                    title: String(localized: "tab.presets"),
                    value: "\(presetStore.presets.count)",
                    badge: String(localized: "tab.presets"),
                    auxiliary: String(localized: "presets.count_compact")
                ) {
                    EmptyView()
                }

                if !guidedTestPlans.isEmpty {
                    InstrumentCard(fill: AppTheme.cardStrong) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: String(localized: "guided_test.flow_title"))
                            Text(String(localized: "guided_test.flow_subtitle"))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            Button(String(localized: "guided_test.action_start")) {
                                isGuidedTestSheetPresented = true
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                }

                if !builtInPresets.isEmpty {
                    InstrumentCard(fill: AppTheme.cardStrong) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: String(localized: "presets.builtin_title"))
                            Text(String(localized: "presets.builtin_subtitle"))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)

                            VStack(spacing: 10) {
                                ForEach(builtInPresets) { preset in
                                    builtInPresetRow(for: preset)
                                }
                            }
                        }
                    }
                }

                InstrumentCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: String(localized: "presets.save_current"))
                        TextField(String(localized: "presets.name_placeholder"), text: $presetName)
                            .textFieldStyle(.plain)
                            .focused(focusedField, equals: .presetName)
                            .submitLabel(.done)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        HStack(spacing: 10) {
                            Button(String(localized: "button.save_preset"), action: savePreset)
                                .buttonStyle(PrimaryButtonStyle())

                            Button {
                                isPresetImporterPresented = true
                            } label: {
                                Label(String(localized: "presets.import"), systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }

                if presetStore.presets.isEmpty {
                    InstrumentCard {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionTitle(title: String(localized: "presets.empty_title"))
                            Text(String(localized: "presets.empty_body"))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        ForEach(presetStore.presets) { preset in
                            InstrumentCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(preset.name)
                                                .font(.headline.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Text(preset.mode.localizedTitle)
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                        Spacer()
                                        Text(summaryText(for: preset))
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(AppTheme.accent)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(AppTheme.accent.opacity(0.12))
                                            .clipShape(Capsule())
                                    }

                                    HStack(spacing: 10) {
                                        Button(String(localized: "button.load")) {
                                            loadPreset(preset)
                                        }
                                        .buttonStyle(SecondaryButtonStyle())

                                        ShareActionButton {
                                            try PresetFileTransfer.sharePayload(for: preset)
                                        } label: {
                                            Image(systemName: "square.and.arrow.up")
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .accessibilityLabel(String(localized: "presets.share"))

                                        Button(String(localized: "button.delete"), role: .destructive) {
                                            deletePreset(preset)
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                }

                if !guidedTestHistoryStore.recentRuns.isEmpty {
                    InstrumentCard(fill: AppTheme.cardStrong) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: String(localized: "guided_test.history_title"))

                            ForEach(Array(guidedTestHistoryStore.recentRuns.prefix(5)), id: \.id) { run in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(LocalizedStringKey(run.planNameKey))
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)

                                            Text(Self.historyDateFormatter.string(from: run.createdAt))
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }

                                        Spacer()

                                        ShareActionButton {
                                            try GuidedTestShareRenderer.sharePayload(for: run)
                                        } label: {
                                            Image(systemName: "square.and.arrow.up")
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .accessibilityLabel(String(localized: "guided_test.share_result"))

                                        Button(role: .destructive) {
                                            guidedTestHistoryStore.delete(run)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                    }

                                    Text(String(
                                        format: String(localized: "guided_test.history_summary"),
                                        run.passCount,
                                        run.anomalyCount,
                                        run.skippedCount
                                    ))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                }
                                .padding(.vertical, 4)

                                if run.id != guidedTestHistoryStore.recentRuns.prefix(5).last?.id {
                                    Divider().overlay(Color.white.opacity(0.12))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "tab.presets"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isGuidedTestSheetPresented) {
            GuidedTestFlowSheet(
                plans: guidedTestPlans,
                historyStore: guidedTestHistoryStore,
                audioController: audioController,
                requestReviewAfterMeaningfulAction: requestReviewAfterMeaningfulAction
            )
            .presentationDetents([.large])
            .preferredColorScheme(.dark)
        }
        .fileImporter(
            isPresented: $isPresetImporterPresented,
            allowedContentTypes: [.acoustaLabPreset, .json],
            allowsMultipleSelection: false,
            onCompletion: importPreset
        )
        .alert(String(localized: "presets.import_result_title"), isPresented: Binding(
            get: { presetImportMessage != nil },
            set: { if !$0 { presetImportMessage = nil } }
        )) {
            Button(String(localized: "button.done"), role: .cancel) {}
        } message: {
            Text(presetImportMessage ?? "")
        }
        .tabItem {
            Label(String(localized: "tab.presets"), systemImage: "square.stack")
        }
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

    private func importPreset(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let isSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let preset = try PresetFileTransfer.preset(from: data)
            presetStore.save(preset)
            presetImportMessage = String(
                format: String(localized: "presets.import_success"),
                preset.name
            )
        } catch {
            presetImportMessage = String(
                format: String(localized: "presets.import_failed"),
                error.localizedDescription
            )
        }
    }

    private func builtInPresetRow(for preset: BuiltInTestPreset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(preset.nameKey))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(preset.preset.mode.localizedTitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Text(summaryText(for: preset.preset))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.accent.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(LocalizedStringKey(preset.descriptionKey))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Button {
                loadPreset(preset.preset)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2.weight(.semibold))
                    Text(String(localized: "button.apply_test_preset"))
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}
