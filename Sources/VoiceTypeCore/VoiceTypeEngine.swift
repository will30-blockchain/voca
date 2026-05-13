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
        urlSession: URLSession = .shared
    ) {
        self.settingsStore = settingsStore
        self.memory = memory
        self.dictionary = dictionary
        self.recorder = recorder
        self.injector = injector
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
        } catch {
            state = .error(message: error.localizedDescription)
            AppLog.engine.error("recorder.start failed: \(String(describing: error), privacy: .public)")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            state = .idle
        }
    }

    public func endRecording() async {
        guard case .recording(let mode) = state else { return }
        do {
            state = .processing(mode: mode, stage: "Encoding…")
            let recording = try await recorder.stop()
            if recording.audio.isEmpty || recording.duration < 0.25 {
                state = .idle
                AppLog.engine.info("Recording too short, ignoring.")
                return
            }

            // Skip the API call on completely silent recordings to save the
            // round-trip and avoid the classic "Thank you" hallucination.
            // Threshold is very low (0.004) so real-but-quiet speech still
            // makes it through — see HallucinationFilter for the rationale.
            if recording.peakLevel < HallucinationFilter.silenceThreshold {
                AppLog.engine.info("Silent recording (peak=\(recording.peakLevel, format: .fixed(precision: 4))), skipping transcribe.")
                state = .idle
                return
            }

            state = .processing(mode: mode, stage: "Transcribing…")
            let raw = try await transcribe(recording)

            // Final guard: drop only if the transcript is an exact known
            // Whisper outro AND the audio was effectively silent. Everything
            // else — including short answers like "OK" or "好" — passes.
            switch HallucinationFilter.decide(transcript: raw.text, peakLevel: recording.peakLevel) {
            case .drop(let reason):
                AppLog.engine.info("Dropped transcript — \(reason, privacy: .public)")
                state = .idle
                return
            case .keep:
                break
            }

            state = .processing(mode: mode, stage: mode == .translate ? "Translating…" : "Refining…")
            let finalText = try await refine(raw: raw, mode: mode)

            state = .processing(mode: mode, stage: "Injecting…")
            try await injector.inject(finalText, method: settingsStore.settings.injectionMethod)

            if settingsStore.settings.learningEnabled {
                memory.ingest(transcript: finalText)
            }
            history.append(mode: mode, text: finalText)

            state = .idle
        } catch {
            AppLog.engine.error("pipeline failed: \(String(describing: error), privacy: .public)")
            state = .error(message: error.localizedDescription)
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            state = .idle
        }
    }

    public func cancelRecording() async {
        if case .recording = state {
            _ = try? await recorder.stop()
            state = .idle
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
