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

    private let settingsStore: SettingsStore
    private let memory: PersonalMemory
    private let dictionary: UserDictionary
    private let recorder: AudioRecorder
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
    }

    // MARK: - Recording control

    public func beginRecording(mode: DictationMode) async {
        guard case .idle = state else { return }
        do {
            try await recorder.start()
            state = .recording(mode: mode)
        } catch {
            state = .error(message: error.localizedDescription)
            AppLog.engine.error("recorder.start failed: \(String(describing: error), privacy: .public)")
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

            state = .processing(mode: mode, stage: "Transcribing…")
            let raw = try await transcribe(recording)

            state = .processing(mode: mode, stage: mode == .translate ? "Translating…" : "Refining…")
            let finalText = try await refine(raw: raw, mode: mode)

            state = .processing(mode: mode, stage: "Injecting…")
            try await injector.inject(finalText, method: settingsStore.settings.injectionMethod)

            if settingsStore.settings.learningEnabled {
                memory.ingest(transcript: finalText)
            }

            state = .idle
        } catch {
            AppLog.engine.error("pipeline failed: \(String(describing: error), privacy: .public)")
            state = .error(message: error.localizedDescription)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
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
