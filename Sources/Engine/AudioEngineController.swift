import AVFoundation
import QuartzCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

final class AudioEngineController: ObservableObject {
    struct CalibrationInputOption: Identifiable, Hashable {
        let id: String
        let title: String
        let detail: String
        let isLoopbackCapable: Bool
    }

    enum SignalMode: String, CaseIterable, Identifiable, Codable {
        case single = "Single Tone"
        case sweep = "Sweep"
        case noise = "Noise"

        var id: String { rawValue }
    }

    enum Waveform: String, CaseIterable, Identifiable, Codable {
        case sine = "Sine"
        case square = "Square"
        case triangle = "Triangle"
        case saw = "Saw"

        var id: String { rawValue }
    }

    enum ChannelMode: String, CaseIterable, Identifiable, Codable {
        case stereo = "L+R"
        case left = "L"
        case right = "R"

        var id: String { rawValue }
    }

    enum SweepCurve: String, CaseIterable, Identifiable, Codable {
        case linear = "Linear"
        case logarithmic = "Log"

        var id: String { rawValue }
    }

    enum SweepMode: String, CaseIterable, Identifiable, Codable {
        case sweep = "Sweep"
        case steppedSine = "Stepped Sine"

        var id: String { rawValue }
    }

    enum NoiseType: String, CaseIterable, Identifiable, Codable {
        case white = "White"
        case pink = "Pink"
        case brown = "Brown"

        var id: String { rawValue }
    }

    enum FilterMode: String, CaseIterable, Identifiable, Codable {
        case off = "Off"
        case lowPass = "Low-pass"
        case highPass = "High-pass"
        case bandPass = "Band-pass"

        var id: String { rawValue }
    }

    enum FilterSlope: String, CaseIterable, Identifiable, Codable {
        case twelveDecibels = "12 dB/oct"
        case twentyFourDecibels = "24 dB/oct"
        case fortyEightDecibels = "48 dB/oct"

        var id: String { rawValue }
    }

    @Published var selectedMode: SignalMode = .single {
        didSet {
            if oldValue != selectedMode {
                stop()
            }
            resetRealtimeStates()
            persistState()
        }
    }

    @Published var frequency: Double = 1000 {
        didSet { persistState() }
    }
    @Published var waveform: Waveform = .sine {
        didSet { persistState() }
    }
    @Published var channelMode: ChannelMode = .stereo {
        didSet { persistState() }
    }

    @Published var sweepStartFrequency: Double = 20 {
        didSet { persistState() }
    }
    @Published var sweepEndFrequency: Double = 20_000 {
        didSet { persistState() }
    }
    @Published var sweepDuration: Double = 10 {
        didSet { persistState() }
    }
    @Published var sweepStepHoldDuration: Double = 1.0 {
        didSet { persistState() }
    }
    @Published var sweepCurve: SweepCurve = .logarithmic {
        didSet { persistState() }
    }
    @Published var sweepMode: SweepMode = .sweep {
        didSet {
            resetRealtimeStates()
            persistState()
        }
    }
    @Published var sweepStepMode: FrequencyStepMode = .octave {
        didSet {
            resetRealtimeStates()
            persistState()
        }
    }
    @Published private(set) var currentSweepFrequency: Double = 20
    @Published private(set) var sweepProgress: Double = 0

    @Published var noiseType: NoiseType = .white {
        didSet { persistState() }
    }
    @Published var noiseFilterMode: FilterMode = .off {
        didSet {
            resetNoiseFilterStates()
            persistState()
        }
    }
    @Published var noiseCutoff: Double = 1000 {
        didSet { persistState() }
    }
    @Published var noiseFilterSlope: FilterSlope = .twentyFourDecibels {
        didSet {
            resetNoiseFilterStates()
            persistState()
        }
    }
    @Published var noiseBandQ: Double = 4.3 {
        didSet { persistState() }
    }

    @Published var isPlaying = false
    @Published private(set) var sampleRate: Double = 48_000
    @Published var outputGain: Double = 0.5 {
        didSet { persistState() }
    }
    @Published var safetyFadeEnabled = true {
        didSet { persistState() }
    }
    @Published var keepScreenAwake = true {
        didSet {
            applyIdleTimerPolicy()
            persistState()
        }
    }
    @Published var extendedExternalGainEnabled = false {
        didSet {
            if extendedExternalGainEnabled && !supportsExtendedExternalGain {
                extendedExternalGainEnabled = false
                return
            }
            clampOutputGainToActiveRange(resetToUnity: false)
            persistState()
        }
    }

    @Published private(set) var outputRouteName: String = String(localized: "route.detecting")
    @Published private(set) var outputRouteHint: String = String(localized: "route.checking")
    @Published private(set) var inputRouteName: String = String(localized: "calibration.input_pending")
    @Published private(set) var inputRouteHint: String = String(localized: "calibration.input_hint_pending")
    @Published private(set) var isExternalOutputRoute = false
    @Published private(set) var supportsExtendedExternalGain = false
    @Published private(set) var calibrationInputSuitable = false
    @Published private(set) var outputClipWarningActive = false
    @Published private(set) var outputDigitalPeak: Double = 0
    @Published private(set) var outputDigitalRMS: Double = 0
    @Published private(set) var currentOutputRouteKey: String = "unavailable"
    @Published private(set) var currentOutputRouteDetail: String = String(localized: "route.unavailable")
    @Published private(set) var currentInputRouteKey: String = "unavailable"
    @Published private(set) var currentInputRouteDetail: String = String(localized: "route.unavailable")
    @Published private(set) var availableCalibrationInputs: [CalibrationInputOption] = []
    @Published private(set) var selectedCalibrationInputID: String?
    @Published private(set) var activeCalibrationProfile: CalibrationProfile?
    @Published private(set) var isLoopbackCalibrationRunning = false
    @Published private(set) var loopbackCalibrationProgress: Double = 0
    @Published private(set) var loopbackCalibrationCurrentFrequency: Double = 0
    @Published private(set) var loopbackCalibrationCurrentStepNumber: Int = 0
    @Published private(set) var loopbackCalibrationTotalSteps: Int = 0
    @Published private(set) var loopbackCalibrationPhase: LoopbackCalibrationRun.Phase = .idle
    @Published private(set) var loopbackCalibrationRemainingDuration: Double = 0
    @Published private(set) var loopbackCalibrationStatus: String = String(localized: "calibration.status_idle")
    @Published private(set) var loopbackCalibrationStatusDetail: String = String(localized: "calibration.status_idle_detail")
    @Published private(set) var currentCompensationDecibels: Double = 0
    @Published private(set) var currentRouteCalibrationProfiles: [CalibrationProfile] = []
    @Published var calibrationStepMode: FrequencyStepMode = .thirdOctave {
        didSet { persistState() }
    }
    @Published var calibrationReferenceFrequency: Double = 1000 {
        didSet { persistState() }
    }
    @Published var calibrationProfileDraftName: String = "" {
        didSet { persistState() }
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let minimumFrequency = 1.0
    private let maximumFrequency = 32_000.0
    private let minimumOutputGainDecibels = -80.0
    private let standardMaximumOutputGainDecibels = 12.0
    private let extendedMaximumOutputGainDecibels = 48.0

    private var phase: Double = 0
    private var smoothedGain: Double = 0
    private var smoothedToneFrequency: Double = 1000
    private var smoothedSweepFrequency: Double = 20
    private var randomState: UInt64 = 0x1234_5678_ABCD_EF01
    private var pendingAutoStop = false
    private var clipWarningDeadline: CFTimeInterval = 0
    private var latestOutputDigitalPeak: Double = 0
    private var latestOutputDigitalRMS: Double = 0

    private var pinkB0: Double = 0
    private var pinkB1: Double = 0
    private var pinkB2: Double = 0
    private var pinkB3: Double = 0
    private var pinkB4: Double = 0
    private var pinkB5: Double = 0
    private var pinkB6: Double = 0
    private var brownState: Double = 0

    private var lowPassStates = Array(repeating: BiquadState(), count: 4)
    private var highPassStates = Array(repeating: BiquadState(), count: 4)
    private var bandPassStates = Array(repeating: BiquadState(), count: 2)

    private var playbackStartTime: CFTimeInterval?
    private var uiTimer: Timer?
    private var notificationTokens: [NSObjectProtocol] = []
    private let stateDefaultsKey = "audio_function_generator_runtime_state"
    private var isRestoringState = false
    private let calibrationStore = CalibrationProfileStore()
    private var calibrationRun: LoopbackCalibrationRun?
    private var calibrationCompletionWorkItem: DispatchWorkItem?
    private let calibrationBaseAmplitude: Double = 0.25

    init() {
        restorePersistedState()
        configureAudioSession()
        configureEngine()
        resetRealtimeStates()
        setupNotifications()
        updateAudioRouteInfo()
        applyIdleTimerPolicy()
        persistState()
    }

    deinit {
        uiTimer?.invalidate()
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
    }

    func togglePlayback() {
        isPlaying ? stop() : start()
    }

    func start() {
        guard !isLoopbackCalibrationRunning else { return }
        _ = startPlaybackIfNeeded(configureForCalibration: false)
    }

    func stop() {
        if isLoopbackCalibrationRunning {
            cancelLoopbackCalibration(markAsCancelled: true)
            return
        }
        stopPlaybackState(resetSweepPosition: true)
    }

    @discardableResult
    private func startPlaybackIfNeeded(configureForCalibration: Bool) -> Bool {
        configureAudioSession(for: configureForCalibration ? .calibration : .playback)

        if !engine.isRunning {
            do {
                try engine.start()
                sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
            } catch {
                isPlaying = false
                print("Failed to start audio engine: \(error)")
                return false
            }
        }

        resetSignalPathForFreshPlayback()
        playbackStartTime = CACurrentMediaTime()
        pendingAutoStop = false
        isPlaying = true
        updateAudioRouteInfo()
        startUITimerIfNeeded()
        return true
    }

    private func stopPlaybackState(resetSweepPosition: Bool) {
        isPlaying = false
        playbackStartTime = nil
        pendingAutoStop = false
        outputClipWarningActive = false
        clipWarningDeadline = 0
        outputDigitalPeak = 0
        outputDigitalRMS = 0
        latestOutputDigitalPeak = 0
        latestOutputDigitalRMS = 0
        currentCompensationDecibels = 0
        stopUITimer()
        if resetSweepPosition, selectedMode == .sweep {
            currentSweepFrequency = clamp(sweepStartFrequency)
            sweepProgress = 0
        }
    }

    func nudgeFrequency(by delta: Double) {
        frequency = clamp(frequency + delta)
    }

    func setFrequency(_ value: Double) {
        frequency = clamp(value)
    }

    func setSweepStartFrequency(_ value: Double) {
        sweepStartFrequency = clamp(value)
        if sweepEndFrequency < sweepStartFrequency {
            sweepEndFrequency = sweepStartFrequency
        }
        resetRealtimeStates()
    }

    func setSweepEndFrequency(_ value: Double) {
        sweepEndFrequency = clamp(value)
        if sweepEndFrequency < sweepStartFrequency {
            sweepStartFrequency = sweepEndFrequency
        }
        resetRealtimeStates()
    }

    func setNoiseCutoff(_ value: Double) {
        noiseCutoff = clamp(value)
        resetNoiseFilterStates()
    }

    func setNoiseBandQ(_ value: Double) {
        noiseBandQ = min(max(value, 0.5), 12.0)
        resetNoiseFilterStates()
    }

    func setOutputGain(_ value: Double) {
        outputGain = clampOutputGain(value)
    }

    func setOutputGain(decibels: Double) {
        if decibels <= minimumOutputGainDecibels {
            outputGain = 0
            return
        }
        setOutputGain(gain(forDecibels: min(max(decibels, minimumOutputGainDecibels), activeMaximumOutputGainDecibels)))
    }

    var clampedFrequency: Double {
        clamp(frequency)
    }

    var maximumOutputGainAllowed: Double {
        gain(forDecibels: activeMaximumOutputGainDecibels)
    }

    var minimumOutputGainAllowed: Double {
        0
    }

    var outputGainDecibels: Double {
        decibels(forGain: outputGain)
    }

    var minimumOutputGainDisplayDecibels: Double {
        minimumOutputGainDecibels
    }

    var maximumOutputGainDisplayDecibels: Double {
        activeMaximumOutputGainDecibels
    }

    var extendedOutputGainMaximumDecibels: Double {
        extendedMaximumOutputGainDecibels
    }

    var hasActiveCalibrationProfile: Bool {
        activeCalibrationProfile != nil
    }

    var isCalibrationCompensationEnabled: Bool {
        activeCalibrationProfile?.isCompensationEnabled ?? false
    }

    var activeCalibrationProfileDisplayName: String {
        activeCalibrationProfile?.displayName ?? String(localized: "calibration.profile_missing")
    }

    var calibrationProfileSummaryText: String {
        guard let activeCalibrationProfile else {
            return String(localized: "calibration.profile_missing")
        }
        return String(
            format: String(localized: "calibration.profile_summary"),
            activeCalibrationProfile.pointCount,
            FrequencyFormatting.displayString(for: activeCalibrationProfile.referenceFrequency)
        )
    }

    var calibrationProfileUpdatedText: String {
        guard let activeCalibrationProfile else {
            return String(format: String(localized: "calibration.route_key"), currentOutputRouteKey)
        }

        let timestamp = DateFormatter.localizedString(
            from: activeCalibrationProfile.updatedAt,
            dateStyle: .short,
            timeStyle: .short
        )
        return String(format: String(localized: "calibration.profile_updated"), timestamp)
    }

    var calibrationRouteDescriptionText: String {
        if let activeCalibrationProfile, !activeCalibrationProfile.routeDetail.isEmpty {
            return activeCalibrationProfile.routeDetail
        }
        return currentOutputRouteDetail
    }

    var calibrationReferenceOptions: [Double] {
        let baseOptions = [125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0]
        let available = calibrationFrequencies(for: calibrationStepMode)
        let filtered = baseOptions.filter { target in
            available.contains(where: { abs($0 - target) < 0.0001 })
        }
        return filtered.isEmpty ? baseOptions : filtered
    }

    var loopbackCalibrationPhaseTitle: String {
        loopbackCalibrationPhase.localizedTitle
    }

    var loopbackCalibrationRemainingText: String {
        durationClockText(loopbackCalibrationRemainingDuration)
    }

    var loopbackCalibrationPlanSummaryText: String {
        let stepCount = max(loopbackCalibrationTotalSteps, calibrationFrequencies(for: calibrationStepMode).count)
        let estimatedDuration = estimatedLoopbackCalibrationDuration(stepCount: stepCount)
        return String(
            format: String(localized: "calibration.plan_summary"),
            stepCount,
            calibrationStepMode.localizedTitle,
            FrequencyFormatting.displayString(for: calibrationReferenceFrequency),
            durationClockText(estimatedDuration)
        )
    }

    var calibrationResultSummaryText: String {
        guard let activeCalibrationProfile else {
            return String(localized: "calibration.result_summary_missing")
        }

        return String(
            format: String(localized: "calibration.result_summary"),
            activeCalibrationProfile.pointCount,
            activeCalibrationProfile.stepMode.localizedTitle,
            FrequencyFormatting.displayString(for: activeCalibrationProfile.referenceFrequency),
            Int(activeCalibrationProfile.sampleRate)
        )
    }

    private var activeMaximumOutputGainDecibels: Double {
        supportsExtendedExternalGain && extendedExternalGainEnabled
            ? extendedMaximumOutputGainDecibels
            : standardMaximumOutputGainDecibels
    }

    private func estimatedLoopbackCalibrationDuration(stepCount: Int) -> Double {
        0.25 + (Double(stepCount) * (0.35 + 0.45 + 0.10))
    }

    private func durationClockText(_ duration: Double) -> String {
        let totalSeconds = max(Int(duration.rounded(.up)), 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func runningStatusDetailFormat(for phase: LoopbackCalibrationRun.Phase) -> String {
        switch phase {
        case .measuring:
            return String(localized: "calibration.status_running_measuring")
        case .pausing:
            return String(localized: "calibration.status_running_pausing")
        default:
            return String(localized: "calibration.status_running_settling")
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, minimumFrequency), maximumFrequency)
    }

    private func clampOutputGain(_ value: Double) -> Double {
        min(max(value, minimumOutputGainAllowed), maximumOutputGainAllowed)
    }

    private func clampOutputGainToActiveRange(resetToUnity: Bool) {
        guard outputGainDecibels > activeMaximumOutputGainDecibels + 0.05 else { return }
        setOutputGain(decibels: resetToUnity ? 0 : activeMaximumOutputGainDecibels)
    }

    func gain(forDecibels decibels: Double) -> Double {
        if decibels <= minimumOutputGainDecibels {
            return 0
        }
        return pow(10.0, decibels / 20.0)
    }

    func decibels(forGain gain: Double) -> Double {
        guard gain > 0.00001 else { return minimumOutputGainDecibels }
        return 20.0 * log10(gain)
    }

    private func configureAudioSession(for role: AudioSessionRole = .playback) {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            switch role {
            case .playback:
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            case .calibration:
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])
            }
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
        #endif
    }

    private func configureEngine() {
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        guard let renderFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 48_000,
            channels: 2,
            interleaved: false
        ) else {
            assertionFailure("Failed to create render format")
            return
        }

        sampleRate = renderFormat.sampleRate
        engine.mainMixerNode.outputVolume = 1.0

        sourceNode = AVAudioSourceNode(format: renderFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let sr = self.sampleRate > 0 ? self.sampleRate : renderFormat.sampleRate
            let mode = self.selectedMode
            let channelMode = self.channelMode
            let waveform = self.waveform
            let toneFrequency = self.clamp(self.frequency)
            let startFrequency = self.clamp(self.sweepStartFrequency)
            let endFrequency = self.clamp(self.sweepEndFrequency)
            let sweepDuration = max(self.sweepDuration, 0.1)
            let sweepStepHoldDuration = max(self.sweepStepHoldDuration, 0.2)
            let sweepCurve = self.sweepCurve
            let sweepMode = self.sweepMode
            let sweepStepMode = self.sweepStepMode
            let noiseType = self.noiseType
            let filterMode = self.noiseFilterMode
            let filterCutoff = self.clamp(self.noiseCutoff)
            let filterSlope = self.noiseFilterSlope
            let filterQ = self.noiseBandQ
            let calibrationRun = self.calibrationRun
            let filterConfiguration = filterConfiguration(
                sampleRate: sr,
                cutoff: filterCutoff,
                mode: filterMode,
                slope: filterSlope,
                q: filterQ
            )
            let targetGain = self.isPlaying
                ? (calibrationRun == nil ? self.clampOutputGain(self.outputGain) : 1.0)
                : 0
            let gainSmoothingFactor = self.safetyFadeEnabled ? 0.0025 : 1.0
            let frequencySmoothingFactor = self.safetyFadeEnabled ? 0.0015 : 1.0
            var clippedThisBuffer = false
            var bufferPeak: Double = 0
            var bufferSumSquares: Double = 0

            for frame in 0 ..< Int(frameCount) {
                self.smoothedGain += (targetGain - self.smoothedGain) * gainSmoothingFactor

                var rawSample: Double = 0
                var compensationFrequency: Double?

                if let calibrationRun {
                    let elapsed = self.renderElapsedTime(sampleOffset: frame, sampleRate: sr)
                    let state = calibrationRun.renderState(at: elapsed)
                    if let calibrationFrequency = state.frequency, state.isToneActive {
                        self.smoothedSweepFrequency += (calibrationFrequency - self.smoothedSweepFrequency) * frequencySmoothingFactor
                        let phaseStep = self.smoothedSweepFrequency / sr
                        rawSample = sin(self.phase * 2.0 * Double.pi) * self.calibrationBaseAmplitude
                        self.advancePhase(byNormalizedIncrement: phaseStep)
                    } else {
                        rawSample = 0
                    }
                } else {
                    switch mode {
                    case .single:
                        self.smoothedToneFrequency += (toneFrequency - self.smoothedToneFrequency) * frequencySmoothingFactor
                        let phaseStep = self.smoothedToneFrequency / sr
                        rawSample = bandLimitedSample(for: waveform, phase: self.phase, phaseIncrement: phaseStep)
                        self.advancePhase(byNormalizedIncrement: phaseStep)
                        compensationFrequency = self.smoothedToneFrequency
                    case .sweep:
                        let elapsed = self.renderElapsedTime(sampleOffset: frame, sampleRate: sr)
                        let state = self.sweepState(
                            at: elapsed,
                            start: startFrequency,
                            end: endFrequency,
                            duration: sweepDuration,
                            stepHoldDuration: sweepStepHoldDuration,
                            curve: sweepCurve,
                            mode: sweepMode,
                            stepMode: sweepStepMode
                        )
                        self.smoothedSweepFrequency += (state.frequency - self.smoothedSweepFrequency) * frequencySmoothingFactor
                        let phaseStep = self.smoothedSweepFrequency / sr
                        rawSample = sin(self.phase * 2.0 * Double.pi)
                        self.advancePhase(byNormalizedIncrement: phaseStep)
                        compensationFrequency = state.frequency
                        if state.shouldStop {
                            self.requestAutoStop()
                        }
                    case .noise:
                        let noise = self.noiseSample(for: noiseType)
                        rawSample = self.filteredNoiseSample(
                            input: noise,
                            configuration: filterConfiguration
                        )
                    }
                }

                let compensatedSample = rawSample * self.compensationGain(for: mode, frequency: compensationFrequency, bypass: calibrationRun != nil)
                let sampleValue = Float(compensatedSample * self.smoothedGain)
                let sampleMagnitude = abs(Double(sampleValue))
                if sampleMagnitude > bufferPeak {
                    bufferPeak = sampleMagnitude
                }
                bufferSumSquares += Double(sampleValue) * Double(sampleValue)
                if abs(sampleValue) >= 0.999 {
                    clippedThisBuffer = true
                }
                let leftSample: Float
                let rightSample: Float

                switch calibrationRun == nil ? channelMode : .stereo {
                case .stereo:
                    leftSample = sampleValue
                    rightSample = sampleValue
                case .left:
                    leftSample = sampleValue
                    rightSample = 0
                case .right:
                    leftSample = 0
                    rightSample = sampleValue
                }

                if buffers.count > 0, let leftPointer = buffers[0].mData?.assumingMemoryBound(to: Float.self) {
                    leftPointer[frame] = leftSample
                }

                if buffers.count > 1, let rightPointer = buffers[1].mData?.assumingMemoryBound(to: Float.self) {
                    rightPointer[frame] = rightSample
                } else if buffers.count == 1, let monoPointer = buffers[0].mData?.assumingMemoryBound(to: Float.self) {
                    monoPointer[frame] = sampleValue
                }
            }

            if clippedThisBuffer {
                self.clipWarningDeadline = CACurrentMediaTime() + 0.35
            }

            if frameCount > 0 {
                self.latestOutputDigitalPeak = bufferPeak
                self.latestOutputDigitalRMS = sqrt(bufferSumSquares / Double(frameCount))
            } else {
                self.latestOutputDigitalPeak = 0
                self.latestOutputDigitalRMS = 0
            }
            return noErr
        }

        if let sourceNode {
            engine.attach(sourceNode)
            engine.connect(sourceNode, to: engine.mainMixerNode, format: renderFormat)
            engine.connect(engine.mainMixerNode, to: engine.outputNode, format: renderFormat)
        }
    }

    private func advancePhase(byNormalizedIncrement increment: Double) {
        phase += increment
        if phase >= 1.0 {
            phase -= floor(phase)
        }
    }

    private func renderElapsedTime(sampleOffset: Int, sampleRate: Double) -> Double {
        guard let playbackStartTime else { return 0 }
        let base = CACurrentMediaTime() - playbackStartTime
        return max(0, base + (Double(sampleOffset) / sampleRate))
    }

    private func compensationGain(for mode: SignalMode, frequency: Double?, bypass: Bool) -> Double {
        guard !bypass, mode != .noise, let frequency, let activeCalibrationProfile, activeCalibrationProfile.isCompensationEnabled else {
            return 1
        }
        return gain(forDecibels: activeCalibrationProfile.compensationDecibels(for: frequency))
    }

    private func sweepState(
        at elapsed: Double,
        start: Double,
        end: Double,
        duration: Double,
        stepHoldDuration: Double,
        curve: SweepCurve,
        mode: SweepMode,
        stepMode: FrequencyStepMode
    ) -> (frequency: Double, progress: Double, shouldStop: Bool) {
        switch mode {
        case .sweep:
            let clampedProgress = min(max(elapsed / duration, 0), 1)
            let frequency: Double

            switch curve {
            case .linear:
                frequency = start + ((end - start) * clampedProgress)
            case .logarithmic:
                let safeStart = max(start, 1)
                let safeEnd = max(end, 1)
                let value = log(safeStart) + (log(safeEnd) - log(safeStart)) * clampedProgress
                frequency = exp(value)
            }

            return (frequency, clampedProgress, elapsed >= duration)

        case .steppedSine:
            let frequencies = steppedSweepFrequencies(start: start, end: end, stepMode: stepMode)
            guard let lastFrequency = frequencies.last else {
                return (start, 1, true)
            }

            let hold = max(stepHoldDuration, 0.2)
            let totalDuration = hold * Double(frequencies.count)
            let rawIndex = Int(elapsed / hold)
            let index = min(max(rawIndex, 0), frequencies.count - 1)
            let progress = min(max(elapsed / totalDuration, 0), 1)
            let frequency = frequencies.indices.contains(index) ? frequencies[index] : lastFrequency
            return (frequency, progress, elapsed >= totalDuration)
        }
    }

    private func noiseSample(for type: NoiseType) -> Double {
        let white = nextWhiteNoise()

        switch type {
        case .white:
            return white
        case .pink:
            pinkB0 = 0.99886 * pinkB0 + white * 0.0555179
            pinkB1 = 0.99332 * pinkB1 + white * 0.0750759
            pinkB2 = 0.96900 * pinkB2 + white * 0.1538520
            pinkB3 = 0.86650 * pinkB3 + white * 0.3104856
            pinkB4 = 0.55000 * pinkB4 + white * 0.5329522
            pinkB5 = -0.7616 * pinkB5 - white * 0.0168980
            let pink = pinkB0 + pinkB1 + pinkB2 + pinkB3 + pinkB4 + pinkB5 + pinkB6 + white * 0.5362
            pinkB6 = white * 0.115926
            return pink * 0.11
        case .brown:
            brownState = (brownState + (0.02 * white)) / 1.02
            return brownState * 3.5
        }
    }

    private func filteredNoiseSample(input: Double, configuration: FilterConfiguration) -> Double {
        switch configuration {
        case .off:
            return input
        case let .lowPass(stages):
            return processCascade(input: input, states: &lowPassStates, coefficients: stages)
        case let .highPass(stages):
            return processCascade(input: input, states: &highPassStates, coefficients: stages)
        case let .bandPass(stages):
            return processCascade(input: input, states: &bandPassStates, coefficients: stages)
        }
    }

    private func processCascade(
        input: Double,
        states: inout [BiquadState],
        coefficients: [BiquadCoefficients]
    ) -> Double {
        var output = input
        for index in coefficients.indices {
            output = states[index].process(output, coefficients: coefficients[index])
        }
        return output
    }

    private func nextWhiteNoise() -> Double {
        randomState = 6364136223846793005 &* randomState &+ 1
        let upperBits = Double((randomState >> 11) & 0x1F_FFFF)
        let normalized = upperBits / Double(0x1F_FFFF)
        return (normalized * 2.0) - 1.0
    }

    private func resetSignalPathForFreshPlayback() {
        phase = 0
        smoothedGain = 0
        smoothedToneFrequency = clamp(frequency)
        smoothedSweepFrequency = clamp(sweepStartFrequency)
        resetNoiseFilterStates()
        brownState = 0
        pinkB0 = 0
        pinkB1 = 0
        pinkB2 = 0
        pinkB3 = 0
        pinkB4 = 0
        pinkB5 = 0
        pinkB6 = 0
        loopbackCalibrationProgress = 0
        loopbackCalibrationCurrentFrequency = 0
        resetRealtimeStates()
    }

    private func resetNoiseFilterStates() {
        for index in lowPassStates.indices {
            lowPassStates[index].reset()
        }
        for index in highPassStates.indices {
            highPassStates[index].reset()
        }
        for index in bandPassStates.indices {
            bandPassStates[index].reset()
        }
    }

    private func resetRealtimeStates() {
        outputDigitalPeak = 0
        outputDigitalRMS = 0
        latestOutputDigitalPeak = 0
        latestOutputDigitalRMS = 0
        currentCompensationDecibels = 0

        switch selectedMode {
        case .single:
            currentSweepFrequency = clampedFrequency
            sweepProgress = 0
        case .sweep:
            currentSweepFrequency = clamp(sweepStartFrequency)
            sweepProgress = 0
        case .noise:
            currentSweepFrequency = clamp(noiseCutoff)
            sweepProgress = 0
        }
    }

    private func startUITimerIfNeeded() {
        stopUITimer()
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.refreshRealtimeState()
        }
    }

    private func stopUITimer() {
        uiTimer?.invalidate()
        uiTimer = nil
    }

    private func refreshRealtimeState() {
        guard isPlaying else { return }

        let clippingNow = CACurrentMediaTime() < clipWarningDeadline
        if outputClipWarningActive != clippingNow {
            outputClipWarningActive = clippingNow
        }

        if abs(outputDigitalPeak - latestOutputDigitalPeak) > 0.0001 {
            outputDigitalPeak = latestOutputDigitalPeak
        }

        if abs(outputDigitalRMS - latestOutputDigitalRMS) > 0.0001 {
            outputDigitalRMS = latestOutputDigitalRMS
        }

        if let calibrationRun, isLoopbackCalibrationRunning {
            let elapsed = max(0, CACurrentMediaTime() - calibrationRun.startedAt)
            let state = calibrationRun.renderState(at: elapsed)
            loopbackCalibrationProgress = state.progress
            loopbackCalibrationCurrentFrequency = state.frequency ?? 0
            loopbackCalibrationCurrentStepNumber = state.stepNumber ?? 0
            loopbackCalibrationTotalSteps = calibrationRun.frequencies.count
            loopbackCalibrationPhase = state.phase
            loopbackCalibrationRemainingDuration = state.remainingDuration
            if let stepNumber = state.stepNumber, let frequency = state.frequency {
                loopbackCalibrationStatus = String(
                    format: String(localized: "calibration.status_running"),
                    stepNumber,
                    calibrationRun.frequencies.count
                )
                let frequencyText = FrequencyFormatting.displayString(for: frequency)
                loopbackCalibrationStatusDetail = String(
                    format: runningStatusDetailFormat(for: state.phase),
                    frequencyText
                )
            } else {
                loopbackCalibrationStatus = String(localized: "calibration.status_preparing")
                loopbackCalibrationStatusDetail = String(localized: "calibration.status_preparing_detail")
            }
            currentCompensationDecibels = 0
            return
        }

        switch selectedMode {
        case .single:
            currentSweepFrequency = clampedFrequency
            sweepProgress = 0
            currentCompensationDecibels = activeCalibrationProfile?.isCompensationEnabled == true
                ? (activeCalibrationProfile?.compensationDecibels(for: clampedFrequency) ?? 0)
                : 0
        case .sweep:
            let elapsed = max(0, (playbackStartTime.map { CACurrentMediaTime() - $0 }) ?? 0)
            let state = sweepState(
                at: elapsed,
                start: clamp(sweepStartFrequency),
                end: clamp(sweepEndFrequency),
                duration: max(sweepDuration, 0.1),
                stepHoldDuration: max(sweepStepHoldDuration, 0.2),
                curve: sweepCurve,
                mode: sweepMode,
                stepMode: sweepStepMode
            )
            currentSweepFrequency = state.frequency
            sweepProgress = state.progress
            currentCompensationDecibels = activeCalibrationProfile?.isCompensationEnabled == true
                ? (activeCalibrationProfile?.compensationDecibels(for: state.frequency) ?? 0)
                : 0
            if state.shouldStop {
                requestAutoStop()
            }
        case .noise:
            currentSweepFrequency = clamp(noiseCutoff)
            sweepProgress = 0
            currentCompensationDecibels = 0
        }
    }

    private func requestAutoStop() {
        guard !pendingAutoStop else { return }
        pendingAutoStop = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isPlaying {
                self.stop()
            }
        }
    }

    private func setupNotifications() {
        #if os(iOS)
        let center = NotificationCenter.default

        notificationTokens.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] _ in
                self?.updateAudioRouteInfo()
            }
        )

        notificationTokens.append(
            center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applyIdleTimerPolicy()
            }
        )
        #endif
    }

    private func updateAudioRouteInfo() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        updateInputRouteInfo(session)
        guard let primaryOutput = outputs.first else {
            outputRouteName = String(localized: "route.unknown")
            outputRouteHint = String(localized: "route.none")
            currentOutputRouteKey = "no-output"
            currentOutputRouteDetail = String(format: String(localized: "calibration.route_key"), currentOutputRouteKey)
            isExternalOutputRoute = false
            let hadExtendedSupport = supportsExtendedExternalGain
            supportsExtendedExternalGain = false
            if hadExtendedSupport {
                clampOutputGainToActiveRange(resetToUnity: true)
            }
            if extendedExternalGainEnabled {
                extendedExternalGainEnabled = false
            }
            reloadActiveCalibrationProfile()
            return
        }

        let hadExtendedSupport = supportsExtendedExternalGain
        let isExternal = isExternalRoute(primaryOutput.portType)
        let supportsExtendedGain = portSupportsExtendedGain(primaryOutput.portType)

        isExternalOutputRoute = isExternal
        supportsExtendedExternalGain = supportsExtendedGain
        outputRouteName = primaryOutput.portName
        currentOutputRouteKey = makeOutputRouteKey(primaryOutput)
        currentOutputRouteDetail = makeOutputRouteDetail(primaryOutput)

        switch primaryOutput.portType {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            outputRouteHint = String(localized: "route.bluetooth_hint")
        case .headphones, .airPlay, .usbAudio, .lineOut:
            outputRouteHint = String(localized: "route.external_hint")
        case .builtInSpeaker:
            outputRouteHint = String(localized: "route.speaker_hint")
        default:
            outputRouteHint = String(localized: "route.current_prefix") + primaryOutput.portType.rawValue
        }

        if hadExtendedSupport && !supportsExtendedGain {
            clampOutputGainToActiveRange(resetToUnity: true)
        } else {
            clampOutputGainToActiveRange(resetToUnity: false)
        }

        if !supportsExtendedGain && extendedExternalGainEnabled {
            extendedExternalGainEnabled = false
        }
        reloadActiveCalibrationProfile()
        #else
        outputRouteName = String(localized: "route.unavailable")
        outputRouteHint = String(localized: "route.ios_only")
        inputRouteName = String(localized: "route.unavailable")
        inputRouteHint = String(localized: "route.ios_only")
        calibrationInputSuitable = false
        currentOutputRouteKey = "unavailable"
        currentOutputRouteDetail = String(format: String(localized: "calibration.route_key"), currentOutputRouteKey)
        currentInputRouteKey = "unavailable"
        currentInputRouteDetail = String(format: String(localized: "calibration.route_key"), currentInputRouteKey)
        reloadActiveCalibrationProfile()
        #endif
    }

    #if os(iOS)
    private func updateInputRouteInfo(_ session: AVAudioSession) {
        let activeInput = session.currentRoute.inputs.first
        let availableInputs = session.availableInputs ?? []
        availableCalibrationInputs = availableInputs.map(makeCalibrationInputOption)

        let pendingCandidate = requestedCalibrationInputCandidate(
            availableInputs: availableInputs,
            selectedCalibrationInputID: selectedCalibrationInputID,
            primaryOutput: session.currentRoute.outputs.first?.portType
        )
        let resolvedInput = pendingCandidate ?? activeInput

        guard let resolvedInput else {
            inputRouteName = String(localized: "route.unknown")
            inputRouteHint = String(localized: "calibration.input_hint_unavailable")
            calibrationInputSuitable = false
            currentInputRouteKey = "no-input"
            currentInputRouteDetail = String(format: String(localized: "calibration.route_key"), currentInputRouteKey)
            selectedCalibrationInputID = nil
            return
        }

        let resolvedInputKey = makeInputRouteKey(resolvedInput)
        let isActive = activeInput.map(makeInputRouteKey) == resolvedInputKey
        let isSuitable = supportsLoopbackCalibrationInput(resolvedInput.portType)
        selectedCalibrationInputID = resolvedInputKey

        inputRouteName = resolvedInput.portName + (isActive ? "" : String(localized: "calibration.input_pending_suffix"))
        inputRouteHint = calibrationInputHint(for: resolvedInput.portType, isActive: isActive)
        calibrationInputSuitable = isActive && isSuitable
        currentInputRouteKey = resolvedInputKey
        currentInputRouteDetail = makeInputRouteDetail(resolvedInput)
    }

    func selectCalibrationInput(_ inputID: String) {
        selectedCalibrationInputID = inputID
        configureAudioSession(for: .calibration)
        _ = applyRequestedCalibrationInput()
        updateAudioRouteInfo()
    }

    func selectPreferredExternalCalibrationInput() {
        configureAudioSession(for: .calibration)
        let session = AVAudioSession.sharedInstance()
        if let preferredInput = preferredCalibrationInputCandidate(
            availableInputs: session.availableInputs ?? [],
            primaryOutput: session.currentRoute.outputs.first?.portType
        ) {
            selectedCalibrationInputID = makeInputRouteKey(preferredInput)
        }
        _ = applyRequestedCalibrationInput()
        updateAudioRouteInfo()
    }

    private func preparePreferredCalibrationInput() -> Bool {
        configureAudioSession(for: .calibration)
        return applyRequestedCalibrationInput()
    }

    private func applyRequestedCalibrationInput() -> Bool {
        let session = AVAudioSession.sharedInstance()
        guard let preferredInput = requestedCalibrationInputCandidate(
            availableInputs: session.availableInputs ?? [],
            selectedCalibrationInputID: selectedCalibrationInputID,
            primaryOutput: session.currentRoute.outputs.first?.portType
        ) else {
            return false
        }

        do {
            try session.setPreferredInput(preferredInput)
            selectedCalibrationInputID = makeInputRouteKey(preferredInput)
            return supportsLoopbackCalibrationInput(preferredInput.portType)
        } catch {
            print("Preferred calibration input selection failed: \(error)")
            return false
        }
    }
    #endif

    private func applyIdleTimerPolicy() {
        #if os(iOS)
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = self.keepScreenAwake
        }
        #endif
    }

    func selectCalibrationProfile(_ profileID: UUID) {
        calibrationStore.setActiveProfile(profileID, for: currentOutputRouteKey)
        reloadActiveCalibrationProfile()
    }

    func renameActiveCalibrationProfile(to name: String) {
        guard let activeCalibrationProfile else { return }
        calibrationStore.renameProfile(name, profileID: activeCalibrationProfile.id)
        reloadActiveCalibrationProfile()
    }

    func setCalibrationCompensationEnabled(_ isEnabled: Bool) {
        guard let activeCalibrationProfile else { return }
        calibrationStore.setCompensationEnabled(isEnabled, for: activeCalibrationProfile.id)
        reloadActiveCalibrationProfile()
        refreshCurrentCompensationValue()
    }

    func deleteCurrentCalibrationProfile() {
        guard let activeCalibrationProfile, !isLoopbackCalibrationRunning else { return }
        calibrationStore.deleteProfile(id: activeCalibrationProfile.id)
        reloadActiveCalibrationProfile()
        loopbackCalibrationStatus = String(localized: "calibration.status_idle")
        loopbackCalibrationStatusDetail = String(localized: "calibration.profile_deleted")
        refreshCurrentCompensationValue()
    }

    func startLoopbackCalibration() {
        guard !isLoopbackCalibrationRunning else { return }
        stopPlaybackState(resetSweepPosition: true)
        requestLoopbackRecordPermission { [weak self] isGranted in
            guard let self else { return }
            DispatchQueue.main.async {
                guard isGranted else {
                    self.loopbackCalibrationStatus = String(localized: "calibration.status_failed")
                    self.loopbackCalibrationStatusDetail = String(localized: "calibration.status_permission_denied")
                    return
                }
                self.beginLoopbackCalibration()
            }
        }
    }

    func cancelLoopbackCalibration() {
        cancelLoopbackCalibration(markAsCancelled: true)
    }

    private func beginLoopbackCalibration() {
        updateAudioRouteInfo()
        let frequencies = calibrationFrequencies(for: calibrationStepMode)
        let profileName = resolvedCalibrationProfileName(
            draftName: calibrationProfileDraftName,
            outputRouteName: outputRouteName,
            calibrationStepMode: calibrationStepMode
        )
        let run = LoopbackCalibrationRun(
            profileName: profileName,
            routeKey: currentOutputRouteKey,
            routeName: outputRouteName,
            routeDetail: currentOutputRouteDetail,
            startedAt: CACurrentMediaTime(),
            sampleRate: sampleRate,
            referenceFrequency: calibrationReferenceFrequency,
            stepMode: calibrationStepMode,
            frequencies: frequencies,
            startDelay: 0.25,
            settleDuration: 0.35,
            measureDuration: 0.45,
            pauseDuration: 0.10
        )

        configureAudioSession(for: .calibration)
        guard preparePreferredCalibrationInput() else {
            loopbackCalibrationStatus = String(localized: "calibration.status_failed")
            loopbackCalibrationStatusDetail = String(localized: "calibration.status_failed_builtin_input")
            configureAudioSession(for: .playback)
            updateAudioRouteInfo()
            return
        }

        installLoopbackTap()
        calibrationRun = run
        isLoopbackCalibrationRunning = true
        loopbackCalibrationProgress = 0
        loopbackCalibrationCurrentFrequency = 0
        loopbackCalibrationCurrentStepNumber = 0
        loopbackCalibrationTotalSteps = frequencies.count
        loopbackCalibrationPhase = .preparing
        loopbackCalibrationRemainingDuration = run.totalDuration
        loopbackCalibrationStatus = String(localized: "calibration.status_preparing")
        loopbackCalibrationStatusDetail = String(localized: "calibration.status_preparing_detail")
        guard startPlaybackIfNeeded(configureForCalibration: true) else {
            removeLoopbackTapIfNeeded()
            calibrationRun = nil
            isLoopbackCalibrationRunning = false
            loopbackCalibrationCurrentStepNumber = 0
            loopbackCalibrationPhase = .idle
            loopbackCalibrationRemainingDuration = 0
            loopbackCalibrationStatus = String(localized: "calibration.status_failed")
            loopbackCalibrationStatusDetail = String(localized: "calibration.status_failed_no_signal")
            configureAudioSession(for: .playback)
            return
        }

        updateAudioRouteInfo()
        guard calibrationInputSuitable else {
            removeLoopbackTapIfNeeded()
            calibrationRun = nil
            isLoopbackCalibrationRunning = false
            stopPlaybackState(resetSweepPosition: true)
            loopbackCalibrationCurrentStepNumber = 0
            loopbackCalibrationPhase = .idle
            loopbackCalibrationRemainingDuration = 0
            loopbackCalibrationStatus = String(localized: "calibration.status_failed")
            loopbackCalibrationStatusDetail = String(localized: "calibration.status_failed_builtin_input")
            configureAudioSession(for: .playback)
            updateAudioRouteInfo()
            return
        }

        scheduleLoopbackCalibrationCompletion(for: run)
    }

    private func scheduleLoopbackCalibrationCompletion(for run: LoopbackCalibrationRun) {
        calibrationCompletionWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.completeLoopbackCalibration(token: run.id)
        }
        calibrationCompletionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + run.totalDuration + 0.25, execute: workItem)
    }

    private func completeLoopbackCalibration(token: UUID) {
        guard let run = calibrationRun, run.id == token else { return }

        calibrationCompletionWorkItem?.cancel()
        calibrationCompletionWorkItem = nil
        removeLoopbackTapIfNeeded()
        calibrationRun = nil
        isLoopbackCalibrationRunning = false
        loopbackCalibrationCurrentStepNumber = run.frequencies.count
        loopbackCalibrationTotalSteps = run.frequencies.count
        loopbackCalibrationPhase = .completed
        loopbackCalibrationRemainingDuration = 0
        stopPlaybackState(resetSweepPosition: true)
        configureAudioSession(for: .playback)

        let measurements = run.measuredPoints(minimumSamples: 256)
        guard measurements.count >= max(4, run.frequencies.count / 2) else {
            loopbackCalibrationStatus = String(localized: "calibration.status_failed")
            loopbackCalibrationStatusDetail = String(localized: "calibration.status_failed_no_signal")
            loopbackCalibrationProgress = 0
            loopbackCalibrationCurrentFrequency = 0
            loopbackCalibrationCurrentStepNumber = 0
            loopbackCalibrationTotalSteps = 0
            loopbackCalibrationPhase = .idle
            updateAudioRouteInfo()
            return
        }

        let calibrationResult = makeCalibrationProfile(from: run, measurements: measurements)
        let profile = calibrationResult.profile
        calibrationStore.save(profile)
        reloadActiveCalibrationProfile()
        loopbackCalibrationProgress = 1
        loopbackCalibrationCurrentFrequency = calibrationResult.referenceFrequency
        loopbackCalibrationStatus = String(localized: "calibration.status_complete")
        loopbackCalibrationStatusDetail = String(
            format: String(localized: "calibration.status_complete_detail"),
            profile.pointCount
        )
        refreshCurrentCompensationValue()
        updateAudioRouteInfo()
    }

    private func cancelLoopbackCalibration(markAsCancelled: Bool) {
        calibrationCompletionWorkItem?.cancel()
        calibrationCompletionWorkItem = nil
        removeLoopbackTapIfNeeded()
        calibrationRun = nil
        isLoopbackCalibrationRunning = false
        loopbackCalibrationProgress = 0
        loopbackCalibrationCurrentFrequency = 0
        loopbackCalibrationCurrentStepNumber = 0
        loopbackCalibrationTotalSteps = 0
        loopbackCalibrationPhase = .idle
        loopbackCalibrationRemainingDuration = 0
        stopPlaybackState(resetSweepPosition: true)
        configureAudioSession(for: .playback)
        updateAudioRouteInfo()
        if markAsCancelled {
            loopbackCalibrationStatus = String(localized: "calibration.status_cancelled")
            loopbackCalibrationStatusDetail = String(localized: "calibration.status_cancelled_detail")
        }
    }

    private func installLoopbackTap() {
        let inputNode = engine.inputNode
        inputNode.removeTap(onBus: 0)
        let format = inputNode.inputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self, let calibrationRun = self.calibrationRun, self.isLoopbackCalibrationRunning else { return }
            let elapsed = max(0, CACurrentMediaTime() - calibrationRun.startedAt)
            calibrationRun.record(buffer: buffer, elapsed: elapsed)
        }
    }

    private func removeLoopbackTapIfNeeded() {
        engine.inputNode.removeTap(onBus: 0)
    }

    private func requestLoopbackRecordPermission(completion: @escaping (Bool) -> Void) {
        #if os(iOS)
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

    private func reloadActiveCalibrationProfile() {
        currentRouteCalibrationProfiles = calibrationStore.profiles(for: currentOutputRouteKey)
        activeCalibrationProfile = calibrationStore.activeProfile(for: currentOutputRouteKey)
        if let activeCalibrationProfile {
            calibrationProfileDraftName = activeCalibrationProfile.displayName
            calibrationReferenceFrequency = activeCalibrationProfile.referenceFrequency
            calibrationStepMode = activeCalibrationProfile.stepMode
        } else if calibrationProfileDraftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            calibrationProfileDraftName = outputRouteName
        }
        refreshCurrentCompensationValue()
    }

    private func refreshCurrentCompensationValue() {
        guard let activeCalibrationProfile, activeCalibrationProfile.isCompensationEnabled else {
            currentCompensationDecibels = 0
            return
        }

        switch selectedMode {
        case .single:
            currentCompensationDecibels = activeCalibrationProfile.compensationDecibels(for: clampedFrequency)
        case .sweep:
            currentCompensationDecibels = activeCalibrationProfile.compensationDecibels(for: currentSweepFrequency)
        case .noise:
            currentCompensationDecibels = 0
        }
    }

    func makePreset(named name: String) -> AppPreset {
        AppPreset(
            name: name,
            mode: selectedMode,
            frequency: frequency,
            waveform: waveform,
            sweepStartFrequency: sweepStartFrequency,
            sweepEndFrequency: sweepEndFrequency,
            sweepDuration: sweepDuration,
            sweepStepHoldDuration: sweepStepHoldDuration,
            sweepCurve: sweepCurve,
            sweepMode: sweepMode,
            sweepStepMode: sweepStepMode,
            noiseType: noiseType,
            noiseFilterMode: noiseFilterMode,
            noiseCutoff: noiseCutoff,
            noiseFilterSlope: noiseFilterSlope,
            noiseBandQ: noiseBandQ,
            channelMode: channelMode,
            outputGain: outputGain,
            safetyFadeEnabled: safetyFadeEnabled
        )
    }

    func applyPreset(_ preset: AppPreset) {
        selectedMode = preset.mode
        frequency = clamp(preset.frequency)
        waveform = preset.waveform
        sweepStartFrequency = clamp(preset.sweepStartFrequency)
        sweepEndFrequency = clamp(preset.sweepEndFrequency)
        sweepDuration = max(preset.sweepDuration, 0.1)
        sweepStepHoldDuration = max(preset.sweepStepHoldDuration, 0.2)
        sweepCurve = preset.sweepCurve
        sweepMode = preset.sweepMode
        sweepStepMode = preset.sweepStepMode
        noiseType = preset.noiseType
        noiseFilterMode = preset.noiseFilterMode
        noiseCutoff = clamp(preset.noiseCutoff)
        noiseFilterSlope = preset.noiseFilterSlope
        noiseBandQ = min(max(preset.noiseBandQ, 0.5), 12.0)
        channelMode = preset.channelMode
        outputGain = clampOutputGain(preset.outputGain)
        safetyFadeEnabled = preset.safetyFadeEnabled
        resetRealtimeStates()
        persistState()
    }

    func resetToDefaults() {
        selectedMode = .single
        frequency = 1000
        waveform = .sine
        sweepStartFrequency = 20
        sweepEndFrequency = 20_000
        sweepDuration = 10
        sweepStepHoldDuration = 1.0
        sweepCurve = .logarithmic
        sweepMode = .sweep
        sweepStepMode = .octave
        noiseType = .white
        noiseFilterMode = .off
        noiseCutoff = 1000
        noiseFilterSlope = .twentyFourDecibels
        noiseBandQ = 4.3
        channelMode = .stereo
        outputGain = gain(forDecibels: 0)
        safetyFadeEnabled = true
        keepScreenAwake = true
        extendedExternalGainEnabled = false
        calibrationStepMode = .thirdOctave
        calibrationReferenceFrequency = 1000
        calibrationProfileDraftName = outputRouteName
        loopbackCalibrationCurrentStepNumber = 0
        loopbackCalibrationTotalSteps = 0
        loopbackCalibrationPhase = .idle
        loopbackCalibrationRemainingDuration = 0
        loopbackCalibrationStatus = String(localized: "calibration.status_idle")
        loopbackCalibrationStatusDetail = String(localized: "calibration.status_idle_detail")
        resetSignalPathForFreshPlayback()
        persistState()
    }

    private func persistState() {
        guard !isRestoringState else { return }

        let state = PersistedState(
            selectedMode: selectedMode,
            frequency: frequency,
            waveform: waveform,
            channelMode: channelMode,
            sweepStartFrequency: sweepStartFrequency,
            sweepEndFrequency: sweepEndFrequency,
            sweepDuration: sweepDuration,
            sweepStepHoldDuration: sweepStepHoldDuration,
            sweepCurve: sweepCurve,
            sweepMode: sweepMode,
            sweepStepMode: sweepStepMode,
            noiseType: noiseType,
            noiseFilterMode: noiseFilterMode,
            noiseCutoff: noiseCutoff,
            noiseFilterSlope: noiseFilterSlope,
            noiseBandQ: noiseBandQ,
            outputGain: outputGain,
            safetyFadeEnabled: safetyFadeEnabled,
            keepScreenAwake: keepScreenAwake,
            extendedExternalGainEnabled: extendedExternalGainEnabled,
            calibrationStepMode: calibrationStepMode,
            calibrationReferenceFrequency: calibrationReferenceFrequency,
            calibrationProfileDraftName: calibrationProfileDraftName
        )

        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: stateDefaultsKey)
        } catch {
            print("Failed to persist runtime state: \(error)")
        }
    }

    private func restorePersistedState() {
        guard let data = UserDefaults.standard.data(forKey: stateDefaultsKey) else { return }
        do {
            let state = try JSONDecoder().decode(PersistedState.self, from: data)
            isRestoringState = true
            selectedMode = state.selectedMode
            frequency = clamp(state.frequency)
            waveform = state.waveform
            channelMode = state.channelMode
            sweepStartFrequency = clamp(state.sweepStartFrequency)
            sweepEndFrequency = clamp(state.sweepEndFrequency)
            sweepDuration = max(state.sweepDuration, 0.1)
            sweepStepHoldDuration = max(state.sweepStepHoldDuration, 0.2)
            sweepCurve = state.sweepCurve
            sweepMode = state.sweepMode
            sweepStepMode = state.sweepStepMode
            noiseType = state.noiseType
            noiseFilterMode = state.noiseFilterMode
            noiseCutoff = clamp(state.noiseCutoff)
            noiseFilterSlope = state.noiseFilterSlope
            noiseBandQ = min(max(state.noiseBandQ, 0.5), 12.0)
            outputGain = clampOutputGain(state.outputGain)
            safetyFadeEnabled = state.safetyFadeEnabled
            keepScreenAwake = state.keepScreenAwake
            extendedExternalGainEnabled = state.extendedExternalGainEnabled
            calibrationStepMode = state.calibrationStepMode
            calibrationReferenceFrequency = state.calibrationReferenceFrequency
            calibrationProfileDraftName = state.calibrationProfileDraftName
            isRestoringState = false
        } catch {
            isRestoringState = false
            print("Failed to restore runtime state: \(error)")
        }
    }
}
