import Foundation

enum GuidedTestStepResultState: String, Codable, CaseIterable {
    case pass
    case anomaly
    case skipped

    var localizedKey: String {
        switch self {
        case .pass:
            return "guided_test.step_result.pass"
        case .anomaly:
            return "guided_test.step_result.anomaly"
        case .skipped:
            return "guided_test.step_result.skipped"
        }
    }
}

struct GuidedTestStep: Identifiable, Codable, Equatable {
    let id: String
    let preset: AppPreset
    let descriptionKey: String
    let objectiveKey: String
}

struct GuidedTestPlan: Identifiable, Codable, Equatable {
    let id: String
    let nameKey: String
    let descriptionKey: String
    let steps: [GuidedTestStep]
}

struct GuidedTestStepResult: Identifiable, Codable, Equatable {
    let id: UUID
    let stepID: String
    let presetID: UUID
    let presetName: String
    let state: GuidedTestStepResultState
    let note: String?

    init(
        id: UUID = UUID(),
        stepID: String,
        presetID: UUID,
        presetName: String,
        state: GuidedTestStepResultState,
        note: String?
    ) {
        self.id = id
        self.stepID = stepID
        self.presetID = presetID
        self.presetName = presetName
        self.state = state
        self.note = note
    }
}

struct GuidedTestRun: Identifiable, Codable, Equatable {
    let id: UUID
    let planID: String
    let planNameKey: String
    let createdAt: Date
    var stepResults: [GuidedTestStepResult]

    init(
        id: UUID = UUID(),
        planID: String,
        planNameKey: String,
        createdAt: Date = Date(),
        stepResults: [GuidedTestStepResult]
    ) {
        self.id = id
        self.planID = planID
        self.planNameKey = planNameKey
        self.createdAt = createdAt
        self.stepResults = stepResults
    }

    var passCount: Int {
        stepResults.filter { $0.state == .pass }.count
    }

    var anomalyCount: Int {
        stepResults.filter { $0.state == .anomaly }.count
    }

    var skippedCount: Int {
        stepResults.filter { $0.state == .skipped }.count
    }

    var completedCount: Int {
        stepResults.count
    }
}

@MainActor
final class GuidedTestHistoryStore: ObservableObject {
    @Published private(set) var runs: [GuidedTestRun] = []

    private let defaultsKey = "audio_function_generator_guided_test_runs"
    private let maxHistoryCount = 30

    init() {
        load()
    }

    func save(_ run: GuidedTestRun) {
        if let existingIndex = runs.firstIndex(where: { $0.id == run.id }) {
            runs[existingIndex] = run
        } else {
            runs.insert(run, at: 0)
        }

        if runs.count > maxHistoryCount {
            runs = Array(runs.prefix(maxHistoryCount))
        }

        persist()
    }

    func delete(_ run: GuidedTestRun) {
        runs.removeAll { $0.id == run.id }
        persist()
    }

    var recentRuns: [GuidedTestRun] {
        runs.sorted { $0.createdAt > $1.createdAt }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            runs = try JSONDecoder().decode([GuidedTestRun].self, from: data)
        } catch {
            print("Failed to load guided test history: \(error)")
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(runs)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            print("Failed to save guided test history: \(error)")
        }
    }
}

enum GuidedTestPlanCatalog {
    static let plans: [GuidedTestPlan] = {
        let reference = BuiltInTestPresetCatalog.preset(for: "built_in_1khz_reference_tone")?.preset
        let speaker = BuiltInTestPresetCatalog.preset(for: "built_in_sine_sweep_speaker_check")?.preset
        let pink = BuiltInTestPresetCatalog.preset(for: "built_in_pink_noise_room_check")?.preset
        let white = BuiltInTestPresetCatalog.preset(for: "built_in_white_noise_floor_check")?.preset
        let left = BuiltInTestPresetCatalog.preset(for: "built_in_left_channel_check")?.preset
        let right = BuiltInTestPresetCatalog.preset(for: "built_in_right_channel_check")?.preset
        let lowFrequency = BuiltInTestPresetCatalog.preset(for: "built_in_low_frequency_response_check")?.preset

        let fallback = AppPreset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "guided_test.fallback_preset_name",
            mode: .single,
            frequency: 1000,
            waveform: .sine,
            sweepStartFrequency: 20,
            sweepEndFrequency: 20_000,
            sweepDuration: 10,
            sweepStepHoldDuration: 1.0,
            sweepCurve: .logarithmic,
            sweepMode: .sweep,
            sweepStepMode: .octave,
            noiseType: .white,
            noiseFilterMode: .off,
            noiseCutoff: 1000,
            noiseFilterSlope: .twentyFourDecibels,
            noiseBandQ: 4.3,
            channelMode: .stereo,
            outputGain: 0.5,
            safetyFadeEnabled: true
        )

        return [
            GuidedTestPlan(
                id: "guided_test_plan.acoustic_validation",
                nameKey: "guided_test.plan.acoustic_validation.name",
                descriptionKey: "guided_test.plan.acoustic_validation.description",
                steps: [
                    GuidedTestStep(
                        id: "guided_test_plan.acoustic_validation.reference_tone",
                        preset: reference ?? fallback,
                        descriptionKey: "guided_test.plan.acoustic_validation.step.reference_tone.description",
                        objectiveKey: "guided_test.plan.acoustic_validation.step.reference_tone.objective"
                    ),
                    GuidedTestStep(
                        id: "guided_test_plan.acoustic_validation.speaker_check",
                        preset: speaker ?? fallback,
                        descriptionKey: "guided_test.plan.acoustic_validation.step.speaker_check.description",
                        objectiveKey: "guided_test.plan.acoustic_validation.step.speaker_check.objective"
                    ),
                    GuidedTestStep(
                        id: "guided_test_plan.acoustic_validation.pink_noise",
                        preset: pink ?? fallback,
                        descriptionKey: "guided_test.plan.acoustic_validation.step.pink_noise.description",
                        objectiveKey: "guided_test.plan.acoustic_validation.step.pink_noise.objective"
                    ),
                    GuidedTestStep(
                        id: "guided_test_plan.acoustic_validation.white_noise",
                        preset: white ?? fallback,
                        descriptionKey: "guided_test.plan.acoustic_validation.step.white_noise.description",
                        objectiveKey: "guided_test.plan.acoustic_validation.step.white_noise.objective"
                    ),
                    GuidedTestStep(
                        id: "guided_test_plan.acoustic_validation.left_channel",
                        preset: left ?? fallback,
                        descriptionKey: "guided_test.plan.acoustic_validation.step.left_channel.description",
                        objectiveKey: "guided_test.plan.acoustic_validation.step.left_channel.objective"
                    ),
                    GuidedTestStep(
                        id: "guided_test_plan.acoustic_validation.right_channel",
                        preset: right ?? fallback,
                        descriptionKey: "guided_test.plan.acoustic_validation.step.right_channel.description",
                        objectiveKey: "guided_test.plan.acoustic_validation.step.right_channel.objective"
                    ),
                    GuidedTestStep(
                        id: "guided_test_plan.acoustic_validation.low_frequency",
                        preset: lowFrequency ?? fallback,
                        descriptionKey: "guided_test.plan.acoustic_validation.step.low_frequency.description",
                        objectiveKey: "guided_test.plan.acoustic_validation.step.low_frequency.objective"
                    )
                ]
            )
        ]
    }()
}
