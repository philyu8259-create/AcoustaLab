import AVFoundation
import Foundation

func isExternalRoute(_ portType: AVAudioSession.Port) -> Bool {
    switch portType {
    case .headphones, .airPlay, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .usbAudio, .lineOut:
        return true
    default:
        return false
    }
}

func portSupportsExtendedGain(_ portType: AVAudioSession.Port) -> Bool {
    switch portType {
    case .headphones, .usbAudio, .lineOut:
        return true
    default:
        return false
    }
}

func supportsLoopbackCalibrationInput(_ portType: AVAudioSession.Port) -> Bool {
    switch portType {
    case .usbAudio, .lineIn, .headsetMic:
        return true
    default:
        return false
    }
}

func calibrationInputHint(for portType: AVAudioSession.Port, isActive: Bool) -> String {
    if !isActive {
        return String(localized: "calibration.input_hint_pending")
    }

    switch portType {
    case .usbAudio, .lineIn, .headsetMic:
        return String(localized: "calibration.input_hint_external")
    case .builtInMic:
        return String(localized: "calibration.input_hint_builtin")
    default:
        return String(localized: "calibration.input_hint_unavailable")
    }
}

func requestedCalibrationInputCandidate(
    availableInputs: [AVAudioSessionPortDescription],
    selectedCalibrationInputID: String?,
    primaryOutput: AVAudioSession.Port?
) -> AVAudioSessionPortDescription? {
    guard !availableInputs.isEmpty else { return nil }

    if let selectedCalibrationInputID,
       let selectedInput = availableInputs.first(where: { makeInputRouteKey($0) == selectedCalibrationInputID }) {
        return selectedInput
    }

    return preferredCalibrationInputCandidate(
        availableInputs: availableInputs,
        primaryOutput: primaryOutput
    )
}

func preferredCalibrationInputCandidate(
    availableInputs: [AVAudioSessionPortDescription],
    primaryOutput: AVAudioSession.Port?
) -> AVAudioSessionPortDescription? {
    guard !availableInputs.isEmpty else { return nil }

    let preferredTypes: [AVAudioSession.Port]
    switch primaryOutput {
    case .usbAudio:
        preferredTypes = [.usbAudio, .lineIn, .headsetMic]
    case .lineOut, .headphones:
        preferredTypes = [.lineIn, .usbAudio, .headsetMic]
    default:
        preferredTypes = [.usbAudio, .lineIn, .headsetMic]
    }

    for preferredType in preferredTypes {
        if let match = availableInputs.first(where: { $0.portType == preferredType }) {
            return match
        }
    }

    return availableInputs.first
}

func makeCalibrationInputOption(_ input: AVAudioSessionPortDescription) -> AudioEngineController.CalibrationInputOption {
    AudioEngineController.CalibrationInputOption(
        id: makeInputRouteKey(input),
        title: input.portName,
        detail: input.portType.rawValue,
        isLoopbackCapable: supportsLoopbackCalibrationInput(input.portType)
    )
}

func makeInputRouteKey(_ input: AVAudioSessionPortDescription) -> String {
    let uid = input.uid.trimmingCharacters(in: .whitespacesAndNewlines)
    if uid.isEmpty {
        return "\(input.portType.rawValue)|\(input.portName)"
    }
    return "\(input.portType.rawValue)|\(uid)"
}

func makeInputRouteDetail(_ input: AVAudioSessionPortDescription) -> String {
    let key = makeInputRouteKey(input)
    return "\(input.portName) · \(input.portType.rawValue) · \(key)"
}

func makeOutputRouteKey(_ primaryOutput: AVAudioSessionPortDescription) -> String {
    let uid = primaryOutput.uid.trimmingCharacters(in: .whitespacesAndNewlines)
    if uid.isEmpty {
        return "\(primaryOutput.portType.rawValue)|\(primaryOutput.portName)"
    }
    return "\(primaryOutput.portType.rawValue)|\(uid)"
}

func makeOutputRouteDetail(_ primaryOutput: AVAudioSessionPortDescription) -> String {
    let key = makeOutputRouteKey(primaryOutput)
    return "\(primaryOutput.portName) · \(primaryOutput.portType.rawValue) · \(key)"
}
