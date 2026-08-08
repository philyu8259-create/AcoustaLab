import XCTest
@testable import AudioFunctionGenerator

final class AudioFunctionGeneratorTests: XCTestCase {
    func testLogFrequencyScaleRoundTripsRepresentativeValues() {
        for frequency in [1.0, 20.0, 440.0, 1_000.0, 20_000.0, 32_000.0] {
            let sliderValue = LogFrequencyScale.sliderValue(for: frequency)
            let roundTripped = LogFrequencyScale.frequency(for: sliderValue)
            XCTAssertEqual(roundTripped, frequency, accuracy: max(0.0001, frequency * 0.000001))
        }
    }

    func testSteppedSweepIncludesRequestedRangeBoundaries() {
        let frequencies = steppedSweepFrequencies(start: 30, end: 18_000, stepMode: .octave)

        XCTAssertEqual(frequencies.first, 30)
        XCTAssertEqual(frequencies.last, 18_000)
        XCTAssertEqual(frequencies, frequencies.sorted())
    }

    func testGuidedPlansHaveSafePlayableSteps() {
        let plans = GuidedTestPlanCatalog.plans

        XCTAssertFalse(plans.isEmpty)
        for plan in plans {
            XCTAssertFalse(plan.steps.isEmpty)
            XCTAssertEqual(Set(plan.steps.map(\.id)).count, plan.steps.count)
            XCTAssertTrue(plan.steps.allSatisfy { $0.playbackDuration >= 1 && $0.playbackDuration <= 30 })
            XCTAssertTrue(plan.steps.allSatisfy { $0.preset.outputGain >= 0 && $0.preset.outputGain <= 1 })
        }
    }

    func testButterworthStageCountMatchesSelectedSlope() {
        XCTAssertEqual(butterworthQValues(for: .twelveDecibels).count, 1)
        XCTAssertEqual(butterworthQValues(for: .twentyFourDecibels).count, 2)
        XCTAssertEqual(butterworthQValues(for: .fortyEightDecibels).count, 4)
    }

    func testFixedSweepStopsAfterRequestedRoundsAndIntervals() {
        let active = AudioEngineController.sweepState(
            at: 21.9,
            start: 20,
            end: 20_000,
            duration: 10,
            stepHoldDuration: 1,
            curve: .logarithmic,
            mode: .sweep,
            steppedFrequencies: [],
            repeatMode: .fixed,
            repeatCount: 2,
            direction: .forward,
            loopInterval: 2
        )
        let completed = AudioEngineController.sweepState(
            at: 22,
            start: 20,
            end: 20_000,
            duration: 10,
            stepHoldDuration: 1,
            curve: .logarithmic,
            mode: .sweep,
            steppedFrequencies: [],
            repeatMode: .fixed,
            repeatCount: 2,
            direction: .forward,
            loopInterval: 2
        )

        XCTAssertFalse(active.shouldStop)
        XCTAssertTrue(completed.shouldStop)
        XCTAssertFalse(completed.isToneActive)
        XCTAssertEqual(completed.iteration, 2)
    }

    func testRoundTripReturnsToStartFrequency() {
        let returning = AudioEngineController.sweepState(
            at: 15,
            start: 100,
            end: 1_000,
            duration: 10,
            stepHoldDuration: 1,
            curve: .linear,
            mode: .sweep,
            steppedFrequencies: [],
            repeatMode: .continuous,
            repeatCount: 3,
            direction: .roundTrip,
            loopInterval: 0
        )

        XCTAssertEqual(returning.phase, .returning)
        XCTAssertEqual(returning.frequency, 550, accuracy: 0.001)
        XCTAssertEqual(returning.iteration, 1)
    }

    func testContinuousSweepFadesAcrossZeroIntervalBoundary() {
        let beforeBoundary = AudioEngineController.sweepState(
            at: 9.995,
            start: 20,
            end: 20_000,
            duration: 10,
            stepHoldDuration: 1,
            curve: .logarithmic,
            mode: .sweep,
            steppedFrequencies: [],
            repeatMode: .continuous,
            repeatCount: 3,
            direction: .forward,
            loopInterval: 0
        )
        let afterBoundary = AudioEngineController.sweepState(
            at: 10.005,
            start: 20,
            end: 20_000,
            duration: 10,
            stepHoldDuration: 1,
            curve: .logarithmic,
            mode: .sweep,
            steppedFrequencies: [],
            repeatMode: .continuous,
            repeatCount: 3,
            direction: .forward,
            loopInterval: 0
        )

        XCTAssertLessThan(beforeBoundary.signalGain, 0.6)
        XCTAssertLessThan(afterBoundary.signalGain, 0.6)
        XCTAssertEqual(afterBoundary.iteration, 2)
    }

    func testLegacyPresetDecodesWithSingleSweepDefaults() throws {
        let source = try XCTUnwrap(BuiltInTestPresetCatalog.presets.first?.preset)
        let encoded = try JSONEncoder().encode(source)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "sweepRepeatMode")
        object.removeValue(forKey: "sweepRepeatCount")
        object.removeValue(forKey: "sweepDirection")
        object.removeValue(forKey: "sweepLoopInterval")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(AppPreset.self, from: legacyData)

        XCTAssertEqual(decoded.sweepRepeatMode, .single)
        XCTAssertEqual(decoded.sweepRepeatCount, 3)
        XCTAssertEqual(decoded.sweepDirection, .forward)
        XCTAssertEqual(decoded.sweepLoopInterval, 0)
    }
}
