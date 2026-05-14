import Foundation
import Combine

public enum DictationMode: Sendable, Equatable {
    case transcribe
    case translate
}

public enum ProcessingStage: String, Sendable, Equatable, CaseIterable {
    case encoding, transcribing, refining, translating, injecting

    public var label: String {
        switch self {
        case .encoding:     return "Encoding…"
        case .transcribing: return "Transcribing…"
        case .refining:     return "Refining…"
        case .translating:  return "Translating…"
        case .injecting:    return "Injecting…"
        }
    }

    /// Fraction of the pipeline that has nominally completed once this stage
    /// is reached. Tuned so the bar visibly advances at each step rather than
    /// holding still — STT dominates the wall time so it spans the widest band.
    public var progress: Double {
        switch self {
        case .encoding:     return 0.08
        case .transcribing: return 0.45
        case .refining:     return 0.85
        case .translating:  return 0.85
        case .injecting:    return 0.97
        }
    }
}

public enum EngineState: Sendable, Equatable {
    case idle
    case recording(mode: DictationMode)
    case processing(mode: DictationMode, stage: ProcessingStage)
    case error(message: String)

    /// True when the last pipeline ended in `.error` and a retry is available.
    public var isRetryable: Bool {
        if case .error = self { return true }
        return false
    }
}

@MainActor
public final class VOCAEngine: ObservableObject {
    @Published public private(set) var state: EngineState = .idle

    public let history: TranscriptHistory
    public let recorder: AudioRecorder
    public let log: LogStore
    public let learner: CorrectionLearner
    public let sounds: SoundPlayer

    /// True when the engine has audio buffered from the previous take and
    /// can re-run the pipeline without re-recording.
    @Published public private(set) var canRetry: Bool = false

    private let settingsStore: SettingsStore
    private let memory: PersonalMemory
    private let dictionary: UserDictionary
    private let injector: TextInjector
    private let urlSession: URLSession

    /// Last successfully-captured recording. Retained so the user can hit
    /// "Retry" after a network blip — we don't need to re-record.
    private var lastRecording: AudioRecorder.Recording?
    private var lastMode: DictationMode = .transcribe

    public init(
        settingsStore: SettingsStore,
        memory: PersonalMemory,
        dictionary: UserDictionary,
        recorder: AudioRecorder,
        injector: TextInjector,
        log: LogStore,
        urlSession: URLSession? = nil
    ) {
        self.settingsStore = settingsStore
        self.memory = memory
        self.dictionary = dictionary
        self.recorder = recorder
        self.injector = injector
        self.log = log
        // Dedicated session so transient retries don't fight the
        // shared session's connection pool, and per-request timeout is
        // generous enough for a slow Whisper upload.
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            config.waitsForConnectivity = true
            self.urlSession = URLSession(configuration: config)
        }
        self.history = TranscriptHistory()
        self.learner = CorrectionLearner(dictionary: dictionary, memory: memory, log: log)
        self.sounds = SoundPlayer()
    }

    /// Tap-toggle entry point. If idle, starts a recording in the given mode.
    /// If recording, stops it and pushes the result through the pipeline.
    /// If processing, ignores the tap (so a double-tap won't pile up requests).
    public func toggleRecording(mode: DictationMode) async {
        switch state {
        case .idle:
            await beginRecording(mode: mode)
        case .recording:
            await endRecording()
        case .processing:
            AppLog.engine.info("Ignored toggle while processing.")
        case .error:
            state = .idle
        }
    }

    public func beginRecording(mode: DictationMode) async {
        guard case .idle = state else { return }
        // The user has clearly moved on from the previous paste — a great
        // moment to scan that field for typo corrections to learn from.
        if settingsStore.settings.learnFromCorrections {
            learner.reviewPendingPaste()
        }
        do {
            try await recorder.start()
            state = .recording(mode: mode)
            // Starting a fresh recording invalidates the previous "retry" buffer.
            lastRecording = nil
            canRetry = false
            log.info(.engine, "Recording started", detail: ["mode": mode == .translate ? "translate" : "transcribe"])
            if settingsStore.settings.playSounds {
                sounds.playStart()
            }
        } catch {
            state = .error(message: error.localizedDescription)
            AppLog.engine.error("recorder.start failed: \(String(describing: error), privacy: .public)")
            log.error(.audio, "Recorder failed to start", detail: ["error": error.localizedDescription])
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            state = .idle
        }
    }

    public func endRecording() async {
        guard case .recording(let mode) = state else { return }
        do {
            let recording = try await recorder.stop()
            if settingsStore.settings.playSounds {
                sounds.playStop()
            }
            try await runPipeline(recording: recording, mode: mode)
        } catch {
            AppLog.engine.error("recorder stop failed: \(String(describing: error), privacy: .public)")
            log.error(.audio, "Recorder stop failed", detail: ["error": error.localizedDescription])
            state = .error(message: error.localizedDescription)
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if case .error = state { state = .idle }
        }
    }

    /// Re-runs the pipeline using the previously-captured audio — used by
    /// the HUD's "Retry" button so the user doesn't have to speak again
    /// after a transient API or network failure.
    public func retryLastRecording() async {
        guard let recording = lastRecording else {
            log.warning(.engine, "Retry requested but no recording is buffered")
            return
        }
        // Only retry from .error or .idle; ignore taps mid-recording / mid-processing.
        switch state {
        case .error, .idle: break
        default: return
        }
        log.info(.engine, "Retrying last recording", detail: [
            "duration_s": String(format: "%.2f", recording.duration)
        ])
        do {
            try await runPipeline(recording: recording, mode: lastMode)
        } catch {
            log.error(.engine, "Retry failed", detail: ["error": error.localizedDescription])
            state = .error(message: error.localizedDescription)
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if case .error = state { state = .idle }
        }
    }

    private func runPipeline(recording: AudioRecorder.Recording, mode: DictationMode) async throws {
        let startedAt = Date()
        let peakStr = String(format: "%.4f", recording.peakLevel)
        let durStr = String(format: "%.2f", recording.duration)
        log.info(.audio, "Recording captured",
                 detail: ["duration_s": durStr, "peak": peakStr, "bytes": "\(recording.audio.count)"])

        if recording.audio.isEmpty || recording.duration < 0.25 {
            state = .idle
            lastRecording = nil
            canRetry = false
            log.info(.engine, "Take too short — ignored", detail: ["duration_s": durStr])
            return
        }

        // Skip the API call on completely silent recordings.
        if recording.peakLevel < HallucinationFilter.silenceThreshold {
            state = .idle
            lastRecording = nil
            canRetry = false
            log.info(.filter, "Silent recording — skipped transcribe",
                     detail: ["peak": peakStr, "threshold": "\(HallucinationFilter.silenceThreshold)"])
            return
        }

        // Buffer the audio so the user can hit Retry on transient failures.
        lastRecording = recording
        lastMode = mode
        canRetry = true

        try await runRemoteStages(recording: recording, mode: mode, startedAt: startedAt)
    }

    private func runRemoteStages(
        recording: AudioRecorder.Recording,
        mode: DictationMode,
        startedAt: Date
    ) async throws {
        do {

            state = .processing(mode: mode, stage: .transcribing)
            let sttProvider = settingsStore.settings.sttProvider.rawValue
            let sttModel = settingsStore.settings.sttModel
            let sttStart = Date()
            let raw = try await transcribe(recording)
            let sttLatency = String(format: "%.2f", Date().timeIntervalSince(sttStart))
            log.info(.stt, "Transcribed",
                     detail: [
                        "provider": sttProvider, "model": sttModel,
                        "language": raw.detectedLanguage ?? "auto",
                        "chars": "\(raw.text.count)",
                        "latency_s": sttLatency
                     ])

            switch HallucinationFilter.decide(transcript: raw.text, peakLevel: recording.peakLevel) {
            case .drop(let reason):
                state = .idle
                // Never persist dropped transcript text — could contain
                // personal speech and would land in world-readable log.jsonl.
                log.info(.filter, "Transcript dropped",
                         detail: ["reason": reason, "chars": "\(raw.text.count)"])
                return
            case .keep:
                break
            }

            state = .processing(mode: mode, stage: mode == .translate ? .translating : .refining)
            let llmProvider = settingsStore.settings.llmProvider.rawValue
            let llmModel = settingsStore.settings.llmModel
            let llmStart = Date()
            let finalText = try await refine(raw: raw, mode: mode)
            let llmLatency = String(format: "%.2f", Date().timeIntervalSince(llmStart))
            if settingsStore.settings.llmProvider != .disabled {
                log.info(.llm, mode == .translate ? "Translated" : "Refined",
                         detail: [
                            "provider": llmProvider, "model": llmModel,
                            "in_chars": "\(raw.text.count)", "out_chars": "\(finalText.count)",
                            "latency_s": llmLatency
                         ])
            }

            state = .processing(mode: mode, stage: .injecting)
            try await injector.inject(finalText, method: settingsStore.settings.injectionMethod)
            log.info(.inject, "Injected text",
                     detail: ["chars": "\(finalText.count)", "method": settingsStore.settings.injectionMethod.rawValue])

            // Capture the focused text element NOW so we can re-read it on
            // the next dictation and learn from any typo corrections.
            if settingsStore.settings.learnFromCorrections {
                learner.recordPaste(finalText)
            }
            if settingsStore.settings.learningEnabled {
                memory.ingest(transcript: finalText)
            }
            history.append(mode: mode, text: finalText)

            let total = String(format: "%.2f", Date().timeIntervalSince(startedAt))
            log.info(.engine, "Pipeline complete", detail: ["total_s": total])

            // Successful pipeline → no point keeping the audio buffer.
            lastRecording = nil
            canRetry = false
            state = .idle
        } catch {
            AppLog.engine.error("pipeline failed: \(String(describing: error), privacy: .public)")
            log.error(.engine, "Pipeline failed",
                      detail: [
                        "error": error.localizedDescription,
                        "type": String(describing: type(of: error))
                      ])
            // Keep `lastRecording` populated so the HUD's Retry button still
            // works — the audio is fine, only the remote stages failed.
            state = .error(message: error.localizedDescription)
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if case .error = state {
                // If the user didn't tap Retry within the window, clear.
                state = .idle
            }
        }
    }

    public func cancelRecording() async {
        switch state {
        case .recording:
            _ = try? await recorder.stop()
            lastRecording = nil
            canRetry = false
            state = .idle
            log.info(.engine, "Recording cancelled")
        case .error:
            // User dismissed the error — clear retry buffer too.
            lastRecording = nil
            canRetry = false
            state = .idle
            log.info(.engine, "Error dismissed")
        default:
            break
        }
    }

    // MARK: - Pipeline

    private func transcribe(_ rec: AudioRecorder.Recording) async throws -> STTResult {
        let s = settingsStore.settings
        let provider = STTProviderFactory.make(id: s.sttProvider, credentials: s.credentials, session: urlSession)

        let biasPieces: [String] = [dictionary.biasPrompt(), memory.topPhrases(limit: 12).joined(separator: ", ").nilIfEmpty]
            .compactMap { $0 }
        let prompt = biasPieces.isEmpty ? nil : "Glossary: " + biasPieces.joined(separator: " | ")

        let req = STTRequest(
            audio: rec.audio,
            sampleRate: rec.sampleRate,
            mimeType: "audio/wav",
            filename: "audio.wav",
            language: s.primaryLanguage,
            prompt: prompt
        )
        return try await withTransientRetry(category: .stt, label: "transcribe") {
            try await provider.transcribe(req, model: s.sttModel)
        }
    }

    private func refine(raw: STTResult, mode: DictationMode) async throws -> String {
        let s = settingsStore.settings
        if s.llmProvider == .disabled {
            return raw.text
        }
        let provider = LLMProviderFactory.make(id: s.llmProvider, credentials: s.credentials, session: urlSession)

        let system: String
        let user: String
        switch mode {
        case .transcribe:
            system = RefinementPrompts.system(
                tone: s.tone,
                glossary: dictionary.entries.map { $0.term },
                memoryPhrases: memory.topPhrases(limit: 20),
                personalFacts: memory.snapshot.personalFacts,
                detectedLanguage: raw.detectedLanguage
            )
            user = RefinementPrompts.user(transcript: raw.text)
        case .translate:
            system = TranslationPrompts.system(
                source: s.translateSourceLanguage,
                target: s.translateTargetLanguage,
                tone: s.tone,
                glossary: dictionary.entries.map { $0.term },
                personalFacts: memory.snapshot.personalFacts
            )
            user = TranslationPrompts.user(transcript: raw.text)
        }

        let req = LLMRequest(
            messages: [
                LLMMessage(role: .system, content: system),
                LLMMessage(role: .user, content: user)
            ],
            temperature: 0.2,
            maxTokens: 1024
        )

        let result = try await withTransientRetry(category: .llm, label: mode == .translate ? "translate" : "refine") {
            try await provider.complete(req, model: s.llmModel)
        }
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Retry

    /// Retries the operation on transient URLSession failures (connection
    /// dropped, host unreachable, DNS, timeout). These are normal blips on
    /// macOS — Wi-Fi roams, NAT entries expire, the server closes a
    /// keep-alive connection just before we reuse it. A single failure
    /// shouldn't surface as a user-visible error.
    private func withTransientRetry<T: Sendable>(
        category: LogStore.Category,
        label: String,
        maxAttempts: Int = 3,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                let code = (error as? URLError)?.code
                let transient = code.map(Self.isTransient) ?? false
                if !transient || attempt == maxAttempts {
                    throw error
                }
                let delay = 0.4 * Double(attempt)
                log.warning(category, "Transient network error — retrying \(label)",
                            detail: [
                                "attempt": "\(attempt)/\(maxAttempts)",
                                "error": error.localizedDescription,
                                "next_delay_s": String(format: "%.2f", delay)
                            ])
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? URLError(.unknown)
    }

    private static func isTransient(_ code: URLError.Code) -> Bool {
        switch code {
        case .networkConnectionLost,
             .timedOut,
             .cannotConnectToHost,
             .cannotFindHost,
             .notConnectedToInternet,
             .dnsLookupFailed,
             .resourceUnavailable,
             .internationalRoamingOff,
             .callIsActive,
             .dataNotAllowed,
             .secureConnectionFailed:
            return true
        default:
            return false
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
