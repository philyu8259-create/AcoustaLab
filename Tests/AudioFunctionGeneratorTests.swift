import XCTest
import UIKit
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

    func testSharedPresetRoundTripsAndReceivesNewIdentifier() throws {
        let original = try XCTUnwrap(BuiltInTestPresetCatalog.presets.first?.preset)
        let data = try PresetFileTransfer.data(for: original)
        var imported = try PresetFileTransfer.preset(from: data)

        XCTAssertNotEqual(imported.id, original.id)
        imported.id = original.id
        XCTAssertEqual(imported, original)
    }

    @MainActor
    func testGuidedTestShareCardRendersAtExpectedSize() throws {
        let plan = try XCTUnwrap(GuidedTestPlanCatalog.plans.first)
        let results = plan.steps.map { step in
            GuidedTestStepResult(
                stepID: step.id,
                presetID: step.preset.id,
                presetName: step.preset.name,
                state: .pass,
                note: nil
            )
        }
        let run = GuidedTestRun(
            planID: plan.id,
            planNameKey: plan.nameKey,
            stepResults: results
        )

        for localeIdentifier in ["en", "zh-Hans"] {
            let payload = try GuidedTestShareRenderer.sharePayload(
                for: run,
                locale: Locale(identifier: localeIdentifier)
            )
            let image = try XCTUnwrap(payload.items.first as? UIImage)
            XCTAssertEqual(image.size.width, 1080, accuracy: 0.5)
            XCTAssertEqual(image.size.height, 1350, accuracy: 0.5)
            let topPixel = try rgbaPixel(in: image, x: 5, y: 5)
            XCTAssertGreaterThan(topPixel.green, 150)
            XCTAssertGreaterThan(topPixel.blue, 180)
            let panelPixel = try rgbaPixel(in: image, x: 70, y: 220)
            XCTAssertGreaterThan(panelPixel.red, 20)
            XCTAssertGreaterThan(panelPixel.blue, 35)

            let pngData = try XCTUnwrap(image.pngData())
            let attachment = XCTAttachment(
                data: pngData,
                uniformTypeIdentifier: "public.png"
            )
            attachment.name = "AcoustaLab-Guided-Test-Share-Card-\(localeIdentifier)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func rgbaPixel(in image: UIImage, x: Int, y: Int) throws -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let cgImage = try XCTUnwrap(image.cgImage)
        let data = try XCTUnwrap(cgImage.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        let offset = y * cgImage.bytesPerRow + x * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3])
    }

    @MainActor
    func testReviewPromptWaitsForTwoEventsAndOnlyRequestsOncePerVersion() {
        let suiteName = "ReviewPromptCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = ReviewPromptCoordinator(
            defaults: defaults,
            appVersion: "1.6-test",
            now: { Date(timeIntervalSince1970: 1_000_000) },
            minimumEventCount: 2,
            minimumPromptInterval: 0
        )

        XCTAssertFalse(coordinator.record(.presetSaved))
        XCTAssertTrue(coordinator.record(.guidedTestCompleted))
        XCTAssertFalse(coordinator.record(.reportExported))
    }

    @MainActor
    func testReviewPromptRespectsMinimumIntervalAcrossVersions() {
        let suiteName = "ReviewPromptIntervalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var date = Date(timeIntervalSince1970: 2_000_000)
        let firstVersion = ReviewPromptCoordinator(
            defaults: defaults,
            appVersion: "1.6-test",
            now: { date },
            minimumEventCount: 1,
            minimumPromptInterval: 30 * 24 * 60 * 60
        )
        XCTAssertTrue(firstVersion.record(.guidedTestCompleted))

        date.addTimeInterval(10 * 24 * 60 * 60)
        let nextVersionTooSoon = ReviewPromptCoordinator(
            defaults: defaults,
            appVersion: "1.7-test",
            now: { date },
            minimumEventCount: 1,
            minimumPromptInterval: 30 * 24 * 60 * 60
        )
        XCTAssertFalse(nextVersionTooSoon.record(.guidedTestCompleted))

        date.addTimeInterval(21 * 24 * 60 * 60)
        XCTAssertTrue(nextVersionTooSoon.record(.reportExported))
    }
}
