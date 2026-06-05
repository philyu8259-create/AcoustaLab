import AVFoundation

final class RealtimeSpectrumAnalyzer: ObservableObject {
    struct Band: Identifiable, Equatable {
        let id: Int
        let centerFrequency: Double
        let lowerFrequency: Double
        let upperFrequency: Double
        let levelDecibels: Double

        var isActive: Bool {
            levelDecibels > -90
        }
    }

    struct BandDefinition {
        let id: Int
        let centerFrequency: Double
        let lowerFrequency: Double
        let upperFrequency: Double
    }

    @Published private(set) var isRunning = false
    @Published private(set) var bands: [Band] = []
    @Published private(set) var peakFrequency: Double = 0
    @Published private(set) var inputLevelDecibels: Double = -120
    @Published private(set) var statusText: String = String(localized: "analyzer.status_idle")

    private let audioEngine = AVAudioEngine()
    private let analysisFrameCount = 2048
    private let hopSize = 1024
    private let minDecibelFloor = -120.0
    private let lowInputLevelThreshold = -72.0
    private let analysisLevelsSmoothing = 0.22
    private let levelSmoothing = 0.82
    private let maxBands: Int = 16
    private var sampleWindow: [Float] = []
    private var smoothedLevels: [Double] = []
    private var isPreparing = false
    private var isProcessing = false
    private var isTapInstalled = false
    private var sampleRate: Double = 48_000
    private var previousSessionCategory: AVAudioSession.Category?
    private var previousSessionMode: AVAudioSession.Mode?
    private var previousSessionOptions: AVAudioSession.CategoryOptions?

    private let thirdOctaveBandDefinitions: [BandDefinition] = {
        let centerFrequencies: [Double] = [
            20,
            25,
            31.5,
            40,
            50,
            63,
            80,
            100,
            125,
            160,
            200,
            250,
            315,
            400,
            500,
            630
        ]
        let ratio = pow(2.0, 1.0 / 6.0)

        return centerFrequencies.enumerated().map { index, center in
            let lower = center / ratio
            let upper = center * ratio
            return BandDefinition(
                id: index,
                centerFrequency: center,
                lowerFrequency: lower,
                upperFrequency: upper
            )
        }
    }()

    init() {
        self.bands = thirdOctaveBandDefinitions.map {
            Band(
                id: $0.id,
                centerFrequency: $0.centerFrequency,
                lowerFrequency: $0.lowerFrequency,
                upperFrequency: $0.upperFrequency,
                levelDecibels: -120
            )
        }
        self.smoothedLevels = Array(repeating: -120, count: minBandsCount)
    }

    deinit {
        stop()
        audioEngine.reset()
    }

    func start() {
        guard !isRunning else { return }
        statusText = String(localized: "analyzer.status_requesting")
        isPreparing = true
        requestRecordPermission { [weak self] granted in
            guard let self else { return }

            DispatchQueue.main.async {
                guard granted else {
                    self.isPreparing = false
                    self.statusText = String(localized: "analyzer.status_permission_denied")
                    return
                }

                self.statusText = String(localized: "analyzer.status_starting")
                self.beginCapture()
            }
        }
    }

    func stop() {
        guard isRunning else {
            if isPreparing {
                isPreparing = false
                statusText = String(localized: "analyzer.status_stopped")
            }
            return
        }

        isRunning = false
        isPreparing = false
        isProcessing = false
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        audioEngine.stop()
        sampleWindow.removeAll(keepingCapacity: true)
        restoreAudioSession()

        smoothedLevels = Array(repeating: minDecibelFloor, count: minBandsCount)
        DispatchQueue.main.async {
            self.peakFrequency = 0
            self.inputLevelDecibels = self.minDecibelFloor
            self.bands = self.thirdOctaveBandDefinitions.map {
                Band(
                    id: $0.id,
                    centerFrequency: $0.centerFrequency,
                    lowerFrequency: $0.lowerFrequency,
                    upperFrequency: $0.upperFrequency,
                    levelDecibels: self.minDecibelFloor
                )
            }
            self.statusText = String(localized: "analyzer.status_stopped")
        }
    }

    private var minBandsCount: Int {
        min(maxBands, thirdOctaveBandDefinitions.count)
    }

    private func beginCapture() {
        guard !isRunning else { return }

        if configureAudioSessionForRecording() == false {
            isPreparing = false
            statusText = String(localized: "analyzer.status_no_input")
            return
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)

        guard format.channelCount > 0 else {
            isPreparing = false
            statusText = String(localized: "analyzer.status_no_input")
            return
        }
        if format.sampleRate > 0 {
            sampleRate = format.sampleRate
        }

        removeTapIfNeeded()
        sampleWindow.removeAll(keepingCapacity: true)

        let frameCount = AVAudioFrameCount(min(analysisFrameCount, Int(format.sampleRate > 0 ? Int(format.sampleRate / 20) : 1024)))
        inputNode.installTap(onBus: 0, bufferSize: frameCount, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.processBuffer(buffer)
        }
        isTapInstalled = true

        do {
            try audioEngine.start()
            isRunning = true
            isPreparing = false
            statusText = String(localized: "analyzer.status_running")
        } catch {
            isPreparing = false
            isRunning = false
            isTapInstalled = false
            removeTapIfNeeded()
            statusText = String(localized: "analyzer.status_failed")
            restoreAudioSession()
        }
    }

    private func requestRecordPermission(completion: @escaping (Bool) -> Void) {
        #if canImport(UIKit) && !os(tvOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                completion(granted)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                completion(granted)
            }
        }
        #else
        completion(false)
        #endif
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRunning else { return }
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var monoSamples: [Float] = []
        monoSamples.reserveCapacity(frameLength)
        let divisor = Float(max(channelCount, 1))

        for frame in 0..<frameLength {
            var sampleSum: Float = 0
            for channel in 0..<channelCount {
                sampleSum += channelData[channel][frame]
            }
            monoSamples.append(sampleSum / divisor)
        }

        guard !monoSamples.isEmpty else { return }
        sampleWindow.append(contentsOf: monoSamples)

        while sampleWindow.count >= analysisFrameCount {
            let chunk = Array(sampleWindow.prefix(analysisFrameCount))
            analyze(chunk)
            sampleWindow.removeFirst(hopSize)
        }

        let maxWindowSize = analysisFrameCount * 3
        if sampleWindow.count > maxWindowSize {
            sampleWindow.removeFirst(sampleWindow.count - maxWindowSize)
        }
    }

    private func analyze(_ samples: [Float]) {
        let inputLevel = calculateInputLevelDecibels(samples)
        var updatedBands: [Band] = []
        updatedBands.reserveCapacity(minBandsCount)

        for index in 0..<minBandsCount {
            let definition = thirdOctaveBandDefinitions[index]
            let center = goertzelMagnitudeDb(samples: samples, frequency: definition.centerFrequency)
            let lower = goertzelMagnitudeDb(samples: samples, frequency: definition.lowerFrequency)
            let upper = goertzelMagnitudeDb(samples: samples, frequency: definition.upperFrequency)

            let combinedDb = (center + lower + upper) / 3
            let smoothed = (smoothedLevels[index] * levelSmoothing) + (combinedDb * (1 - levelSmoothing))
            smoothedLevels[index] = smoothed

            updatedBands.append(
                Band(
                    id: definition.id,
                    centerFrequency: definition.centerFrequency,
                    lowerFrequency: definition.lowerFrequency,
                    upperFrequency: definition.upperFrequency,
                    levelDecibels: smoothed
                )
            )
        }

        let sortedByEnergy = updatedBands
            .sorted { $0.levelDecibels > $1.levelDecibels }
            .filter { $0.levelDecibels > lowInputLevelThreshold }
        let dominantFrequency = sortedByEnergy.first?.centerFrequency ?? 0
        let smoothedInputLevel = (Double(inputLevel) * (1 - analysisLevelsSmoothing))
            + (inputLevelDecibels * analysisLevelsSmoothing)

        DispatchQueue.main.async {
            self.peakFrequency = dominantFrequency
            self.inputLevelDecibels = smoothedInputLevel
            self.bands = updatedBands
            if inputLevel <= self.lowInputLevelThreshold {
                self.statusText = String(localized: "analyzer.status_no_signal")
            } else {
                self.statusText = String(localized: "analyzer.status_running")
            }
        }
    }

    private func calculateInputLevelDecibels(_ samples: [Float]) -> Double {
        var sumSquares: Double = 0
        for sample in samples {
            let value = Double(sample)
            sumSquares += value * value
        }
        let meanSquare = sumSquares / max(Double(samples.count), 1)
        let rms = sqrt(meanSquare)
        return decibels(fromLinearAmplitude: rms)
    }

    private func goertzelMagnitudeDb(samples: [Float], frequency: Double) -> Double {
        guard frequency > 0, frequency < (sampleRate / 2.0) else { return minDecibelFloor }
        let normalizedFrequency = frequency / sampleRate
        let omega = 2.0 * Double.pi * normalizedFrequency
        let coefficient = 2.0 * cos(omega)

        var previous1 = 0.0
        var previous2 = 0.0
        var current = 0.0

        for sample in samples {
            current = Double(sample) + (coefficient * previous1) - previous2
            previous2 = previous1
            previous1 = current
        }

        let magnitude = previous1 * previous1 + previous2 * previous2 - (coefficient * previous1 * previous2)
        guard magnitude > 0 else { return minDecibelFloor }
        let normalized = sqrt(magnitude) / Double(max(samples.count, 1))
        return decibels(fromLinearAmplitude: normalized)
    }

    private func decibels(fromLinearAmplitude linear: Double) -> Double {
        guard linear > 1e-12 else {
            return minDecibelFloor
        }
        let db = 20.0 * log10(linear)
        return max(db, minDecibelFloor)
    }

    @discardableResult
    private func configureAudioSessionForRecording() -> Bool {
        #if canImport(UIKit) && !os(tvOS)
        let session = AVAudioSession.sharedInstance()
        previousSessionCategory = session.category
        previousSessionMode = session.mode
        previousSessionOptions = session.categoryOptions

        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])
            try session.setActive(true)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    private func restoreAudioSession() {
        #if canImport(UIKit) && !os(tvOS)
        guard let previousSessionCategory, let previousSessionMode, let previousSessionOptions else {
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(previousSessionCategory, mode: previousSessionMode, options: previousSessionOptions)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to restore audio session: \(error)")
        }
        #endif
    }

    private func removeTapIfNeeded() {
        if isTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
    }
}
