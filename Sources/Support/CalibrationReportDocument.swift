import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CalibrationReportDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        CalibrationReportExportFormat.allCases.map(\.contentType)
    }

    var text: String
    var data: Data
    var exportFormat: CalibrationReportExportFormat
    var defaultFilename: String

    init(text: String = "", defaultFilename: String = "AcoustaLab-Calibration-Report") {
        self.text = text
        self.data = text.data(using: .utf8) ?? Data()
        self.exportFormat = .text
        self.defaultFilename = defaultFilename
    }

    init(profile: CalibrationProfile, format: CalibrationReportExportFormat = .text) {
        let generatedData = CalibrationReportExporter.data(for: profile, format: format)
        self.text = String(data: generatedData, encoding: .utf8) ?? ""
        self.data = generatedData
        self.exportFormat = format
        self.defaultFilename = CalibrationReportExporter.filename(for: profile)
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        self.text = String(data: data, encoding: .utf8) ?? ""
        self.data = data
        self.exportFormat = .text
        self.defaultFilename = "AcoustaLab-Calibration-Report"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
