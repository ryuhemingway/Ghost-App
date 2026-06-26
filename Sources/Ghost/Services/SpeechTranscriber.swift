import AVFoundation
import Foundation
import Observation
import Speech

@Observable
@MainActor
final class SpeechTranscriber {
    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    var isRecording = false
    var authorizationMessage: String?

    func toggle(onTranscript: @escaping @MainActor (String) -> Void) {
        if isRecording {
            stop()
            return
        }

        Task {
            do {
                try await requestPermissions()
                try start(onTranscript: onTranscript)
            } catch {
                authorizationMessage = error.localizedDescription
                stop()
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    private func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw SpeechTranscriberError.speechNotAuthorized
        }

        let microphoneStatus = await AVCaptureDevice.requestAccess(for: .audio)
        guard microphoneStatus else {
            throw SpeechTranscriberError.microphoneNotAuthorized
        }
    }

    private func start(onTranscript: @escaping @MainActor (String) -> Void) throws {
        stop()

        guard let recognizer, recognizer.isAvailable else {
            throw SpeechTranscriberError.recognizerUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        authorizationMessage = nil

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                if let result {
                    onTranscript(result.bestTranscription.formattedString)
                }

                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }
}

enum SpeechTranscriberError: LocalizedError {
    case speechNotAuthorized
    case microphoneNotAuthorized
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .speechNotAuthorized:
            "Speech recognition permission is needed."
        case .microphoneNotAuthorized:
            "Microphone permission is needed."
        case .recognizerUnavailable:
            "Speech recognition is not available right now."
        }
    }
}
