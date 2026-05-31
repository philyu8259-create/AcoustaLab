import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CalibrationReportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String
    var defaultFilename: String

    init(text: String = "", defaultFilename: String = "AcoustaLab-Calibration-Report") {
        self.text = text
        self.defaultFilename = defaultFilename
    }

    init(profile: CalibrationProfile) {
        text = CalibrationReportDocument.reportText(for: profile)
        defaultFilename = CalibrationReportDocument.filename(for: profile)
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let decoded = String(data: data, encoding: .utf8) {
            text = decoded
        } else {
            text = ""
        }
        defaultFilename = "AcoustaLab-Calibration-Report"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }

    private static func reportText(for profile: CalibrationProfile) -> String {
        let analysis = profile.analysis
        let lines: [String] = [
            "AcoustaLab Calibration Report",
            "Generated: \(dateTimeText(Date()))",
            "",
            "Profile",
            "Name: \(profile.displayName)",
            "Route: \(profile.routeName)",
            "Route Detail: \(emptyPlaceholder(profile.routeDetail))",
            "Sample Rate: \(Int(profile.sampleRate)) Hz",
            "Reference Frequency: \(FrequencyFormatting.displayString(for: profile.referenceFrequency))",
            "Step Mode: \(profile.stepMode.localizedTitle)",
            "Compensation Enabled: \(profile.isCompensationEnabled ? "Yes" : "No")",
            "Created: \(dateTimeText(profile.createdAt))",
            "Updated: \(dateTimeText(profile.updatedAt))",
            "",
            "Summary",
            "Point Count: \(profile.pointCount)",
            "Coverage: \(coverageText(for: analysis))",
            "Correction Span: \(correctionSpanText(for: analysis))",
            "Average Absolute Correction: \(averageCorrectionText(for: analysis))",
            "Strongest Correction: \(strongestCorrectionText(for: analysis))",
            "Reference Anchor: \(referenceAnchorText(for: analysis))",
            "",
            "Measured Points",
            "Frequency,Measured dB,Compensation dB"
        ]

        let pointRows = profile.points.map { point in
            "\(FrequencyFormatting.displayString(for: point.frequency)),\(decibelText(point.measuredDecibels)),\(signedDecibelText(point.compensationDecibels))"
        }

        return (lines + pointRows).joined(separator: "\n") + "\n"
    }

    private static func filename(for profile: CalibrationProfile) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safeName = profile.displayName
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .split(separator: "-")
            .joined(separator: "-")

        return "AcoustaLab-\(safeName.isEmpty ? "Calibration" : safeName)-Report"
    }

    private static func coverageText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let analysis else { return "-" }
        return "\(FrequencyFormatting.displayString(for: analysis.coverageStart)) - \(FrequencyFormatting.displayString(for: analysis.coverageEnd))"
    }

    private static func correctionSpanText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let analysis else { return "-" }
        return "\(signedDecibelText(analysis.minCorrectionPoint.compensationDecibels)) to \(signedDecibelText(analysis.maxCorrectionPoint.compensationDecibels))"
    }

    private static func averageCorrectionText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let analysis else { return "-" }
        return decibelText(abs(analysis.averageAbsoluteCorrection))
    }

    private static func strongestCorrectionText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let point = analysis?.strongestCorrectionPoint else { return "-" }
        return "\(signedDecibelText(point.compensationDecibels)) @ \(FrequencyFormatting.displayString(for: point.frequency))"
    }

    private static func referenceAnchorText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let point = analysis?.referencePoint else { return "-" }
        return "\(FrequencyFormatting.displayString(for: point.frequency)) / \(signedDecibelText(point.compensationDecibels))"
    }

    private static func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func decibelText(_ value: Double) -> String {
        String(format: "%.1f dB", value)
    }

    private static func signedDecibelText(_ value: Double) -> String {
        String(format: "%+.1f dB", value)
    }

    private static func emptyPlaceholder(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : value
    }
}
