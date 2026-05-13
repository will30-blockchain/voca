import Foundation

public enum STTProviderID: String, Codable, CaseIterable, Sendable {
    case groqWhisper = "groq-whisper"
    case openaiWhisper = "openai-whisper"
    case deepgram = "deepgram"
    case appleSpeech = "apple-speech"

    public var displayName: String {
        switch self {
        case .groqWhisper: return "Groq Whisper (fast, cheap)"
        case .openaiWhisper: return "OpenAI Whisper"
        case .deepgram: return "Deepgram Nova"
        case .appleSpeech: return "Apple Speech (on-device)"
        }
    }

    public var defaultModel: String {
        switch self {
        case .groqWhisper: return "whisper-large-v3"
        case .openaiWhisper: return "gpt-4o-transcribe"
        case .deepgram: return "nova-3"
        case .appleSpeech: return "system"
        }
    }

    /// Known-good model presets shown in the Providers picker. The user can
    /// still type a custom model name in the text field if they want
    /// something not on this list.
    public var knownModels: [(id: String, label: String)] {
        switch self {
        case .groqWhisper: return [
            ("whisper-large-v3", "Whisper Large v3 — best accuracy, still fast on Groq"),
            ("whisper-large-v3-turbo", "Whisper Large v3 Turbo — faster, slightly less accurate")
        ]
        case .openaiWhisper: return [
            ("gpt-4o-transcribe", "GPT-4o Transcribe — most accurate (recommended)"),
            ("gpt-4o-mini-transcribe", "GPT-4o Mini Transcribe — cheaper, almost as good"),
            ("whisper-1", "Whisper v2 — legacy, cheaper")
        ]
        case .deepgram: return [
            ("nova-3", "Nova 3 — newest, best for English with proper nouns"),
            ("nova-2", "Nova 2 — previous generation")
        ]
        case .appleSpeech: return [("system", "System (on-device)")]
        }
    }
}

public enum LLMProviderID: String, Codable, CaseIterable, Sendable {
    case groq = "groq"
    case openai = "openai"
    case anthropic = "anthropic"
    case disabled = "disabled"

    public var displayName: String {
        switch self {
        case .groq: return "Groq (Llama, fast & cheap)"
        case .openai: return "OpenAI GPT"
        case .anthropic: return "Anthropic Claude"
        case .disabled: return "Disabled (raw transcript)"
        }
    }

    public var defaultModel: String {
        switch self {
        case .groq: return "llama-3.3-70b-versatile"
        case .openai: return "gpt-4o-mini"
        case .anthropic: return "claude-haiku-4-5-20251001"
        case .disabled: return ""
        }
    }

    public var knownModels: [(id: String, label: String)] {
        switch self {
        case .groq: return [
            ("llama-3.3-70b-versatile", "Llama 3.3 70B — recommended"),
            ("llama-3.1-70b-versatile", "Llama 3.1 70B — older fallback"),
            ("mixtral-8x7b-32768", "Mixtral 8x7B — long context")
        ]
        case .openai: return [
            ("gpt-4o-mini", "GPT-4o Mini — fast + cheap"),
            ("gpt-4o", "GPT-4o — most accurate (more expensive)"),
            ("gpt-4.1-mini", "GPT-4.1 Mini")
        ]
        case .anthropic: return [
            ("claude-haiku-4-5-20251001", "Claude Haiku 4.5 — fast"),
            ("claude-sonnet-4-6", "Claude Sonnet 4.6 — best for nuanced rewrites"),
            ("claude-opus-4-7", "Claude Opus 4.7 — most accurate")
        ]
        case .disabled: return []
        }
    }
}

public struct ProviderCredentials: Codable, Sendable, Equatable {
    public var groqAPIKey: String
    public var openaiAPIKey: String
    public var anthropicAPIKey: String
    public var deepgramAPIKey: String

    public init(
        groqAPIKey: String = "",
        openaiAPIKey: String = "",
        anthropicAPIKey: String = "",
        deepgramAPIKey: String = ""
    ) {
        self.groqAPIKey = groqAPIKey
        self.openaiAPIKey = openaiAPIKey
        self.anthropicAPIKey = anthropicAPIKey
        self.deepgramAPIKey = deepgramAPIKey
    }
}

public struct AppSettings: Codable, Sendable, Equatable {
    public var sttProvider: STTProviderID
    public var sttModel: String
    public var llmProvider: LLMProviderID
    public var llmModel: String
    public var credentials: ProviderCredentials

    /// Primary dictation language (BCP-47 or "auto").
    public var primaryLanguage: String
    /// Target language when in translate mode.
    public var translateTargetLanguage: String
    /// Source language for translate mode ("auto" recommended).
    public var translateSourceLanguage: String

    /// Tone hint for LLM refinement.
    public var tone: String
    /// Whether to enable adaptive personal memory learning.
    public var learningEnabled: Bool
    /// Whether the recording HUD should appear.
    public var showHUD: Bool
    /// Inject method.
    public var injectionMethod: InjectionMethod
    /// Whether to play subtle sounds on start/stop.
    public var playSounds: Bool

    public enum InjectionMethod: String, Codable, CaseIterable, Sendable {
        case paste = "paste"
        case typed = "typed"

        public var displayName: String {
            switch self {
            case .paste: return "Paste (⌘V)"
            case .typed: return "Simulated typing"
            }
        }
    }

    public init(
        sttProvider: STTProviderID = .groqWhisper,
        sttModel: String = STTProviderID.groqWhisper.defaultModel,
        llmProvider: LLMProviderID = .groq,
        llmModel: String = LLMProviderID.groq.defaultModel,
        credentials: ProviderCredentials = ProviderCredentials(),
        primaryLanguage: String = "auto",
        translateTargetLanguage: String = "en",
        translateSourceLanguage: String = "auto",
        tone: String = "natural, concise, faithful to the speaker",
        learningEnabled: Bool = true,
        showHUD: Bool = true,
        injectionMethod: InjectionMethod = .paste,
        playSounds: Bool = true
    ) {
        self.sttProvider = sttProvider
        self.sttModel = sttModel
        self.llmProvider = llmProvider
        self.llmModel = llmModel
        self.credentials = credentials
        self.primaryLanguage = primaryLanguage
        self.translateTargetLanguage = translateTargetLanguage
        self.translateSourceLanguage = translateSourceLanguage
        self.tone = tone
        self.learningEnabled = learningEnabled
        self.showHUD = showHUD
        self.injectionMethod = injectionMethod
        self.playSounds = playSounds
    }

    public static let `default` = AppSettings()
}

public enum SupportedLanguage: String, CaseIterable, Sendable {
    case auto
    case en
    case zh
    case ja
    case ko
    case es
    case fr
    case de
    case it
    case pt
    case ru
    case vi
    case th
    case id

    public var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .en: return "English"
        case .zh: return "中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .pt: return "Português"
        case .ru: return "Русский"
        case .vi: return "Tiếng Việt"
        case .th: return "ไทย"
        case .id: return "Bahasa Indonesia"
        }
    }
}
