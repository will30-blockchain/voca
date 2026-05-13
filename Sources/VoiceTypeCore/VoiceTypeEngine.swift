import Foundation
import Combine

public enum DictationMode: Sendable, Equatable {
    case transcribe
    case translate
}

public enum EngineState: Sendable, Equatable {
    case idle
    case recording(mode: DictationMode)
    case processing(mode: DictationMode, stage: String)
    case error(message: String)
}

@MainActor
public final class VoiceTypeEngine: ObservableObject {
    @Published public private(set) var state: EngineState = .idle

    public let history: TranscriptHistory
    public let recorder: AudioRecorder
    public let log: LogStore

    private let settingsStore: SettingsStore
    private let memory: PersonalMemory
    private let dictionary: UserDictionary
    private let injector: TextInjector
    private let urlSession: URLSession

    public init(
        settingsStore: SettingsStore,
        memory: PersonalMemory,
        dictionary: UserDictionary,
        recorder: AudioRecorder,
        injector: TextInjector,
        log: LogStore,
        urlSession: URLSession = .shared
    ) {
        self.settingsStore = settingsStore
        self.memory = memory
        self.dictionary = dictionary
        self.recorder = recorder
        self.injector = injector
        self.log = log
        self.urlSession = urlSession
        self.history = TranscriptHistory()
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
        do {
            try await recorder.start()
            state = .recording(mode: mode)
            log.info(.engine, "Recording started", detail: ["mode": mode == .translate ? "translate" : "transcribe"])
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
        let startedAt = Date()
        do {
            state = .processing(mode: mode, stage: "Encoding…")
            let recording = try await recorder.stop()
            let peakStr = String(format: "%.4f", recording.peakLevel)
            let durStr = String(format: "%.2f", recording.duration)
            log.info(.audio, "Recording captured",
                     detail: ["duration_s": durStr, "peak": peakStr, "bytes": "\(recording.audio.count)"])

            if recording.audio.isEmpty || recording.duration < 0.25 {
                state = .idle
                log.info(.engine, "Take too short — ignored", detail: ["duration_s": durStr])
                return
            }

            // Skip the API call on completely silent recordings.
            if recording.peakLevel < HallucinationFilter.silenceThreshold {
                state = .idle
                log.info(.filter, "Silent recording — skipped transcribe",
                         detail: ["peak": peakStr, "threshold": "\(HallucinationFilter.silenceThreshold)"])
                return
            }

            state = .processing(mode: mode, stage: "Transcribing…")
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
                log.info(.filter, "Transcript dropped",
                         detail: ["reason": reason, "text": String(raw.text.prefix(120))])
                return
            case .keep:
                break
            }

            state = .processing(mode: mode, stage: mode == .translate ? "Translating…" : "Refining…")
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

            state = .processing(mode: mode, stage: "Injecting…")
            try await injector.inject(finalText, method: settingsStore.settings.injectionMethod)
            log.info(.inject, "Injected text",
                     detail: ["chars": "\(finalText.count)", "method": settingsStore.settings.injectionMethod.rawValue])

            if settingsStore.settings.learningEnabled {
                memory.ingest(transcript: finalText)
            }
            history.append(mode: mode, text: finalText)

            let total = String(format: "%.2f", Date().timeIntervalSince(startedAt))
            log.info(.engine, "Pipeline complete", detail: ["total_s": total])

            state = .idle
        } catch {
            AppLog.engine.error("pipeline failed: \(String(describing: error), privacy: .public)")
            log.error(.engine, "Pipeline failed",
                      detail: [
                        "error": error.localizedDescription,
                        "type": String(describing: type(of: error))
                      ])
            state = .error(message: error.localizedDescription)
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            state = .idle
        }
    }

    public func cancelRecording() async {
        if case .recording = state {
            _ = try? await recorder.stop()
            state = .idle
            log.info(.engine, "Recording cancelled")
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
        return try await provider.transcribe(req, model: s.sttModel)
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

        let result = try await provider.complete(req, model: s.llmModel)
        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
