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
        case .groqWhisper: return "whisper-large-v3-turbo"
        case .openaiWhisper: return "whisper-1"
        case .deepgram: return "nova-2"
        case .appleSpeech: return "system"
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
