import Foundation

/// User-selectable UI language. `.system` means "match the macOS language
/// at app launch"; explicit picks override the system. Persisted via
/// AppSettings.uiLanguage.
public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system
    case english = "en"
    case traditionalChinese = "zh-Hant"

    public var displayName: String {
        switch self {
        case .system: return "Follow system / 跟隨系統"
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        }
    }

    /// Resolves `.system` to a concrete language using macOS locale.
    public var effective: AppLanguage {
        if self != .system { return self }
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        if code.lowercased().hasPrefix("zh") { return .traditionalChinese }
        return .english
    }
}

/// All user-facing strings. One enum case per logical key; the en/zhHant
/// translations live below. Add a case here when introducing new UI text,
/// then look it up via `store.t(.someKey)` so the view re-renders when the
/// user flips the language picker.
public enum L10n: String, CaseIterable, Sendable {
    // MARK: - App-wide
    case appName
    case appTagline

    // MARK: - Dashboard
    case dashboardSettings
    case dashboardDictionary
    case dashboardMemory

    case statusReady
    case statusListening
    case statusListeningTranslate
    case statusError
    case statusReadyHint
    case statusListeningHint
    case statusListeningTranslateHint
    case statusProcessingHint

    case actionStartDictation
    case actionStopAndPaste
    case actionCancel
    case actionWorking
    case actionRetry
    case actionDismiss
    case actionUndo
    case actionClear
    case actionCopy

    case hotkeysTitle
    case hotkeyDictateTitle
    case hotkeyDictateDescription
    case hotkeyTranslateTitle
    case hotkeyTranslateDescription
    case hotkeysAccentNote

    case recentTitle
    case recentEmpty
    case recentEmptyTitle
    case recentTotalDictations
    case recentDictateLabel
    case recentTranslateLabel

    case setupTitle
    case setupBody
    case setupOpenProviders
    case setupUseAppleSpeech

    case permissionsCardTitle
    case permissionsCardFooter
    case permAccessibilityTitle
    case permAccessibilityBody
    case permAccessibilityAction
    case permMicTitle
    case permMicBody
    case permMicRequest
    case permMicOpenSettings

    // MARK: - HUD pill
    case hudCouldNotTranscribe

    // MARK: - Toast
    case toastAddedToDictionary

    // MARK: - Settings shell
    case settingsWindowTitle
    case tabGeneral
    case tabProviders
    case tabLanguages
    case tabDictionary
    case tabMemory
    case tabLogs
    case tabAbout

    // MARK: - General settings
    case generalSubtitle
    case generalAppearanceSection
    case generalAppearanceLanguageTitle
    case generalAppearanceLanguageHint
    case generalBehaviorSection
    case generalShowHUDTitle
    case generalShowHUDHint
    case generalAdaptiveMemoryTitle
    case generalAdaptiveMemoryHint
    case generalLearnCorrectionsTitle
    case generalLearnCorrectionsHint
    case generalPlaySoundsTitle
    case generalPlaySoundsHint
    case generalInjectionTitle
    case generalInjectionHint
    case generalInjectionPaste
    case generalInjectionTyped
    case generalHotkeysSection
    case generalHotkeysNote
    case generalToneSection
    case generalToneTitle
    case generalToneFooter
    case generalPermissionsSection
    case generalPermissionsBody
    case generalOpenMicSettings
    case generalOpenAccessibilitySettings

    // MARK: - Providers settings
    case providersSubtitle
    case providersTranscriptionSection
    case providersLLMSection
    case providersKeysSection
    case providersProviderLabel
    case providersModelLabel
    case providersModelHint
    case providersLLMHint
    case providersKeysFooter
    case providersShow
    case providersHide

    // MARK: - Languages settings
    case languagesSubtitle
    case languagesPrimarySection
    case languagesPrimaryLabel
    case languagesPrimaryHint
    case languagesTranslateSection
    case languagesSourceLabel
    case languagesTargetLabel
    case languagesTranslateHint

    // MARK: - Dictionary settings
    case dictionarySubtitle
    case dictionaryAddSection
    case dictionaryTermLabel
    case dictionaryTermPlaceholder
    case dictionaryNoteLabel
    case dictionaryNotePlaceholder
    case dictionaryAdd
    case dictionaryEntriesSection
    case dictionaryColTerm
    case dictionaryColNote
    case dictionaryRemoveSelected

    // MARK: - Memory settings
    case memorySubtitle
    case memoryFactsSection
    case memoryFactsDisclosure
    case memoryFactsFooter
    case memoryLearnedSection
    case memoryLearnedHint
    case memoryLearnedEmpty
    case memoryFooterTotal
    case memoryReset

    // MARK: - Logs settings
    case logsSubtitle
    case logsLevel
    case logsCategory
    case logsRecent
    case logsEmpty
    case logsCopyAll
    case logsReveal

    // MARK: - About
    case aboutSubtitle
    case aboutDefaultsSection
    case aboutTranscription
    case aboutTranscriptionDetail
    case aboutRefinement
    case aboutRefinementDetail
    case aboutOffline
    case aboutOfflineDetail
    case aboutStorageSection
    case aboutStorageFooter

    public func text(_ language: AppLanguage) -> String {
        let effective = language.effective
        switch effective {
        case .english: return Self.en[self] ?? rawValue
        case .traditionalChinese: return Self.zhHant[self] ?? Self.en[self] ?? rawValue
        case .system: return Self.en[self] ?? rawValue
        }
    }

    // MARK: - English

    private static let en: [L10n: String] = [
        .appName: "VOCA",
        .appTagline: "Dictation and translation, on your own keys.",

        .dashboardSettings: "Settings",
        .dashboardDictionary: "Dictionary",
        .dashboardMemory: "Memory",

        .statusReady: "Ready",
        .statusListening: "Listening",
        .statusListeningTranslate: "Listening · Translate",
        .statusError: "Error",
        .statusReadyHint: "Tap Right Option to start dictation. Tap again to stop and paste.",
        .statusListeningHint: "Tap Right Option again — or press Return — to stop and paste.",
        .statusListeningTranslateHint: "Translating to your target language. Tap Right Option to stop.",
        .statusProcessingHint: "Working through the pipeline — hang tight.",

        .actionStartDictation: "Start dictation",
        .actionStopAndPaste: "Stop & paste",
        .actionCancel: "Cancel",
        .actionWorking: "Working…",
        .actionRetry: "Retry",
        .actionDismiss: "Dismiss",
        .actionUndo: "Undo",
        .actionClear: "Clear",
        .actionCopy: "Copy",

        .hotkeysTitle: "Hotkeys",
        .hotkeyDictateTitle: "Dictate",
        .hotkeyDictateDescription: "Tap once to start, tap again to stop and paste.",
        .hotkeyTranslateTitle: "Translate",
        .hotkeyTranslateDescription: "Hold Right Shift while tapping Right Option. Tap Right Option again to stop.",
        .hotkeysAccentNote: "Right Option held continuously (longer than 0.5 s) still works for accent input — Option+E for é, etc.",

        .recentTitle: "Recent dictations",
        .recentEmpty: "Your last dictations will appear here once you've spoken into the meter.",
        .recentEmptyTitle: "Nothing yet",
        .recentTotalDictations: "Total dictations:",
        .recentDictateLabel: "Dictate",
        .recentTranslateLabel: "Translate",

        .setupTitle: "Add an API key to start dictating",
        .setupBody: "VOCA runs on your own API keys. The cheapest fast path is Groq — one key powers both the Whisper transcription and the LLM editor.",
        .setupOpenProviders: "Open Providers",
        .setupUseAppleSpeech: "Use Apple Speech instead",

        .permissionsCardTitle: "Finish setup",
        .permissionsCardFooter: "After enabling a permission, quit VOCA (⌘Q) and relaunch — macOS only refreshes Accessibility trust on launch.",
        .permAccessibilityTitle: "Accessibility",
        .permAccessibilityBody: "Lets the Right Option hotkey work in any app and lets VOCA paste at your cursor.",
        .permAccessibilityAction: "Open Accessibility",
        .permMicTitle: "Microphone",
        .permMicBody: "Captures your speech. If VOCA doesn't appear in System Settings, click Request below.",
        .permMicRequest: "Request",
        .permMicOpenSettings: "Open settings",

        .hudCouldNotTranscribe: "Couldn't transcribe",

        .toastAddedToDictionary: "added to dictionary",

        .settingsWindowTitle: "VOCA Settings",
        .tabGeneral: "General",
        .tabProviders: "Providers",
        .tabLanguages: "Languages",
        .tabDictionary: "Dictionary",
        .tabMemory: "Memory",
        .tabLogs: "Logs",
        .tabAbout: "About",

        .generalSubtitle: "Behavior, hotkeys, and the macOS permissions VOCA needs to run.",
        .generalAppearanceSection: "Appearance",
        .generalAppearanceLanguageTitle: "Interface language",
        .generalAppearanceLanguageHint: "Changes apply immediately — no restart needed.",
        .generalBehaviorSection: "Behavior",
        .generalShowHUDTitle: "Show recording HUD",
        .generalShowHUDHint: "A small overlay near the menu bar while you dictate.",
        .generalAdaptiveMemoryTitle: "Adaptive personal memory",
        .generalAdaptiveMemoryHint: "Learn recurring names and phrases to improve future transcripts.",
        .generalLearnCorrectionsTitle: "Learn from corrections",
        .generalLearnCorrectionsHint: "When you fix a typo right after dictation, VOCA notices and adds the new word (proper nouns, acronyms, names) to your Dictionary automatically.",
        .generalPlaySoundsTitle: "Play subtle sounds",
        .generalPlaySoundsHint: "A soft tone on start and stop. Off if you record over calls.",
        .generalInjectionTitle: "Injection method",
        .generalInjectionHint: "Paste is fastest and most reliable. Use simulated typing for apps that block paste.",
        .generalInjectionPaste: "Paste (⌘V)",
        .generalInjectionTyped: "Simulated typing",
        .generalHotkeysSection: "Hotkeys",
        .generalHotkeysNote: "Hotkeys are fixed in v1. Both modes require Accessibility permission.",
        .generalToneSection: "Refinement tone",
        .generalToneTitle: "Tone hint",
        .generalToneFooter: "Passed to the LLM refiner as style guidance. Plain English is fine.",
        .generalPermissionsSection: "System permissions",
        .generalPermissionsBody: "VOCA needs microphone access to listen and Accessibility access to paste into the focused app.",
        .generalOpenMicSettings: "Open Microphone settings",
        .generalOpenAccessibilitySettings: "Open Accessibility settings",

        .providersSubtitle: "Pick the models that power transcription and refinement. Groq runs Whisper-large at a fraction of OpenAI's price.",
        .providersTranscriptionSection: "Transcription",
        .providersLLMSection: "LLM refinement",
        .providersKeysSection: "API keys",
        .providersProviderLabel: "Provider",
        .providersModelLabel: "Model",
        .providersModelHint: "Pick a preset or type a custom model name for newly released models.",
        .providersLLMHint: "Refinement cleans punctuation and disfluencies. Disable to paste the raw transcript.",
        .providersKeysFooter: "Keys are stored in the macOS Keychain (com.voca.api-key.*). The settings JSON never contains key material.",
        .providersShow: "Show",
        .providersHide: "Hide",

        .languagesSubtitle: "Set your dictation language and the source-target pair used in translate mode.",
        .languagesPrimarySection: "Primary dictation",
        .languagesPrimaryLabel: "Language",
        .languagesPrimaryHint: "Auto-detect mixes Chinese and English smoothly. Pin a language if your accent confuses Whisper.",
        .languagesTranslateSection: "Translate mode",
        .languagesSourceLabel: "Source",
        .languagesTargetLabel: "Target",
        .languagesTranslateHint: "Hold Right Option + Right Shift to dictate in the source language and paste the translated result in the target language.",

        .dictionarySubtitle: "Names, acronyms, and jargon you say often. VOCA passes these to both the transcription model and the LLM editor so spelling stays consistent.",
        .dictionaryAddSection: "Add a term",
        .dictionaryTermLabel: "Term",
        .dictionaryTermPlaceholder: "e.g. Anthropic, MLX, Will",
        .dictionaryNoteLabel: "Note",
        .dictionaryNotePlaceholder: "Optional context",
        .dictionaryAdd: "Add",
        .dictionaryEntriesSection: "Entries",
        .dictionaryColTerm: "Term",
        .dictionaryColNote: "Note",
        .dictionaryRemoveSelected: "Remove selected",

        .memorySubtitle: "Background context VOCA appends to the LLM editor. The more specific the better — name, role, projects, recurring people.",
        .memoryFactsSection: "Personal facts",
        .memoryFactsDisclosure: "These facts are sent to your selected LLM provider on every dictation. Don't include passwords, SSNs, medical IDs, or anything you wouldn't share with that vendor.",
        .memoryFactsFooter: "Free-form. Saved as you type. Max 2,000 characters.",
        .memoryLearnedSection: "Auto-learned phrases",
        .memoryLearnedHint: "Phrases you've spoken more than once. VOCA uses them as transcription hints.",
        .memoryLearnedEmpty: "No learned phrases yet — they appear after a few dictations.",
        .memoryFooterTotal: "Total dictations",
        .memoryReset: "Reset memory",

        .logsSubtitle: "Every step the engine takes, persisted to ~/Library/Application Support/VOCA/log.jsonl. Use this to see why a take dropped or which provider failed.",
        .logsLevel: "Level",
        .logsCategory: "Category",
        .logsRecent: "Recent activity",
        .logsEmpty: "Nothing matches the current filter.",
        .logsCopyAll: "Copy all",
        .logsReveal: "Reveal in Finder",

        .aboutSubtitle: "A native macOS dictation and translation tool that runs on your own API keys.",
        .aboutDefaultsSection: "Defaults",
        .aboutTranscription: "Transcription",
        .aboutTranscriptionDetail: "Groq Whisper — fast and inexpensive.",
        .aboutRefinement: "Refinement",
        .aboutRefinementDetail: "Groq Llama 3.3 70B — quick rewrites in your tone.",
        .aboutOffline: "Offline fallback",
        .aboutOfflineDetail: "Apple Speech runs entirely on-device when no API key is set.",
        .aboutStorageSection: "Storage",
        .aboutStorageFooter: "Settings, dictionary, and personal memory are persisted as JSON."
    ]

    // MARK: - 繁體中文

    private static let zhHant: [L10n: String] = [
        .appName: "VOCA",
        .appTagline: "在你自己的 API key 上跑的語音轉錄與翻譯。",

        .dashboardSettings: "設定",
        .dashboardDictionary: "字典",
        .dashboardMemory: "記憶",

        .statusReady: "待命中",
        .statusListening: "聆聽中",
        .statusListeningTranslate: "聆聽中 · 翻譯",
        .statusError: "錯誤",
        .statusReadyHint: "點一下 Right Option 開始錄音,再點一下停止並貼上。",
        .statusListeningHint: "再點一下 Right Option(或按 Return)停止並貼上。",
        .statusListeningTranslateHint: "正在翻譯到你指定的目標語言。點 Right Option 停止。",
        .statusProcessingHint: "處理中,請稍候。",

        .actionStartDictation: "開始錄音",
        .actionStopAndPaste: "停止並貼上",
        .actionCancel: "取消",
        .actionWorking: "處理中…",
        .actionRetry: "重試",
        .actionDismiss: "關閉",
        .actionUndo: "復原",
        .actionClear: "清除",
        .actionCopy: "複製",

        .hotkeysTitle: "快捷鍵",
        .hotkeyDictateTitle: "錄音",
        .hotkeyDictateDescription: "點一下開始,再點一下停止並貼上。",
        .hotkeyTranslateTitle: "翻譯",
        .hotkeyTranslateDescription: "按住 Right Shift 的同時點 Right Option。再點 Right Option 停止。",
        .hotkeysAccentNote: "按住 Right Option 超過 0.5 秒不會觸發 — 輸入重音字元(Option+E → é)等照常運作。",

        .recentTitle: "最近的轉錄",
        .recentEmpty: "你最近的錄音會顯示在這裡。",
        .recentEmptyTitle: "目前沒有紀錄",
        .recentTotalDictations: "累計轉錄次數:",
        .recentDictateLabel: "錄音",
        .recentTranslateLabel: "翻譯",

        .setupTitle: "加入 API key 才能開始錄音",
        .setupBody: "VOCA 用你自己的 API key 運作。最便宜又快的選擇是 Groq — 一支 key 同時提供 Whisper 轉錄跟 LLM 修飾。",
        .setupOpenProviders: "前往 Providers",
        .setupUseAppleSpeech: "改用 Apple Speech",

        .permissionsCardTitle: "完成設定",
        .permissionsCardFooter: "授權後請 ⌘Q 退出 VOCA 再重開 — macOS 只在啟動時讀取新的 Accessibility 信任狀態。",
        .permAccessibilityTitle: "輔助使用 (Accessibility)",
        .permAccessibilityBody: "讓 Right Option 全域快捷鍵在任何 app 都能用、並讓 VOCA 把文字貼到你的游標位置。",
        .permAccessibilityAction: "打開輔助使用設定",
        .permMicTitle: "麥克風",
        .permMicBody: "用來收音。如果 VOCA 沒出現在系統設定的麥克風清單,點下方「請求」。",
        .permMicRequest: "請求",
        .permMicOpenSettings: "打開設定",

        .hudCouldNotTranscribe: "轉錄失敗",

        .toastAddedToDictionary: "已加入字典",

        .settingsWindowTitle: "VOCA 設定",
        .tabGeneral: "一般",
        .tabProviders: "供應商",
        .tabLanguages: "語言",
        .tabDictionary: "字典",
        .tabMemory: "記憶",
        .tabLogs: "日誌",
        .tabAbout: "關於",

        .generalSubtitle: "行為、快捷鍵,以及 VOCA 需要的 macOS 權限。",
        .generalAppearanceSection: "外觀",
        .generalAppearanceLanguageTitle: "介面語言",
        .generalAppearanceLanguageHint: "切換後立即生效,不需重開 app。",
        .generalBehaviorSection: "行為",
        .generalShowHUDTitle: "顯示錄音 HUD",
        .generalShowHUDHint: "錄音時在螢幕底部浮現一個小膠囊。",
        .generalAdaptiveMemoryTitle: "自適應個人記憶",
        .generalAdaptiveMemoryHint: "學習你常講的名字與詞彙,讓往後的轉錄更精準。",
        .generalLearnCorrectionsTitle: "從修正中學習",
        .generalLearnCorrectionsHint: "當你在貼上後立刻修改字詞,VOCA 會偵測新的專有名詞/縮寫並自動加入字典。",
        .generalPlaySoundsTitle: "播放提示音",
        .generalPlaySoundsHint: "開始與結束時播放輕柔的鐘聲。如果你常邊通話邊錄音可關掉。",
        .generalInjectionTitle: "文字注入方式",
        .generalInjectionHint: "貼上最快、最穩定。某些 app 會擋貼上,這時改用模擬輸入。",
        .generalInjectionPaste: "貼上 (⌘V)",
        .generalInjectionTyped: "模擬輸入",
        .generalHotkeysSection: "快捷鍵",
        .generalHotkeysNote: "v1 的快捷鍵固定。兩個模式都需要輔助使用權限。",
        .generalToneSection: "修飾語氣",
        .generalToneTitle: "語氣提示",
        .generalToneFooter: "會以系統提示的方式傳給 LLM 作為風格引導。寫白話文即可。",
        .generalPermissionsSection: "系統權限",
        .generalPermissionsBody: "VOCA 需要麥克風權限收音,以及輔助使用權限把文字貼進目前的 app。",
        .generalOpenMicSettings: "開啟麥克風設定",
        .generalOpenAccessibilitySettings: "開啟輔助使用設定",

        .providersSubtitle: "選擇驅動轉錄與修飾的模型。Groq 跑 Whisper-large 比 OpenAI 便宜許多。",
        .providersTranscriptionSection: "轉錄",
        .providersLLMSection: "LLM 修飾",
        .providersKeysSection: "API 金鑰",
        .providersProviderLabel: "供應商",
        .providersModelLabel: "模型",
        .providersModelHint: "選一個預設模型,或對新發表的模型直接輸入名稱。",
        .providersLLMHint: "修飾會清掉贅字並補上標點。停用會直接貼上原始轉錄。",
        .providersKeysFooter: "金鑰存在 macOS 鑰匙圈 (com.voca.api-key.*),設定 JSON 不會包含任何金鑰內容。",
        .providersShow: "顯示",
        .providersHide: "隱藏",

        .languagesSubtitle: "設定錄音語言、以及翻譯模式的來源/目標語言。",
        .languagesPrimarySection: "主要錄音語言",
        .languagesPrimaryLabel: "語言",
        .languagesPrimaryHint: "「自動偵測」對中英混講最順。如果你的口音常讓 Whisper 誤判,就指定一個固定語言。",
        .languagesTranslateSection: "翻譯模式",
        .languagesSourceLabel: "來源",
        .languagesTargetLabel: "目標",
        .languagesTranslateHint: "按住 Right Option + Right Shift 用來源語言錄音,結果會以目標語言貼出。",

        .dictionarySubtitle: "你常講的人名、縮寫、專有名詞。VOCA 會把這些一併送給 STT 模型與 LLM 編輯器,維持拼字一致。",
        .dictionaryAddSection: "加入新詞",
        .dictionaryTermLabel: "詞彙",
        .dictionaryTermPlaceholder: "例如 Anthropic、MLX、Will",
        .dictionaryNoteLabel: "註記",
        .dictionaryNotePlaceholder: "選填的上下文",
        .dictionaryAdd: "加入",
        .dictionaryEntriesSection: "已加入的詞彙",
        .dictionaryColTerm: "詞彙",
        .dictionaryColNote: "註記",
        .dictionaryRemoveSelected: "移除選取",

        .memorySubtitle: "VOCA 會把這些背景資訊附加給 LLM 編輯器,越具體越好 — 名字、角色、進行中的專案、常出現的人。",
        .memoryFactsSection: "個人資料",
        .memoryFactsDisclosure: "這欄的內容會在每次轉錄時跟著送給你選的 LLM 供應商。不要寫密碼、身分證號、健保卡號或不想分享給那家廠商的資訊。",
        .memoryFactsFooter: "自由填寫,輸入時即時儲存。上限 2,000 字。",
        .memoryLearnedSection: "自動學到的詞",
        .memoryLearnedHint: "你講過兩次以上的詞,VOCA 會在轉錄時用來提示。",
        .memoryLearnedEmpty: "目前還沒學到任何詞 — 多錄幾次就會出現。",
        .memoryFooterTotal: "累計轉錄次數",
        .memoryReset: "重設記憶",

        .logsSubtitle: "VOCA 引擎每一步的紀錄,存在 ~/Library/Application Support/VOCA/log.jsonl。可以看是哪一步被丟掉、或是哪家供應商失敗。",
        .logsLevel: "等級",
        .logsCategory: "類別",
        .logsRecent: "近期活動",
        .logsEmpty: "目前的篩選沒有符合的紀錄。",
        .logsCopyAll: "全部複製",
        .logsReveal: "在 Finder 顯示",

        .aboutSubtitle: "原生 macOS 語音轉錄與翻譯工具,用你自己的 API key 跑。",
        .aboutDefaultsSection: "預設",
        .aboutTranscription: "轉錄",
        .aboutTranscriptionDetail: "Groq Whisper — 又快又便宜。",
        .aboutRefinement: "修飾",
        .aboutRefinementDetail: "Groq Llama 3.3 70B — 快速修改文字並符合你的語氣。",
        .aboutOffline: "離線備援",
        .aboutOfflineDetail: "沒設定任何 API key 時可改用 Apple Speech,完全在裝置本機跑。",
        .aboutStorageSection: "資料儲存",
        .aboutStorageFooter: "設定、字典、個人記憶都以 JSON 儲存在本機。"
    ]
}
