import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var audioController = AudioEngineController()
    @StateObject private var presetStore = PresetStore()
    @StateObject private var membershipStore = MembershipStore()

    @State private var selectedTab: RootTab = .tone
    @State private var isMembershipSheetPresented = false
    @State private var toneFrequencyText = FrequencyFormatting.textFieldString(for: 1000)
    @State private var sweepStartText = FrequencyFormatting.textFieldString(for: 20)
    @State private var sweepEndText = FrequencyFormatting.textFieldString(for: 20_000)
    @State private var noiseCutoffText = FrequencyFormatting.textFieldString(for: 1000)
    @State private var presetName = ""
    @FocusState private var focusedField: InputField?
    @State private var toneStepMode: FrequencyStepMode = .octave
    @State private var noiseStepMode: FrequencyStepMode = .octave
    @State private var sweepStepTarget: SweepStepTarget = .end
    @State private var toneStepExpanded = false
    @State private var sweepStepExpanded = false
    @State private var noiseStepExpanded = false

    private let toneNudgeSteps: [Double] = [-100, -1, 1, 100]
    private let outputGainQuickSteps: [Double] = [-3, -1, 1, 3]

    var body: some View {
        TabView(selection: $selectedTab) {
            toneTab
            .tag(RootTab.tone)

            sweepTab
            .tag(RootTab.sweep)

            noiseTab
            .tag(RootTab.noise)

            presetsTab
            .tag(RootTab.presets)

            SettingsPageView(
                audioController: audioController,
                membershipStore: membershipStore,
                dismissKeyboard: dismissKeyboard,
                resetToDefaults: resetToDefaults,
                showMembership: showMembership
            )
            .tag(RootTab.settings)
        }
        .tint(AppTheme.accent)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "button.dismiss_keyboard")) {
                    dismissKeyboard()
                }
            }
        }
        .onAppear {
            syncAllInputFields()
            selectedTab = RootTab(mode: audioController.selectedMode)
        }
        .task {
            await membershipStore.configure()
        }
        .sheet(isPresented: $isMembershipSheetPresented) {
            MembershipPaywallView(membershipStore: membershipStore) {
                isMembershipSheetPresented = false
            }
            .presentationDetents([.large])
            .preferredColorScheme(.dark)
        }
        .onChange(of: selectedTab) { _, newValue in
            audioController.stop()
            guard membershipStore.hasCoreAccess else { return }
            if let mode = newValue.signalMode {
                audioController.selectedMode = mode
            }
        }
        .onChange(of: membershipStore.hasCoreAccess) { _, hasCoreAccess in
            if !hasCoreAccess {
                audioController.stop()
            }
        }
        .onChange(of: audioController.frequency) { _, _ in syncToneInput() }
        .onChange(of: audioController.sweepStartFrequency) { _, _ in syncSweepStartInput() }
        .onChange(of: audioController.sweepEndFrequency) { _, _ in syncSweepEndInput() }
        .onChange(of: audioController.noiseCutoff) { _, _ in syncNoiseCutoffInput() }
        .onChange(of: toneStepMode) { _, _ in ensureToneFrequencyFitsStepMode() }
        .onChange(of: audioController.sweepStepMode) { _, _ in ensureSweepFrequencyFitsStepMode() }
        .onChange(of: noiseStepMode) { _, _ in ensureNoiseFrequencyFitsStepMode() }
    }

    @ViewBuilder
    private var toneTab: some View {
        if membershipStore.hasCoreAccess {
            TonePageView(
                audioController: audioController,
                focusedField: $focusedField,
                toneFrequencyText: $toneFrequencyText,
                toneStepMode: $toneStepMode,
                toneStepExpanded: $toneStepExpanded,
                toneNudgeSteps: toneNudgeSteps,
                outputGainQuickSteps: outputGainQuickSteps,
                dismissKeyboard: dismissKeyboard,
                applyToneFrequencyText: applyToneFrequencyText
            )
        } else {
            MembershipLockedPage(
                featureTitle: String(localized: "tab.tone"),
                membershipStore: membershipStore,
                showMembership: showMembership
            )
            .tabItem {
                Label(String(localized: "tab.tone"), systemImage: "waveform")
            }
        }
    }

    @ViewBuilder
    private var sweepTab: some View {
        if membershipStore.hasCoreAccess {
            SweepPageView(
                audioController: audioController,
                focusedField: $focusedField,
                sweepStartText: $sweepStartText,
                sweepEndText: $sweepEndText,
                sweepStepTarget: $sweepStepTarget,
                sweepStepExpanded: $sweepStepExpanded,
                outputGainQuickSteps: outputGainQuickSteps,
                dismissKeyboard: dismissKeyboard,
                applySweepStartText: applySweepStartText,
                applySweepEndText: applySweepEndText,
                applySweepStepValue: applySweepStepValue
            )
        } else {
            MembershipLockedPage(
                featureTitle: String(localized: "tab.sweep"),
                membershipStore: membershipStore,
                showMembership: showMembership
            )
            .tabItem {
                Label(String(localized: "tab.sweep"), systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
        }
    }

    @ViewBuilder
    private var noiseTab: some View {
        if membershipStore.hasCoreAccess {
            NoisePageView(
                audioController: audioController,
                focusedField: $focusedField,
                noiseCutoffText: $noiseCutoffText,
                noiseStepMode: $noiseStepMode,
                noiseStepExpanded: $noiseStepExpanded,
                outputGainQuickSteps: outputGainQuickSteps,
                dismissKeyboard: dismissKeyboard,
                applyNoiseCutoffText: applyNoiseCutoffText
            )
        } else {
            MembershipLockedPage(
                featureTitle: String(localized: "tab.noise"),
                membershipStore: membershipStore,
                showMembership: showMembership
            )
            .tabItem {
                Label(String(localized: "tab.noise"), systemImage: "aqi.medium")
            }
        }
    }

    @ViewBuilder
    private var presetsTab: some View {
        if membershipStore.hasCoreAccess {
            PresetsPageView(
                audioController: audioController,
                presetStore: presetStore,
                focusedField: $focusedField,
                presetName: $presetName,
                dismissKeyboard: dismissKeyboard,
                savePreset: savePreset,
                loadPreset: loadPreset,
                deletePreset: deletePreset
            )
        } else {
            MembershipLockedPage(
                featureTitle: String(localized: "tab.presets"),
                membershipStore: membershipStore,
                showMembership: showMembership
            )
            .tabItem {
                Label(String(localized: "tab.presets"), systemImage: "square.stack")
            }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
#if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    private func showMembership() {
        isMembershipSheetPresented = true
    }

    private func applySweepStepValue(_ value: Double) {
        switch sweepStepTarget {
        case .start:
            audioController.setSweepStartFrequency(value)
        case .end:
            audioController.setSweepEndFrequency(value)
        }
    }

    private func ensureToneFrequencyFitsStepMode() {
        guard !toneStepMode.contains(audioController.frequency) else { return }
        audioController.setFrequency(toneStepMode.defaultStart)
    }

    private func ensureSweepFrequencyFitsStepMode() {
        let stepMode = audioController.sweepStepMode
        let value = sweepStepTarget == .start ? audioController.sweepStartFrequency : audioController.sweepEndFrequency
        guard !stepMode.contains(value) else { return }
        applySweepStepValue(stepMode.defaultStart)
        syncSweepStartInput()
        syncSweepEndInput()
    }

    private func ensureNoiseFrequencyFitsStepMode() {
        guard !noiseStepMode.contains(audioController.noiseCutoff) else { return }
        audioController.setNoiseCutoff(noiseStepMode.defaultStart)
        syncNoiseCutoffInput()
    }

    private func applyToneFrequencyText() {
        applyFrequencyText(toneFrequencyText) { audioController.setFrequency($0) }
        syncToneInput()
    }

    private func applySweepStartText() {
        applyFrequencyText(sweepStartText) { audioController.setSweepStartFrequency($0) }
        syncSweepStartInput()
        syncSweepEndInput()
    }

    private func applySweepEndText() {
        applyFrequencyText(sweepEndText) { audioController.setSweepEndFrequency($0) }
        syncSweepStartInput()
        syncSweepEndInput()
    }

    private func applyNoiseCutoffText() {
        applyFrequencyText(noiseCutoffText) { audioController.setNoiseCutoff($0) }
        syncNoiseCutoffInput()
    }

    private func savePreset() {
        let trimmed = presetName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? defaultPresetName() : trimmed
        presetStore.create(name: finalName, from: audioController)
        presetName = ""
    }

    private func loadPreset(_ preset: AppPreset) {
        audioController.applyPreset(preset)
        syncAllInputFields()
        selectedTab = RootTab(mode: preset.mode)
    }

    private func deletePreset(_ preset: AppPreset) {
        presetStore.delete(preset)
    }

    private func resetToDefaults() {
        audioController.resetToDefaults()
        syncAllInputFields()
        selectedTab = RootTab(mode: audioController.selectedMode)
    }

    private func defaultPresetName() -> String {
        switch audioController.selectedMode {
        case .single:
            return "\(FrequencyFormatting.displayString(for: audioController.frequency)) \(audioController.waveform.localizedTitle)"
        case .sweep:
            return "\(audioController.sweepMode.localizedTitle) \(FrequencyFormatting.displayString(for: audioController.sweepStartFrequency)) - \(FrequencyFormatting.displayString(for: audioController.sweepEndFrequency))"
        case .noise:
            return audioController.noiseType.localizedTitle
        }
    }

    private func applyFrequencyText(_ text: String, apply: (Double) -> Void) {
        let sanitized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(sanitized) else { return }
        apply(value)
    }

    private func syncAllInputFields() {
        syncToneInput()
        syncSweepStartInput()
        syncSweepEndInput()
        syncNoiseCutoffInput()
    }

    private func syncToneInput() {
        toneFrequencyText = FrequencyFormatting.textFieldString(for: audioController.clampedFrequency)
    }

    private func syncSweepStartInput() {
        sweepStartText = FrequencyFormatting.textFieldString(for: audioController.sweepStartFrequency)
    }

    private func syncSweepEndInput() {
        sweepEndText = FrequencyFormatting.textFieldString(for: audioController.sweepEndFrequency)
    }

    private func syncNoiseCutoffInput() {
        noiseCutoffText = FrequencyFormatting.textFieldString(for: audioController.noiseCutoff)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
