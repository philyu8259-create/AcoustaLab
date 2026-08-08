import CoreImage
import CoreImage.CIFilterBuiltins
import CoreText
import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AcoustaLabLinks {
    static let appStore = URL(string: "https://apps.apple.com/app/id6763583795")!
}

struct SharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
    private let cleanupRoot: URL?

    init(items: [Any], cleanupRoot: URL? = nil) {
        self.items = items
        self.cleanupRoot = cleanupRoot
    }

    func cleanup() {
        guard let cleanupRoot else { return }
        try? FileManager.default.removeItem(at: cleanupRoot)
    }
}

struct ShareActionButton<Label: View>: View {
    let makePayload: @MainActor () throws -> SharePayload
    @ViewBuilder let label: () -> Label

    @State private var payload: SharePayload?
    @State private var errorMessage: String?

    var body: some View {
        Button {
            do {
                payload = try makePayload()
            } catch {
                errorMessage = error.localizedDescription
            }
        } label: {
            label()
        }
        .sheet(item: $payload, onDismiss: cleanupPayload) { activePayload in
            SystemShareSheet(payload: activePayload) {
                activePayload.cleanup()
                payload = nil
            }
            .ignoresSafeArea()
        }
        .alert(String(localized: "share.error_title"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "button.done"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "share.error_body"))
        }
    }

    private func cleanupPayload() {
        payload?.cleanup()
        payload = nil
    }
}

private struct SystemShareSheet: UIViewControllerRepresentable {
    let payload: SharePayload
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: payload.items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum TemporaryShareFile {
    static func payload(
        data: Data,
        filename: String,
        fileExtension: String
    ) throws -> SharePayload {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AcoustaLab-Share-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let safeFilename = sanitizedFilename(filename)
        let fileURL = root
            .appendingPathComponent(safeFilename)
            .appendingPathExtension(fileExtension)
        try data.write(to: fileURL, options: .atomic)

        return SharePayload(items: [fileURL], cleanupRoot: root)
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let parts = filename.components(separatedBy: forbidden)
        let cleaned = parts.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "AcoustaLab" : cleaned
    }
}

extension UTType {
    static let acoustaLabPreset = UTType(
        exportedAs: "com.phil.AcoustaLab.preset",
        conformingTo: .json
    )
}

private struct SharedPresetEnvelope: Codable {
    let formatVersion: Int
    let createdAt: Date
    let appStoreURL: URL?
    let preset: AppPreset
}

enum PresetFileTransfer {
    static func data(for preset: AppPreset) throws -> Data {
        let envelope = SharedPresetEnvelope(
            formatVersion: 1,
            createdAt: Date(),
            appStoreURL: AcoustaLabLinks.appStore,
            preset: preset
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(envelope)
    }

    static func preset(from data: Data) throws -> AppPreset {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let envelope = try? decoder.decode(SharedPresetEnvelope.self, from: data),
           envelope.formatVersion == 1
        {
            var importedPreset = envelope.preset
            importedPreset.id = UUID()
            return importedPreset
        }

        var importedPreset = try decoder.decode(AppPreset.self, from: data)
        importedPreset.id = UUID()
        return importedPreset
    }

    static func sharePayload(for preset: AppPreset) throws -> SharePayload {
        try TemporaryShareFile.payload(
            data: data(for: preset),
            filename: "AcoustaLab-\(preset.name)",
            fileExtension: "acoustalabpreset"
        )
    }
}

enum CalibrationReportShareService {
    static func sharePayload(
        for profile: CalibrationProfile,
        format: CalibrationReportExportFormat
    ) throws -> SharePayload {
        try TemporaryShareFile.payload(
            data: CalibrationReportExporter.data(for: profile, format: format),
            filename: CalibrationReportExporter.filename(for: profile),
            fileExtension: format.preferredFileExtension
        )
    }
}

enum GuidedTestShareRenderer {
    @MainActor
    static func sharePayload(
        for run: GuidedTestRun,
        locale: Locale = .current
    ) throws -> SharePayload {
        guard let renderedImage = GuidedTestShareBitmapRenderer.render(run: run, locale: locale) else {
            throw ShareRenderingError.failed
        }
        return SharePayload(items: [renderedImage])
    }
}

private enum GuidedTestShareBitmapRenderer {
    private static let size = CGSize(width: 1080, height: 1350)
    private static let background = UIColor(red: 0.025, green: 0.035, blue: 0.055, alpha: 1)
    private static let panel = UIColor(red: 0.11, green: 0.135, blue: 0.19, alpha: 1)
    private static let metricPanel = UIColor(red: 0.065, green: 0.08, blue: 0.115, alpha: 1)
    private static let accent = UIColor(red: 0.35, green: 0.80, blue: 0.95, alpha: 1)
    private static let success = UIColor(red: 0.23, green: 0.84, blue: 0.67, alpha: 1)
    private static let warning = UIColor(red: 1.0, green: 0.74, blue: 0.27, alpha: 1)
    private static let secondary = UIColor(white: 0.61, alpha: 1)

    static func render(run: GuidedTestRun, locale: Locale) -> UIImage? {
        let strings = ShareCardStrings(locale: locale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
            | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        context.setFillColor(background.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.setFillColor(accent.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: 10))

        drawHeader(run: run, strings: strings, in: context)
        drawSummary(run: run, strings: strings, in: context)
        drawResults(run: run, strings: strings, in: context)
        drawFooter(strings: strings, in: context)

        guard let image = context.makeImage() else { return nil }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    private static func drawHeader(run: GuidedTestRun, strings: ShareCardStrings, in context: CGContext) {
        let logoRect = CGRect(x: 64, y: 64, width: 112, height: 112)
        if let logo = UIImage(named: "AppKnobLogo")?.cgImage {
            context.saveGState()
            context.addPath(CGPath(roundedRect: logoRect, cornerWidth: 22, cornerHeight: 22, transform: nil))
            context.clip()
            drawImage(logo, in: logoRect, context: context)
            context.restoreGState()
        }

        drawText(strings["share.card.app_name"], rect: CGRect(x: 200, y: 78, width: 520, height: 54), font: .systemFont(ofSize: 44, weight: .bold), color: .white, context: context)
        drawText(strings["share.card.category"], rect: CGRect(x: 200, y: 138, width: 520, height: 34), font: .systemFont(ofSize: 24, weight: .semibold), color: accent, context: context)

        let formatter = DateFormatter()
        formatter.locale = strings.locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMd")
        drawText(formatter.string(from: run.createdAt), rect: CGRect(x: 742, y: 91, width: 274, height: 34), font: .monospacedSystemFont(ofSize: 22, weight: .medium), color: secondary, alignment: .right, context: context)
    }

    private static func drawSummary(run: GuidedTestRun, strings: ShareCardStrings, in context: CGContext) {
        let rect = CGRect(x: 64, y: 212, width: 952, height: 317)
        let panelPath = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        context.addPath(panelPath.cgPath)
        context.setFillColor(panel.cgColor)
        context.fillPath()
        context.addPath(panelPath.cgPath)
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.10).cgColor)
        context.setLineWidth(2)
        context.strokePath()

        let statusColor = run.anomalyCount == 0 ? success : warning
        let iconName = run.anomalyCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
        drawStatusIcon(
            isPassing: iconName == "checkmark.seal.fill",
            color: statusColor,
            rect: CGRect(x: 100, y: 253, width: 82, height: 82),
            context: context
        )

        drawText(strings[run.planNameKey], rect: CGRect(x: 216, y: 252, width: 748, height: 55), font: fittedFont(strings[run.planNameKey], maxSize: 42, minSize: 29, width: 748, weight: .bold), color: .white, context: context)
        let statusKey = run.anomalyCount == 0 ? "share.card.status_pass" : "share.card.status_attention"
        drawText(strings[statusKey], rect: CGRect(x: 216, y: 312, width: 748, height: 38), font: .systemFont(ofSize: 26, weight: .semibold), color: statusColor, context: context)

        let metrics: [(Int, String, UIColor)] = [
            (run.passCount, "guided_test.step_result.pass", success),
            (run.anomalyCount, "guided_test.step_result.anomaly", warning),
            (run.skippedCount, "guided_test.step_result.skipped", secondary)
        ]
        for (index, metric) in metrics.enumerated() {
            let metricRect = CGRect(x: 100 + CGFloat(index) * 299, y: 370, width: 283, height: 121)
            let path = UIBezierPath(roundedRect: metricRect, cornerRadius: 8)
            context.addPath(path.cgPath)
            context.setFillColor(metricPanel.cgColor)
            context.fillPath()
            drawText("\(metric.0)", rect: CGRect(x: metricRect.minX, y: 393, width: metricRect.width, height: 48), font: .monospacedSystemFont(ofSize: 42, weight: .bold), color: metric.2, alignment: .center, context: context)
            drawText(strings[metric.1], rect: CGRect(x: metricRect.minX, y: 451, width: metricRect.width, height: 30), font: .systemFont(ofSize: 20, weight: .semibold), color: secondary, alignment: .center, context: context)
        }
    }

    private static func drawResults(run: GuidedTestRun, strings: ShareCardStrings, in context: CGContext) {
        drawText(strings["share.card.details"], rect: CGRect(x: 64, y: 568, width: 952, height: 34), font: .systemFont(ofSize: 24, weight: .bold), color: secondary, context: context)

        for (index, result) in run.stepResults.prefix(7).enumerated() {
            let y = 622 + CGFloat(index) * 58
            let color: UIColor
            switch result.state {
            case .pass: color = success
            case .anomaly: color = warning
            case .skipped: color = secondary
            }
            context.setFillColor(color.cgColor)
            context.fillEllipse(in: CGRect(x: 64, y: y + 8, width: 14, height: 14))
            let title = strings[result.presetName]
            drawText(title, rect: CGRect(x: 96, y: y, width: 748, height: 38), font: fittedFont(title, maxSize: 27, minSize: 19, width: 748, weight: .semibold), color: .white, context: context)
            drawText(strings[result.state.localizedKey], rect: CGRect(x: 856, y: y + 1, width: 160, height: 34), font: .systemFont(ofSize: 22, weight: .bold), color: color, alignment: .right, context: context)
        }
    }

    private static func drawFooter(strings: ShareCardStrings, in context: CGContext) {
        context.setFillColor(UIColor.white.withAlphaComponent(0.12).cgColor)
        context.fill(CGRect(x: 64, y: 1085, width: 952, height: 2))
        drawText(strings["share.card.footer_title"], rect: CGRect(x: 64, y: 1152, width: 730, height: 40), font: .systemFont(ofSize: 28, weight: .bold), color: .white, context: context)
        drawText(strings["share.card.footer_body"], rect: CGRect(x: 64, y: 1200, width: 730, height: 76), font: .systemFont(ofSize: 21, weight: .medium), color: secondary, lineBreakMode: .byWordWrapping, context: context)

        if let qrCode = qrCodeImage() {
            let outerRect = CGRect(x: 842, y: 1112, width: 174, height: 174)
            let path = UIBezierPath(roundedRect: outerRect, cornerRadius: 8)
            context.addPath(path.cgPath)
            context.setFillColor(UIColor.white.cgColor)
            context.fillPath()
            context.interpolationQuality = .none
            drawImage(qrCode, in: CGRect(x: 854, y: 1124, width: 150, height: 150), context: context)
        }
    }

    private static func drawStatusIcon(
        isPassing: Bool,
        color: UIColor,
        rect: CGRect,
        context: CGContext
    ) {
        context.saveGState()
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect.insetBy(dx: 4, dy: 4))
        context.setStrokeColor(background.cgColor)
        context.setLineWidth(9)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.beginPath()
        if isPassing {
            context.move(to: CGPoint(x: rect.minX + 24, y: rect.midY))
            context.addLine(to: CGPoint(x: rect.minX + 37, y: rect.maxY - 23))
            context.addLine(to: CGPoint(x: rect.maxX - 20, y: rect.minY + 23))
        } else {
            context.move(to: CGPoint(x: rect.midX, y: rect.minY + 21))
            context.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 30))
            context.move(to: CGPoint(x: rect.midX, y: rect.maxY - 18))
            context.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 17))
        }
        context.strokePath()
        context.restoreGState()
    }

    private static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private static func fittedFont(_ text: String, maxSize: CGFloat, minSize: CGFloat, width: CGFloat, weight: UIFont.Weight) -> UIFont {
        var size = maxSize
        while size > minSize {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            if (text as NSString).size(withAttributes: [.font: font]).width <= width {
                return font
            }
            size -= 1
        }
        return .systemFont(ofSize: minSize, weight: weight)
    }

    private static func drawText(
        _ text: String,
        rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail,
        context: CGContext
    ) {
        let uiFontType: CTFontUIFontType = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            ? .emphasizedSystem
            : .system
        let ctFont = CTFontCreateUIFontForLanguage(uiFontType, font.pointSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): ctFont,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)

        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)

        if lineBreakMode == .byWordWrapping {
            let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
            let path = CGPath(rect: CGRect(origin: .zero, size: rect.size), transform: nil)
            let frame = CTFramesetterCreateFrame(
                framesetter,
                CFRange(location: 0, length: attributedText.length),
                path,
                nil
            )
            CTFrameDraw(frame, context)
        } else {
            let line = CTLineCreateWithAttributedString(attributedText)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
            let drawableLine: CTLine
            if lineWidth > rect.width,
               let truncated = CTLineCreateTruncatedLine(line, Double(rect.width), .end, nil)
            {
                drawableLine = truncated
            } else {
                drawableLine = line
            }
            let drawableWidth = CGFloat(CTLineGetTypographicBounds(drawableLine, nil, nil, nil))
            let x: CGFloat
            switch alignment {
            case .center: x = max(0, (rect.width - drawableWidth) / 2)
            case .right: x = max(0, rect.width - drawableWidth)
            default: x = 0
            }
            let baseline = max(descent, (rect.height - ascent - descent) / 2 + descent)
            context.textPosition = CGPoint(x: x, y: baseline)
            CTLineDraw(drawableLine, context)
        }
        context.restoreGState()
    }

    private static func qrCodeImage() -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(AcoustaLabLinks.appStore.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)) else {
            return nil
        }
        let context = CIContext(options: [.cacheIntermediates: false])
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
}

private struct ShareCardStrings {
    let locale: Locale
    private let bundle: Bundle

    init(locale: Locale) {
        self.locale = locale
        let languageCode = locale.language.languageCode?.identifier
        let localization = languageCode == "zh" ? "zh-Hans" : "en"
        if let path = Bundle.main.path(forResource: localization, ofType: "lproj"),
           let localizedBundle = Bundle(path: path)
        {
            bundle = localizedBundle
        } else {
            bundle = .main
        }
    }

    subscript(key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }
}

private enum ShareRenderingError: LocalizedError {
    case failed

    var errorDescription: String? {
        String(localized: "share.error_body")
    }
}

private struct GuidedTestShareCard: View {
    let run: GuidedTestRun
    let locale: Locale
    private let contentWidth: CGFloat = 952

    private var statusColor: Color {
        run.anomalyCount == 0 ? AppTheme.success : AppTheme.warning
    }

    private var statusIcon: String {
        run.anomalyCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
    }

    private var displayedResults: [GuidedTestStepResult] {
        Array(run.stepResults.prefix(7))
    }

    var body: some View {
        ZStack {
            Color(hex: 0x090B12)

            VStack(alignment: .leading, spacing: 36) {
                header
                resultSummary
                resultList
                Spacer(minLength: 12)
                footer
            }
            .frame(width: contentWidth, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .padding(64)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.accent)
                .frame(height: 10)
        }
    }

    private var header: some View {
        HStack(spacing: 24) {
            Image("AppKnobLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            VStack(alignment: .leading, spacing: 8) {
                Text(localized("share.card.app_name"))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(localized("share.card.category"))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Text(run.createdAt, format: .dateTime.year().month().day())
                .font(.system(size: 22, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize()
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    private var resultSummary: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 22) {
                Image(systemName: statusIcon)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(run.planNameKey))
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(localized(run.anomalyCount == 0 ? "share.card.status_pass" : "share.card.status_attention"))
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 16) {
                metric(run.passCount, key: "guided_test.step_result.pass", color: AppTheme.success)
                metric(run.anomalyCount, key: "guided_test.step_result.anomaly", color: AppTheme.warning)
                metric(run.skippedCount, key: "guided_test.step_result.skipped", color: AppTheme.textSecondary)
            }
        }
        .padding(36)
        .background(Color(hex: 0x1C2230))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.10), lineWidth: 2)
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    private var resultList: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localized("share.card.details"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)

            ForEach(displayedResults) { result in
                HStack(spacing: 18) {
                    Circle()
                        .fill(color(for: result.state))
                        .frame(width: 14, height: 14)
                    Text(LocalizedStringKey(result.presetName))
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Text(LocalizedStringKey(result.state.localizedKey))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(color(for: result.state))
                        .fixedSize()
                }
                .padding(.vertical, 5)
            }
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                Text(localized("share.card.footer_title"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text(localized("share.card.footer_body"))
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            if let qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.top, 28)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 2)
        }
        .frame(width: contentWidth, alignment: .leading)
    }

    private func metric(_ value: Int, key: String, color: Color) -> some View {
        VStack(spacing: 7) {
            Text("\(value)")
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(LocalizedStringKey(key))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.black.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func color(for state: GuidedTestStepResultState) -> Color {
        switch state {
        case .pass:
            return AppTheme.success
        case .anomaly:
            return AppTheme.warning
        case .skipped:
            return AppTheme.textSecondary
        }
    }

    private func localized(_ key: String) -> String {
        let languageCode = locale.language.languageCode?.identifier
        let localization = languageCode == "zh" ? "zh-Hans" : "en"
        guard let resourcePath = Bundle.main.path(forResource: localization, ofType: "lproj"),
              let localizedBundle = Bundle(path: resourcePath)
        else {
            return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        }
        return localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }

    private var qrCodeImage: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(AcoustaLabLinks.appStore.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
