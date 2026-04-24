import Foundation

enum FrequencyStepMode: String, CaseIterable, Identifiable, Codable {
    case octave
    case thirdOctave

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .octave:
            return String(localized: "step_mode.octave")
        case .thirdOctave:
            return String(localized: "step_mode.third_octave")
        }
    }

    var defaultStart: Double {
        switch self {
        case .octave:
            return 2.0
        case .thirdOctave:
            return 1.0
        }
    }

    var values: [Double] {
        switch self {
        case .octave:
            return [2, 4, 8, 16, 31.5, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000, 32000]
        case .thirdOctave:
            return [
                1.0, 1.25, 1.6, 2.0, 2.5, 3.15,
                4.0, 5.0, 6.3, 8.0, 10.0, 12.5, 16.0,
                20.0, 25.0, 31.5, 40.0, 50.0, 63.0, 80.0, 100.0,
                125.0, 160.0, 200.0, 250.0, 315.0, 400.0, 500.0, 630.0, 800.0,
                1000.0, 1250.0, 1600.0, 2000.0, 2500.0, 3150.0, 4000.0, 5000.0, 6300.0, 8000.0,
                10000.0, 12500.0, 16000.0, 20000.0
            ]
        }
    }

    func contains(_ value: Double) -> Bool {
        values.contains { abs($0 - value) < 0.0001 }
    }

    func nearestValue(to value: Double) -> Double {
        values.min(by: { abs($0 - value) < abs($1 - value) }) ?? defaultStart
    }

    func nextValue(from value: Double) -> Double {
        let values = self.values
        guard !values.isEmpty else { return value }
        if let exactIndex = values.firstIndex(where: { abs($0 - value) < 0.0001 }) {
            return values[min(exactIndex + 1, values.count - 1)]
        }
        return values.first(where: { $0 > value }) ?? values.last ?? value
    }

    func previousValue(from value: Double) -> Double {
        let values = self.values
        guard !values.isEmpty else { return value }
        if let exactIndex = values.firstIndex(where: { abs($0 - value) < 0.0001 }) {
            return values[max(exactIndex - 1, 0)]
        }
        return values.last(where: { $0 < value }) ?? values.first ?? value
    }
}
