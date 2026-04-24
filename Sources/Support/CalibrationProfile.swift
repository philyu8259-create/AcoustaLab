import Foundation

struct CalibrationPoint: Codable, Equatable, Hashable, Identifiable {
    let frequency: Double
    let measuredDecibels: Double
    let compensationDecibels: Double

    var id: Double { frequency }
}

struct CalibrationProfileAnalysis {
    let coverageStart: Double
    let coverageEnd: Double
    let minCorrectionPoint: CalibrationPoint
    let maxCorrectionPoint: CalibrationPoint
    let strongestCorrectionPoint: CalibrationPoint
    let referencePoint: CalibrationPoint
    let averageAbsoluteCorrection: Double

    var correctionSpread: Double {
        maxCorrectionPoint.compensationDecibels - minCorrectionPoint.compensationDecibels
    }

    var strongestCorrectionMagnitude: Double {
        abs(strongestCorrectionPoint.compensationDecibels)
    }

    var hasWideCorrectionSpan: Bool {
        correctionSpread >= 8
    }

    var hasStrongHotspot: Bool {
        strongestCorrectionMagnitude >= 5
    }

    var shouldWarn: Bool {
        hasWideCorrectionSpan || hasStrongHotspot
    }
}

struct CalibrationProfile: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var routeKey: String
    var routeName: String
    var routeDetail: String
    var sampleRate: Double
    var referenceFrequency: Double
    var stepMode: FrequencyStepMode
    var createdAt: Date
    var updatedAt: Date
    var isCompensationEnabled: Bool
    var points: [CalibrationPoint]

    init(
        id: UUID = UUID(),
        name: String = "",
        routeKey: String,
        routeName: String,
        routeDetail: String,
        sampleRate: Double,
        referenceFrequency: Double,
        stepMode: FrequencyStepMode = .octave,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isCompensationEnabled: Bool = true,
        points: [CalibrationPoint]
    ) {
        self.id = id
        self.name = name
        self.routeKey = routeKey
        self.routeName = routeName
        self.routeDetail = routeDetail
        self.sampleRate = sampleRate
        self.referenceFrequency = referenceFrequency
        self.stepMode = stepMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isCompensationEnabled = isCompensationEnabled
        self.points = points.sorted { $0.frequency < $1.frequency }
    }

    var pointCount: Int {
        points.count
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? routeName : trimmed
    }

    var analysis: CalibrationProfileAnalysis? {
        guard let firstPoint = points.first, let lastPoint = points.last else { return nil }
        guard
            let minCorrectionPoint = points.min(by: { $0.compensationDecibels < $1.compensationDecibels }),
            let maxCorrectionPoint = points.max(by: { $0.compensationDecibels < $1.compensationDecibels }),
            let strongestCorrectionPoint = points.max(by: { abs($0.compensationDecibels) < abs($1.compensationDecibels) })
        else {
            return nil
        }

        let referencePoint = points.min(by: {
            abs($0.frequency - referenceFrequency) < abs($1.frequency - referenceFrequency)
        }) ?? firstPoint

        let averageAbsoluteCorrection = points.reduce(0) { partialResult, point in
            partialResult + abs(point.compensationDecibels)
        } / Double(points.count)

        return CalibrationProfileAnalysis(
            coverageStart: firstPoint.frequency,
            coverageEnd: lastPoint.frequency,
            minCorrectionPoint: minCorrectionPoint,
            maxCorrectionPoint: maxCorrectionPoint,
            strongestCorrectionPoint: strongestCorrectionPoint,
            referencePoint: referencePoint,
            averageAbsoluteCorrection: averageAbsoluteCorrection
        )
    }

    func compensationDecibels(for frequency: Double) -> Double {
        let sortedPoints = points.sorted { $0.frequency < $1.frequency }
        guard let firstPoint = sortedPoints.first else { return 0 }
        guard let lastPoint = sortedPoints.last else { return 0 }

        if sortedPoints.count == 1 {
            return firstPoint.compensationDecibels
        }

        let safeFrequency = max(frequency, 1)

        if safeFrequency <= firstPoint.frequency {
            return firstPoint.compensationDecibels
        }

        if safeFrequency >= lastPoint.frequency {
            return lastPoint.compensationDecibels
        }

        for index in 0 ..< (sortedPoints.count - 1) {
            let lower = sortedPoints[index]
            let upper = sortedPoints[index + 1]
            guard safeFrequency >= lower.frequency, safeFrequency <= upper.frequency else { continue }

            let lowerLog = log(max(lower.frequency, 1))
            let upperLog = log(max(upper.frequency, 1))
            guard abs(upperLog - lowerLog) > 0.000_001 else {
                return lower.compensationDecibels
            }

            let targetLog = log(safeFrequency)
            let progress = (targetLog - lowerLog) / (upperLog - lowerLog)
            return lower.compensationDecibels + ((upper.compensationDecibels - lower.compensationDecibels) * progress)
        }

        return lastPoint.compensationDecibels
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case routeKey
        case routeName
        case routeDetail
        case sampleRate
        case referenceFrequency
        case stepMode
        case createdAt
        case updatedAt
        case isCompensationEnabled
        case points
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        routeKey = try container.decode(String.self, forKey: .routeKey)
        routeName = try container.decode(String.self, forKey: .routeName)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? routeName
        routeDetail = try container.decode(String.self, forKey: .routeDetail)
        sampleRate = try container.decode(Double.self, forKey: .sampleRate)
        referenceFrequency = try container.decode(Double.self, forKey: .referenceFrequency)
        stepMode = try container.decodeIfPresent(FrequencyStepMode.self, forKey: .stepMode) ?? .octave
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        isCompensationEnabled = try container.decodeIfPresent(Bool.self, forKey: .isCompensationEnabled) ?? true
        points = (try container.decode([CalibrationPoint].self, forKey: .points)).sorted { $0.frequency < $1.frequency }
    }
}

private struct CalibrationProfileStorePayload: Codable {
    var profiles: [CalibrationProfile]
    var activeProfileIDsByRoute: [String: UUID]
}

final class CalibrationProfileStore {
    private let defaultsKey = "audio_function_generator_calibration_profiles"
    private(set) var profiles: [CalibrationProfile] = []
    private(set) var activeProfileIDsByRoute: [String: UUID] = [:]

    init() {
        load()
    }

    func profiles(for routeKey: String) -> [CalibrationProfile] {
        profiles
            .filter { $0.routeKey == routeKey }
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    func activeProfile(for routeKey: String) -> CalibrationProfile? {
        let routeProfiles = profiles(for: routeKey)
        guard !routeProfiles.isEmpty else { return nil }

        if let activeID = activeProfileIDsByRoute[routeKey],
           let matched = routeProfiles.first(where: { $0.id == activeID }) {
            return matched
        }

        return routeProfiles.first
    }

    func save(_ profile: CalibrationProfile, makeActive: Bool = true) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }

        if makeActive {
            activeProfileIDsByRoute[profile.routeKey] = profile.id
        } else if activeProfileIDsByRoute[profile.routeKey] == nil {
            activeProfileIDsByRoute[profile.routeKey] = profile.id
        }

        profiles.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func setActiveProfile(_ profileID: UUID, for routeKey: String) {
        guard profiles.contains(where: { $0.routeKey == routeKey && $0.id == profileID }) else { return }
        activeProfileIDsByRoute[routeKey] = profileID
        persist()
    }

    func setCompensationEnabled(_ isEnabled: Bool, for profileID: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        profiles[index].isCompensationEnabled = isEnabled
        profiles[index].updatedAt = Date()
        persist()
    }

    func renameProfile(_ name: String, profileID: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        profiles[index].name = name
        profiles[index].updatedAt = Date()
        persist()
    }

    func deleteProfile(id: UUID) {
        guard let removed = profiles.first(where: { $0.id == id }) else { return }
        profiles.removeAll { $0.id == id }

        if activeProfileIDsByRoute[removed.routeKey] == id {
            activeProfileIDsByRoute[removed.routeKey] = profiles(for: removed.routeKey).first?.id
        }

        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            let payload = try JSONDecoder().decode(CalibrationProfileStorePayload.self, from: data)
            profiles = payload.profiles.sorted { $0.updatedAt > $1.updatedAt }
            activeProfileIDsByRoute = payload.activeProfileIDsByRoute
        } catch {
            do {
                profiles = try JSONDecoder().decode([CalibrationProfile].self, from: data)
                profiles.sort { $0.updatedAt > $1.updatedAt }
                activeProfileIDsByRoute = Dictionary(uniqueKeysWithValues: profiles.map { ($0.routeKey, $0.id) })
                persist()
            } catch {
                print("Failed to load calibration profiles: \(error)")
            }
        }
    }

    private func persist() {
        do {
            let payload = CalibrationProfileStorePayload(
                profiles: profiles,
                activeProfileIDsByRoute: activeProfileIDsByRoute
            )
            let data = try JSONEncoder().encode(payload)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            print("Failed to save calibration profiles: \(error)")
        }
    }
}
