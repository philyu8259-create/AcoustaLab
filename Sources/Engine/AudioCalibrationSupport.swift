import Foundation

struct CalibrationProfileBuildResult {
    let profile: CalibrationProfile
    let referenceFrequency: Double
}

func calibrationFrequencies(for stepMode: FrequencyStepMode) -> [Double] {
    let values = stepMode.values.filter { $0 >= 20 && $0 <= 20_000 }
    return values.isEmpty ? [31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000] : values
}

func resolvedCalibrationProfileName(
    draftName: String,
    outputRouteName: String,
    calibrationStepMode: FrequencyStepMode
) -> String {
    let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
        return trimmed
    }
    return String(
        format: String(localized: "calibration.profile_default_name"),
        outputRouteName,
        calibrationStepMode.localizedTitle
    )
}

func makeCalibrationProfile(
    from run: LoopbackCalibrationRun,
    measurements: [LoopbackCalibrationRun.StepMeasurement]
) -> CalibrationProfileBuildResult {
    let referenceMeasurement = measurements.min(by: {
        abs($0.frequency - run.referenceFrequency) < abs($1.frequency - run.referenceFrequency)
    }) ?? measurements[measurements.count / 2]

    let points = measurements.map { measurement in
        CalibrationPoint(
            frequency: measurement.frequency,
            measuredDecibels: measurement.decibels,
            compensationDecibels: referenceMeasurement.decibels - measurement.decibels
        )
    }

    let profile = CalibrationProfile(
        name: run.profileName,
        routeKey: run.routeKey,
        routeName: run.routeName,
        routeDetail: run.routeDetail,
        sampleRate: run.sampleRate,
        referenceFrequency: referenceMeasurement.frequency,
        stepMode: run.stepMode,
        isCompensationEnabled: true,
        points: points
    )

    return CalibrationProfileBuildResult(
        profile: profile,
        referenceFrequency: referenceMeasurement.frequency
    )
}
