import CoreGraphics
import Foundation
import UniformTypeIdentifiers
import UIKit

enum CalibrationReportExportFormat: String, CaseIterable, Identifiable {
    case text
    case csv
    case pdf
    case png

    var id: String { rawValue }

    var contentType: UTType {
        switch self {
        case .text:
            return Self.reportTextType
        case .csv:
            return Self.reportCsvType
        case .pdf:
            return Self.reportPdfType
        case .png:
            return Self.reportPngType
        }
    }

    var localizedTitleKey: String {
        "calibration.export.\(rawValue)"
    }

    var preferredFileExtension: String {
        switch self {
        case .text:
            return "txt"
        case .csv, .pdf, .png:
            return rawValue
        }
    }

    var systemImage: String {
        switch self {
        case .text:
            return "doc.plaintext"
        case .csv:
            return "tablecells"
        case .pdf:
            return "doc.text"
        case .png:
            return "chart.xyaxis.line"
        }
    }

    static let exportButtonFormats: [CalibrationReportExportFormat] = [.pdf, .csv, .png]

    private static var reportTextType: UTType {
        if #available(iOS 14.0, *) {
            return .plainText
        }
        return UTType(filenameExtension: "txt") ?? .data
    }

    private static var reportCsvType: UTType {
        if #available(iOS 15.0, *) {
            return .commaSeparatedText
        }
        return UTType(filenameExtension: "csv") ?? reportTextType
    }

    private static var reportPdfType: UTType {
        if #available(iOS 14.0, *) {
            return .pdf
        }
        return UTType(filenameExtension: "pdf") ?? .data
    }

    private static var reportPngType: UTType {
        if #available(iOS 14.0, *) {
            return .png
        }
        return UTType(filenameExtension: "png") ?? .data
    }
}

enum CalibrationReportExporter {
    static func data(for profile: CalibrationProfile, format: CalibrationReportExportFormat) -> Data {
        switch format {
        case .text:
            return reportText(for: profile).data(using: .utf8) ?? Data()
        case .csv:
            return csvText(for: profile).data(using: .utf8) ?? Data()
        case .pdf:
            return pdfData(for: profile)
        case .png:
            return pngData(for: profile)
        }
    }

    static func filename(for profile: CalibrationProfile) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safeName = profile.displayName
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { $0.append($1) }
            .split(separator: "-")
            .joined(separator: "-")

        return "AcoustaLab-\(safeName.isEmpty ? "Calibration" : safeName)-Report"
    }

    static func reportText(for profile: CalibrationProfile) -> String {
        let analysis = profile.analysis
        let rows: [String] = [
            "AcoustaLab Calibration Report",
            "Generated: \(dateText(Date()))",
            "",
            "Profile",
            "Name: \(profile.displayName)",
            "Route: \(profile.routeName)",
            "Route Detail: \(profile.routeDetail.isEmpty ? "-" : profile.routeDetail)",
            "Sample Rate: \(Int(profile.sampleRate)) Hz",
            "Reference Frequency: \(FrequencyFormatting.displayString(for: profile.referenceFrequency))",
            "Step Mode: \(profile.stepMode.localizedTitle)",
            "Compensation Enabled: \(profile.isCompensationEnabled ? "Yes" : "No")",
            "Created: \(dateText(profile.createdAt))",
            "Updated: \(dateText(profile.updatedAt))",
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
            "\(formattedFrequency(point.frequency)),\(formattedSignedDecibel(point.measuredDecibels)),\(formattedSignedDecibel(point.compensationDecibels))"
        }

        return (rows + pointRows).joined(separator: "\n") + "\n"
    }

    static func csvText(for profile: CalibrationProfile) -> String {
        let analysis = profile.analysis
        var output: [String] = []

        output.append("AcoustaLab Calibration Report")
        output.append("")
        output.append("Generated at,\(csvValue(dateText(Date())))")
        output.append("")
        output.append("Profile Metadata")
        output.append("Profile Name,\(csvValue(profile.displayName))")
        output.append("Route,\(csvValue(profile.routeName))")
        output.append("Route Detail,\(csvValue(profile.routeDetail))")
        output.append("Sample Rate (Hz),\(Int(profile.sampleRate))")
        output.append("Reference Frequency (Hz),\(formattedFrequency(profile.referenceFrequency))")
        output.append("Step Mode,\(csvValue(profile.stepMode.localizedTitle))")
        output.append("Compensation Enabled,\(profile.isCompensationEnabled ? "YES" : "NO")")
        output.append("Point Count,\(profile.pointCount)")
        output.append("Created at,\(csvValue(dateText(profile.createdAt)))")
        output.append("Updated at,\(csvValue(dateText(profile.updatedAt)))")
        output.append("")
        output.append("Profile Analysis")
        if let analysis {
            output.append("Coverage Start (Hz),\(formattedFrequency(analysis.coverageStart))")
            output.append("Coverage End (Hz),\(formattedFrequency(analysis.coverageEnd))")
            output.append("Strongest Correction (dB),\(formattedSignedDecibel(analysis.strongestCorrectionPoint.compensationDecibels))")
            output.append("Reference Anchor (Hz),\(formattedFrequency(analysis.referencePoint.frequency))")
            output.append("Reference Anchor Correction (dB),\(formattedSignedDecibel(analysis.referencePoint.compensationDecibels))")
        } else {
            output.append("Coverage Start (Hz),-")
            output.append("Coverage End (Hz),-")
            output.append("Strongest Correction (dB),-")
            output.append("Reference Anchor (Hz),-")
            output.append("Reference Anchor Correction (dB),-")
        }
        output.append("")
        output.append("Measured Points")
        output.append("Frequency (Hz),Measured (dB),Compensation (dB)")

        for point in profile.points {
            output.append(
                "\(formattedFrequency(point.frequency)),"
                    + "\(formattedSignedDecibel(point.measuredDecibels)),"
                    + "\(formattedSignedDecibel(point.compensationDecibels))"
            )
        }

        return output.joined(separator: "\n") + "\n"
    }

    static func pdfData(for profile: CalibrationProfile) -> Data {
        let points = profile.points.sorted { $0.frequency < $1.frequency }
        let analysis = profile.analysis
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let chartRect = CGRect(x: 42, y: 244, width: pageRect.width - 84, height: 190)
        let contentRect = CGRect(x: 36, y: 28, width: pageRect.width - 72, height: pageRect.height - 56)
        let textFont = UIFont.systemFont(ofSize: 12)
        let tableFont = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: UIGraphicsPDFRendererFormat())
        return renderer.pdfData { context in
            context.beginPage()
            let cgContext = context.cgContext

            drawPDFHeader(in: cgContext, profile: profile, bounds: contentRect, titleFont: UIFont.boldSystemFont(ofSize: 22), bodyFont: textFont)
            let metadataRows = metadataRows(for: profile)
            var cursorY = 136.0

            cursorY += drawPDFSectionTitle(
                "Profile Information",
                atX: contentRect.minX,
                y: cursorY,
                font: UIFont.boldSystemFont(ofSize: 14),
                in: cgContext
            )
            cursorY += drawPDFKeyValueLines(metadataRows, in: cgContext, font: textFont, at: CGPoint(x: contentRect.minX, y: cursorY), width: contentRect.width)
            cursorY += 18

            let summaryLines = summaryLines(for: analysis, pointCount: profile.pointCount)
            cursorY += drawPDFSectionTitle(
                "Summary",
                atX: contentRect.minX,
                y: cursorY,
                font: UIFont.boldSystemFont(ofSize: 14),
                in: cgContext
            )
            cursorY += drawPDFKeyValueLines(summaryLines, in: cgContext, font: textFont, at: CGPoint(x: contentRect.minX, y: cursorY), width: contentRect.width)

            cursorY += 16
            cursorY += drawPDFSectionTitle("Compensation Curve", atX: contentRect.minX, y: cursorY, font: UIFont.boldSystemFont(ofSize: 14), in: cgContext)
            drawCompensationCurve(in: cgContext, rect: chartRect, profile: profile, analysis: analysis)

            let tableStartY = chartRect.maxY + 24
            cursorY = max(cursorY, tableStartY)
            cursorY += drawPDFSectionTitle("Frequency Points", atX: contentRect.minX, y: cursorY, font: UIFont.boldSystemFont(ofSize: 14), in: cgContext)
            let tableTop = cursorY + 10
            drawPointsTable(in: cgContext, points: points, at: CGPoint(x: contentRect.minX, y: tableTop), width: contentRect.width, rowHeight: 16, font: tableFont)
        }
    }

    static func pngData(for profile: CalibrationProfile) -> Data {
        let analysis = profile.analysis
        let imageSize = CGSize(width: 1400, height: 980)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            cgContext.setFillColor(UIColor.white.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: imageSize))

            let titleFont = UIFont.systemFont(ofSize: 40, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 20, weight: .semibold)
            let normalFont = UIFont.systemFont(ofSize: 18, weight: .regular)
            drawString(
                "AcoustaLab Compensation Curve",
                at: CGPoint(x: 44, y: 46),
                width: imageSize.width - 88,
                font: titleFont,
                color: .black,
                in: cgContext
            )

            drawString(
                "Profile: \(profile.displayName)",
                at: CGPoint(x: 44, y: 92),
                width: imageSize.width - 88,
                font: subtitleFont,
                color: .darkGray,
                in: cgContext
            )

            let lines = [
                "Route: \(profile.routeName)",
                "Reference frequency: \(formattedFrequency(profile.referenceFrequency)) Hz",
                "Points: \(profile.pointCount)",
                "Generated: \(dateText(Date()))",
                "Correction span: \(correctionSpanText(for: profile.analysis))"
            ]
            for (index, line) in lines.enumerated() {
                drawString(
                    line,
                    at: CGPoint(x: 44, y: 132 + (CGFloat(index) * 30)),
                    width: imageSize.width - 88,
                    font: normalFont,
                    color: UIColor.black.withAlphaComponent(0.85),
                    in: cgContext
                )
            }

            let chartRect = CGRect(
                x: 84,
                y: 360,
                width: imageSize.width - 168,
                height: 560
            )
            drawCompensationCurve(in: cgContext, rect: chartRect, profile: profile, analysis: analysis, axisColor: .black, lineColor: UIColor(red: 0.0, green: 0.44, blue: 0.86, alpha: 1))
        }

        return image.pngData() ?? Data()
    }

    private static func coverageText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let analysis else { return "-" }
        return "\(FrequencyFormatting.displayString(for: analysis.coverageStart)) - \(FrequencyFormatting.displayString(for: analysis.coverageEnd))"
    }

    private static func correctionSpanText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let analysis else { return "-" }
        return "\(formattedSignedDecibel(analysis.minCorrectionPoint.compensationDecibels)) to \(formattedSignedDecibel(analysis.maxCorrectionPoint.compensationDecibels))"
    }

    private static func averageCorrectionText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let analysis else { return "-" }
        return formattedDecibel(analysis.averageAbsoluteCorrection)
    }

    private static func strongestCorrectionText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let point = analysis?.strongestCorrectionPoint else { return "-" }
        return "\(formattedSignedDecibel(point.compensationDecibels)) @ \(FrequencyFormatting.displayString(for: point.frequency))"
    }

    private static func referenceAnchorText(for analysis: CalibrationProfileAnalysis?) -> String {
        guard let point = analysis?.referencePoint else { return "-" }
        return "\(FrequencyFormatting.displayString(for: point.frequency)) / \(formattedSignedDecibel(point.compensationDecibels))"
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formattedFrequency(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.2f", value)
        }
        return String(format: "%.1f", value)
    }

    private static func formattedDecibel(_ value: Double) -> String {
        String(format: "%.1f dB", value)
    }

    private static func formattedSignedDecibel(_ value: Double) -> String {
        String(format: "%+.1f dB", value)
    }

    private static func metadataRows(for profile: CalibrationProfile) -> [(String, String)] {
        [
            ("Name", profile.displayName),
            ("Route", profile.routeName),
            ("Route Detail", profile.routeDetail.isEmpty ? "-" : profile.routeDetail),
            ("Sample Rate", "\(Int(profile.sampleRate)) Hz"),
            ("Reference Frequency", "\(formattedFrequency(profile.referenceFrequency)) Hz"),
            ("Step Mode", profile.stepMode.localizedTitle),
            ("Compensation Enabled", profile.isCompensationEnabled ? "Yes" : "No"),
            ("Created", dateText(profile.createdAt)),
            ("Updated", dateText(profile.updatedAt))
        ]
    }

    private static func summaryLines(for analysis: CalibrationProfileAnalysis?, pointCount: Int) -> [(String, String)] {
        guard let analysis else {
            return [
                ("Point Count", "\(pointCount)"),
                ("Coverage", "-"),
                ("Correction Span", "-"),
                ("Average Absolute Correction", "-"),
                ("Strongest Correction", "-"),
                ("Reference Anchor", "-")
            ]
        }

        return [
            ("Point Count", "\(pointCount)"),
            ("Coverage", "\(FrequencyFormatting.displayString(for: analysis.coverageStart)) - \(FrequencyFormatting.displayString(for: analysis.coverageEnd))"),
            ("Correction Span", "\(formattedSignedDecibel(analysis.minCorrectionPoint.compensationDecibels)) to \(formattedSignedDecibel(analysis.maxCorrectionPoint.compensationDecibels))"),
            ("Average Absolute Correction", formattedDecibel(analysis.averageAbsoluteCorrection)),
            (
                "Strongest Correction",
                "\(formattedSignedDecibel(analysis.strongestCorrectionPoint.compensationDecibels))"
                    + " @ "
                    + FrequencyFormatting.displayString(for: analysis.strongestCorrectionPoint.frequency)
            ),
            ("Reference Anchor", "\(FrequencyFormatting.displayString(for: analysis.referencePoint.frequency)) / \(formattedSignedDecibel(analysis.referencePoint.compensationDecibels))")
        ]
    }

    private static func drawPDFHeader(in context: CGContext, profile: CalibrationProfile, bounds: CGRect, titleFont: UIFont, bodyFont: UIFont) {
        let topTitle = "AcoustaLab Calibration Report"
        drawString(topTitle, at: CGPoint(x: bounds.minX, y: bounds.minY), width: bounds.width, font: titleFont, color: .black, in: context)

        drawString(
            "Profile: \(profile.displayName)",
            at: CGPoint(x: bounds.minX, y: bounds.minY + 38),
            width: bounds.width,
            font: bodyFont,
            color: UIColor.darkGray,
            in: context
        )

        drawString(
            "Route: \(profile.routeName)",
            at: CGPoint(x: bounds.minX, y: bounds.minY + 58),
            width: bounds.width * 0.55,
            font: bodyFont,
            color: UIColor.darkGray,
            in: context
        )

        drawString(
            "Generated: \(dateText(Date()))",
            at: CGPoint(x: bounds.minX, y: bounds.minY + 82),
            width: bounds.width * 0.55,
            font: bodyFont,
            color: UIColor.darkGray,
            in: context
        )
    }

    private static func drawPDFSectionTitle(_ title: String, atX x: CGFloat, y: Double, font: UIFont, in context: CGContext) -> Double {
        drawString(title, at: CGPoint(x: x, y: CGFloat(y)), width: 500, font: font, color: .black, in: context)
        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: x, y: CGFloat(y) + 20))
        context.addLine(to: CGPoint(x: x + 200, y: CGFloat(y) + 20))
        context.strokePath()
        return 30
    }

    private static func drawPDFKeyValueLines(
        _ rows: [(String, String)],
        in context: CGContext,
        font: UIFont,
        at point: CGPoint,
        width: CGFloat
    ) -> Double {
        var cursorY = point.y
        let keyWidth = width * 0.42

        for (key, value) in rows {
            drawString(
                key,
                at: CGPoint(x: point.x, y: cursorY),
                width: keyWidth,
                font: font,
                color: UIColor.gray,
                in: context
            )
            drawString(
                value,
                at: CGPoint(x: point.x + keyWidth + 10, y: cursorY),
                width: width - keyWidth - 10,
                font: font,
                color: UIColor.black,
                in: context
            )
            cursorY += 18
        }

        return cursorY - point.y
    }

    private static func drawPointsTable(
        in context: CGContext,
        points: [CalibrationPoint],
        at origin: CGPoint,
        width: CGFloat,
        rowHeight: CGFloat,
        font: UIFont
    ) {
        let columns = [0.0, 0.36, 0.66]
        let labelX = [origin.x, origin.x + width * CGFloat(columns[1]), origin.x + width * CGFloat(columns[2])]
        let tableHeight = min(CGFloat(points.count + 2) * rowHeight + 2, 430)
        let tableRect = CGRect(
            x: origin.x,
            y: origin.y,
            width: width,
            height: tableHeight
        )

        context.setStrokeColor(UIColor.separator.cgColor)
        context.setLineWidth(1)
        context.stroke(tableRect)

        let headers = ["Frequency (Hz)", "Measured (dB)", "Compensation (dB)"]
        drawString(
            headers[0],
            at: CGPoint(x: labelX[0], y: origin.y),
            width: width * 0.36,
            font: UIFont.boldSystemFont(ofSize: font.pointSize),
            color: .black,
            in: context
        )
        drawString(
            headers[1],
            at: CGPoint(x: labelX[1], y: origin.y),
            width: width * 0.30,
            font: UIFont.boldSystemFont(ofSize: font.pointSize),
            color: .black,
            in: context
        )
        drawString(
            headers[2],
            at: CGPoint(x: labelX[2], y: origin.y),
            width: width * 0.34,
            font: UIFont.boldSystemFont(ofSize: font.pointSize),
            color: .black,
            in: context
        )

        var rowY = origin.y + rowHeight
        for index in 0..<min(points.count, 120) {
            let point = points[index]
            let rowColor = UIColor(red: 0.88, green: 0.88, blue: 0.9, alpha: 1)
            if index.isMultiple(of: 2) {
                context.setFillColor(rowColor.cgColor)
                context.fill(CGRect(x: tableRect.minX, y: rowY, width: tableRect.width, height: rowHeight))
            }

            drawString(
                formattedFrequency(point.frequency),
                at: CGPoint(x: labelX[0], y: rowY),
                width: width * 0.36,
                font: font,
                color: .black,
                in: context
            )
            drawString(
                formattedSignedDecibel(point.measuredDecibels),
                at: CGPoint(x: labelX[1], y: rowY),
                width: width * 0.30,
                font: font,
                color: .black,
                in: context
            )
            drawString(
                formattedSignedDecibel(point.compensationDecibels),
                at: CGPoint(x: labelX[2], y: rowY),
                width: width * 0.34,
                font: font,
                color: .black,
                in: context
            )
            rowY += rowHeight
        }

        if points.count > 120 {
            drawString(
                "… truncated, first 120 points only",
                at: CGPoint(x: labelX[0], y: rowY + 8),
                width: width,
                font: UIFont.italicSystemFont(ofSize: 9),
                color: UIColor.gray,
                in: context
            )
        }
        context.setLineWidth(0.7)
        let lineCount = min(points.count, 120) + 2
        for lineIndex in 0...lineCount {
            let y = origin.y + (CGFloat(lineIndex) * rowHeight)
            context.move(to: CGPoint(x: tableRect.minX, y: y))
            context.addLine(to: CGPoint(x: tableRect.maxX, y: y))
            context.strokePath()
        }
    }

    private static func drawCompensationCurve(
        in context: CGContext,
        rect: CGRect,
        profile: CalibrationProfile,
        analysis: CalibrationProfileAnalysis?,
        axisColor: UIColor = UIColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1),
        lineColor: UIColor = UIColor(red: 0.0, green: 0.45, blue: 0.9, alpha: 1)
    ) {
        let sorted = profile.points.sorted { $0.frequency < $1.frequency }
        guard !sorted.isEmpty else {
            drawString("No calibration points", at: CGPoint(x: rect.midX - 60, y: rect.midY), width: 120, font: UIFont.systemFont(ofSize: 14), color: UIColor.gray, in: context)
            return
        }

        context.setFillColor(UIColor(white: 0.96, alpha: 1).cgColor)
        context.fill(rect)
        context.setStrokeColor(axisColor.cgColor)
        context.setLineWidth(0.8)
        context.stroke(rect)

        let bounds = yBounds(for: sorted, analysis: analysis)
        drawGrid(in: context, rect: rect, bounds: bounds, axisColor: axisColor)
        drawCurve(in: context, rect: rect, points: sorted, yBounds: bounds, axisColor: axisColor, lineColor: lineColor)

        drawString(
            "Frequency",
            at: CGPoint(x: rect.maxX - 80, y: rect.maxY + 8),
            width: 80,
            font: UIFont.systemFont(ofSize: 11),
            color: UIColor.darkGray,
            in: context
        )
        drawString("0 dB", at: CGPoint(x: rect.minX - 24, y: rect.midY - 7), width: 40, font: UIFont.systemFont(ofSize: 10), color: UIColor.darkGray, in: context)
    }

    private static func drawGrid(
        in context: CGContext,
        rect: CGRect,
        bounds: (min: Double, max: Double),
        axisColor: UIColor
    ) {
        context.setStrokeColor(axisColor.withAlphaComponent(0.45).cgColor)
        context.setLineWidth(0.6)
        for i in 0...4 {
            let x = rect.minX + (rect.width / 4.0) * CGFloat(i)
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            context.strokePath()
        }
        for i in 0...4 {
            let y = rect.minY + (rect.height / 4.0) * CGFloat(i)
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.strokePath()
        }

        let span = bounds.max - bounds.min
        guard span > 0 else { return }
        let zeroProgress = (0 - bounds.min) / span
        if zeroProgress >= 0 && zeroProgress <= 1 {
            let y = rect.maxY - CGFloat(zeroProgress) * rect.height
            context.setStrokeColor(UIColor.systemGreen.withAlphaComponent(0.6).cgColor)
            context.setLineWidth(1.2)
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
            context.strokePath()
        }
    }

    private static func drawCurve(
        in context: CGContext,
        rect: CGRect,
        points: [CalibrationPoint],
        yBounds: (min: Double, max: Double),
        axisColor: UIColor,
        lineColor: UIColor
    ) {
        guard let minPoint = points.first, let maxPoint = points.last else { return }
        let minLog = log(max(minPoint.frequency, 1))
        let maxLog = log(max(maxPoint.frequency, minPoint.frequency + 1))
        let logRange = max(maxLog - minLog, 0.000_001)
        let yRange = max(yBounds.max - yBounds.min, 0.000_001)

        let curve = CGMutablePath()
        for (index, point) in points.enumerated() {
            let mapped = mappedPoint(point, in: rect, minLog: minLog, logRange: logRange, yBounds: yBounds, yRange: yRange)
            if index == 0 {
                curve.move(to: mapped)
            } else {
                curve.addLine(to: mapped)
            }
        }

        context.addPath(curve)
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(2.2)
        context.strokePath()

        for point in points {
            let mapped = mappedPoint(point, in: rect, minLog: minLog, logRange: logRange, yBounds: yBounds, yRange: yRange)
            let radius = point.frequency == points.max(by: { $0.compensationDecibels < $1.compensationDecibels })?.frequency ? 4.0 : 2.8
            let marker = CGRect(x: mapped.x - radius, y: mapped.y - radius, width: radius * 2, height: radius * 2)
            context.setFillColor((point.compensationDecibels > 4 || point.compensationDecibels < -4 ? UIColor.systemOrange.cgColor : UIColor.black.cgColor))
            context.fillEllipse(in: marker)
        }

        context.setStrokeColor(axisColor.withAlphaComponent(0.7).cgColor)
        let leftLabel = "\(formattedFrequency(minPoint.frequency))"
        let rightLabel = "\(formattedFrequency(maxPoint.frequency))"
        drawString(leftLabel, at: CGPoint(x: rect.minX - 36, y: rect.maxY + 2), width: 34, font: UIFont.systemFont(ofSize: 9), color: .black, in: context, alignment: .right)
        drawString(rightLabel, at: CGPoint(x: rect.maxX - 4, y: rect.maxY + 2), width: 34, font: UIFont.systemFont(ofSize: 9), color: .black, in: context, alignment: .left)
    }

    private static func yBounds(for points: [CalibrationPoint], analysis: CalibrationProfileAnalysis?) -> (min: Double, max: Double) {
        guard !points.isEmpty else { return (min: -8, max: 8) }
        let minValue = points.map(\.compensationDecibels).min() ?? 0
        let maxValue = points.map(\.compensationDecibels).max() ?? 0
        let lower = Swift.min(minValue, 0)
        let upper = Swift.max(maxValue, 0)
        if upper - lower < 2 {
            return (lower - 1, upper + 1)
        }
        let padding = (upper - lower) * 0.18
        return (lower - padding, upper + padding)
    }

    private static func mappedPoint(
        _ point: CalibrationPoint,
        in rect: CGRect,
        minLog: Double,
        logRange: Double,
        yBounds: (min: Double, max: Double),
        yRange: Double
    ) -> CGPoint {
        let frequencyLog = log(max(point.frequency, 1))
        let x = rect.minX + (rect.width * CGFloat((frequencyLog - minLog) / logRange))
        let yProgress = 1 - CGFloat((point.compensationDecibels - yBounds.min) / yRange)
        let y = rect.minY + (rect.height * min(max(yProgress, 0), 1))
        return CGPoint(x: x, y: y)
    }

    private static func drawString(
        _ text: String,
        at point: CGPoint,
        width: CGFloat,
        font: UIFont,
        color: UIColor,
        in context: CGContext,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(
            with: CGRect(origin: point, size: CGSize(width: width, height: 200)),
            options: .usesLineFragmentOrigin,
            context: nil
        )
    }

    private static func csvValue(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
