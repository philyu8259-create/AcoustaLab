import SwiftUI

struct PresetsPageView: View {
    @ObservedObject var audioController: AudioEngineController
    @ObservedObject var presetStore: PresetStore
    let focusedField: FocusState<InputField?>.Binding
    @Binding var presetName: String
    let dismissKeyboard: () -> Void
    let savePreset: () -> Void
    let loadPreset: (AppPreset) -> Void
    let deletePreset: (AppPreset) -> Void

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
                        Button(String(localized: "button.save_preset"), action: savePreset)
                            .buttonStyle(PrimaryButtonStyle())
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
            }
            .navigationTitle(String(localized: "tab.presets"))
            .navigationBarTitleDisplayMode(.inline)
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
            return "\(FrequencyFormatting.displayString(for: preset.sweepStartFrequency)) → \(FrequencyFormatting.displayString(for: preset.sweepEndFrequency))"
        case .noise:
            return preset.noiseType.localizedTitle
        }
    }
}
