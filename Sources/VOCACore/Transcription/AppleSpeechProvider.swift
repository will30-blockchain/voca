import Foundation
import Speech
import AVFoundation

/// On-device Apple Speech transcription — zero cost, no network, but quality
/// trails cloud Whisper. We feed it the recorded WAV file directly.
public struct AppleSpeechProvider: STTProvider {
    public let id: STTProviderID = .appleSpeech

    public init() {}

    public func transcribe(_ request: STTRequest, model _: String) async throws -> STTResult {
        let locale: Locale = {
            if request.language == "auto" || request.language.isEmpty {
                return Locale.current
            }
            return Locale(identifier: request.language)
        }()

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw STTError.unsupported("Apple Speech is unavailable for locale \(locale.identifier)")
        }

        // Authorisation gate.
        let auth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard auth == .authorized else {
            throw STTError.unsupported("Speech recognition permission not granted (status: \(auth.rawValue)).")
        }

        // Write the WAV to a temp file because SFSpeech consumes file URLs reliably.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("vt-\(UUID().uuidString).wav")
        try request.audio.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let recognition = SFSpeechURLRecognitionRequest(url: tmp)
        recognition.requiresOnDeviceRecognition = true
        recognition.shouldReportPartialResults = false
        // On-device biasing: Apple Speech ignores freeform prompts but honours
        // `contextualStrings`. This is the only STT bias signal available
        // offline. Cap defensively — the list arrives pre-ranked.
        if !request.biasTerms.isEmpty {
            recognition.contextualStrings = Array(request.biasTerms.prefix(100))
        }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<STTResult, Error>) in
            let box = ContinuationBox(cont)
            // Guarantee the continuation resumes even if the recognizer never
            // reports a final result (it can stay silent on very short clips).
            DispatchQueue.global().asyncAfter(deadline: .now() + 8) {
                box.resumeIfNeeded(.failure(STTError.empty))
            }

            let task = recognizer.recognitionTask(with: recognition) { result, error in
                if let error {
                    box.resumeIfNeeded(.failure(error))
                    return
                }
                if let result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                    if text.isEmpty {
                        box.resumeIfNeeded(.failure(STTError.empty))
                    } else {
                        box.resumeIfNeeded(.success(STTResult(text: text, detectedLanguage: locale.identifier)))
                    }
                }
            }
            box.task = task
        }
    }
}

private final class ContinuationBox: @unchecked Sendable {
    private let cont: CheckedContinuation<STTResult, Error>
    private let lock = NSLock()
    private var done = false
    var task: SFSpeechRecognitionTask?

    init(_ cont: CheckedContinuation<STTResult, Error>) { self.cont = cont }

    func resumeIfNeeded(_ result: Result<STTResult, Error>) {
        lock.lock()
        let alreadyDone = done
        done = true
        lock.unlock()
        guard !alreadyDone else { return }
        task?.cancel()
        switch result {
        case .success(let r): cont.resume(returning: r)
        case .failure(let e): cont.resume(throwing: e)
        }
    }
}
