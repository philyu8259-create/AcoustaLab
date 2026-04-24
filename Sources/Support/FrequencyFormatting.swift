import Foundation

enum FrequencyFormatting {
    static func displayString(for frequency: Double) -> String {
        if frequency >= 1000 {
            let kiloHertz = frequency / 1000
            let formatter = NumberFormatter()
            formatter.minimumFractionDigits = kiloHertz < 10 ? 1 : 0
            formatter.maximumFractionDigits = kiloHertz < 10 ? 1 : 0
            formatter.minimumIntegerDigits = 1
            return "\(formatter.string(from: NSNumber(value: kiloHertz)) ?? "\(kiloHertz)")k"
        }

        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = frequency < 10 ? 1 : 0
        formatter.maximumFractionDigits = frequency < 10 ? 1 : 0
        return "\(formatter.string(from: NSNumber(value: frequency)) ?? "\(frequency)") Hz"
    }

    static func textFieldString(for frequency: Double) -> String {
        if frequency < 10 {
            return String(format: "%.1f", frequency)
        }
        return String(format: "%.0f", frequency)
    }

    static func stepLabelString(for frequency: Double) -> String {
        if frequency >= 1000 {
            let kiloHertz = frequency / 1000
            let format = kiloHertz.rounded() == kiloHertz ? "%.0fk" : "%.2gk"
            return String(format: format, kiloHertz)
        }

        if frequency < 10 {
            return String(format: frequency.rounded() == frequency ? "%.0f" : "%.2g", frequency)
        }

        return String(format: frequency.rounded() == frequency ? "%.0f" : "%.3g", frequency)
    }
}

enum LogFrequencyScale {
    static let minFrequency = 1.0
    static let maxFrequency = 32_000.0

    static func sliderValue(for frequency: Double) -> Double {
        let clamped = min(max(frequency, minFrequency), maxFrequency)
        let minLog = log2(minFrequency)
        let maxLog = log2(maxFrequency)
        return (log2(clamped) - minLog) / (maxLog - minLog)
    }

    static func frequency(for sliderValue: Double) -> Double {
        let minLog = log2(minFrequency)
        let maxLog = log2(maxFrequency)
        let value = min(max(sliderValue, 0), 1)
        return pow(2, minLog + value * (maxLog - minLog))
    }
}
