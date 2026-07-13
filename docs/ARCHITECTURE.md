# VOCA Architecture

This document is the long-form companion to the **Architecture** section of
[`README.md`](../README.md). It describes how the pieces fit together, the
design choices behind each module, and the invariants that should not be
broken by future refactors.

## Layering

```
┌─────────────────────────────────────────────────────────┐
│  VOCA (macOS app target)                                │
│    AppKit, SwiftUI, NSEvent monitors, status item,      │
│    HUD/Toast windows, Settings panes                    │
└─────────────────────────────────────────────────────────┘
                          ▲
                          │ depends on (one-way)
                          │
┌─────────────────────────────────────────────────────────┐
│  VOCACore (pure-Swift SPM target, no AppKit)            │
│    Pipeline, providers, learning, memory, dictionary,   │
│    settings persistence, logging                        │
└─────────────────────────────────────────────────────────┘
```

**The hard rule:** `VOCACore` cannot import `AppKit`, `SwiftUI`, or anything
that touches windows or the responder chain. This keeps domain logic
unit-testable and forces the UI layer to stay thin.

Practical consequence: things like `NSWorkspace.shared.frontmostApplication`,
`NSPasteboard`, `CGEventTap`, status-bar widgets, and `NSAlert` all live in
the `VOCA` target. `Pipeline`, retry policies, prompt construction, glossary
biasing, and provider clients all live in `VOCACore`.

## The dictation pipeline

A single user tap on Right Option triggers this state machine, orchestrated
by [`VoiceTypeEngine`](../Sources/VOCACore/VoiceTypeEngine.swift):

```
       tap                tap
idle ──────► recording ──────► encoding ──► transcribing ──► refining ──► injecting ──► idle
                              (PCM→WAV)      (STTProvider)   (LLMProvider)  (paste)
                                  │                │              │
                                  └─ failed ─┐  ┌──┘     ┌────────┘
                                             ▼  ▼        ▼
                                           failed(retryable) ──► retry ──► back into pipeline
                                                          │
                                                          └─► cancel ──► idle
```

`ProcessingStage` enumerates these stages and maps each to a 0…1 progress
value, which the HUD shows as a determinate ring.

### Stage details

| Stage | Where | Notes |
|---|---|---|
| Recording | `Audio/AudioRecorder.swift` | `AVAudioEngine` tap into a `Float32` ring buffer. RMS sampled every ~40 ms drives the live waveform. |
| Encoding | `AudioRecorder.encodeWAV()` | In-memory PCM → 16-bit mono WAV. Audio never touches disk. |
| Transcribing | `Transcription/<Provider>.swift` | Provider chosen by `STTProviderFactory.make(id:)`. |
| Refining | `LLM/<Provider>.swift` + `Refinement/Prompts.swift` | Skipped if `llmProvider == .disabled`. |
| Injecting | `VOCA/Injection/TextInjector.swift` | Pasteboard write + synthesised ⌘V via `CGEvent`. |

### Retry semantics

`VoiceTypeEngine.withTransientRetry` wraps both STT and LLM calls with a
small linear backoff. The retry is **only** triggered for transient network
failures (`URLError.networkConnectionLost`, `.timedOut`,
`.cannotFindHost`, etc.) — not for auth, rate-limit, or 4xx errors. Those
surface immediately to the HUD as a `.failed(retryable:)` state. The audio
stays buffered, so the user can tap Retry without re-recording.

## Provider abstraction

STT and LLM both follow the same pattern:

```swift
public protocol STTProvider: Sendable {
    func transcribe(_ req: STTRequest, model: String) async throws -> STTResult
}

public protocol LLMProvider: Sendable {
    func complete(_ req: LLMRequest, model: String) async throws -> LLMResult
}
```

Factories (`STTProviderFactory`, `LLMProviderFactory`) take a provider ID
plus the user's stored credentials and return a configured client. Each
provider:

- Holds **no** mutable state. The same instance is safe to use concurrently.
- Maps every transport / auth / quota failure into a `STTError` / `LLMError`
  case so the engine doesn't care which vendor failed.
- Reads credentials from `ProviderCredentials`, never directly from
  `SettingsStore` — that lets the engine pass a mock credential set in tests.

Adding a provider: see the checklist in
[`CONTRIBUTING.md`](../CONTRIBUTING.md#adding-a-new-stt-or-llm-provider).

## Language handling

Whisper returns `"Chinese"` / `"zh"` without script information, so a naive
pipe-through produces Simplified output for users typing in Traditional.

`VoiceTypeEngine.resolveLanguageHint` resolves the LLM's language hint with
this precedence:

1. The user's explicit `primaryLanguage` (e.g. `zh-Hant`).
2. The STT-detected language, **unless** it's ambiguous Chinese.
3. For ambiguous Chinese, fall back to the UI language preference.

The STT request itself strips the script tag (`zh-Hant` → `zh`), because
Whisper and Deepgram only accept the base ISO-639-1 code. Script enforcement
happens at the LLM-refinement step via `RefinementPrompts.system(...)`.

## Hotkeys and accessibility

`Hotkeys/HotkeyManager.swift` installs a `CGEventTap` at the
`kCGSessionEventTap` level. Two reasons we use an event tap instead of
`NSEvent.addGlobalMonitorForEvents`:

1. Global monitors don't see modifier-only key events (the Right Option key
   alone produces no character).
2. Global monitors can't observe events in apps that mark themselves as
   "secure input" (password fields, terminal sudo prompts) — but neither
   can event taps, so we get to surface a single graceful error path
   instead of two.

The event tap requires **Accessibility** permission. macOS only re-reads
that trust at process start, so granting permission requires a restart.
`Permissions/AccessibilityPermission.swift` polls the trust state and
the UI surfaces a "Restart required" prompt when it flips while the app
is running.

Tap detection uses tap-toggle semantics: a quick press toggles
record/stop, a held press is ignored. The hold threshold is in
`HotkeyManager.holdThreshold`.

## Auto-learn from corrections

If you fix a typo in the pasted text within ~10 seconds, VOCA learns it.
The flow is in `Learning/`:

```
                  ┌─ AXTextReader  ──── reads the focused text element
                  │                     via AXUIElement (a few seconds
                  │                     after injection)
inject text ──────┤
                  └─ CorrectionLearner ─ diffs the injected text vs.
                                         the current AX value (word-level
                                         LCS), adds confidently-changed
                                         tokens to the Dictionary
```

- `CorrectionDiff.swift` is a pure word-level LCS — fully unit-tested.
- The learner only adds tokens that look like proper nouns / capitalised
  unique terms, never common words.
- Every learned addition shows a Toast with one-tap Undo.

## Memory and dictionary

| Store | Backed by | What it does |
|---|---|---|
| `Dictionary/PersonalDictionary` | `dictionary.json` | User-managed glossary. Biases the STT `prompt` *and* appears verbatim in the LLM system prompt. |
| `Memory/PersonalMemory` | `memory.json` | Auto-tracked phrase frequencies + free-form "personal facts" string. Top phrases bias STT; facts go to the LLM. |
| `History/TranscriptHistory` | `history.json` | The N most recent transcripts, viewable in Dashboard. |
| `Logging/LogStore` | `log.jsonl` | One event per pipeline step + per-stage latency. |

All four live under `~/Library/Application Support/VOCA/`. `SupportDirectory`
is the single entry point for that path.

## Logging and redaction

`LogStore` writes a JSON line per event with category, stage, duration_ms,
and a free-form `payload`. Before write, payloads go through a redactor
that masks anything matching common API-key prefixes (`sk-`, `sk-ant-`,
`gsk_`, `AIza`) so a copy-pasted log excerpt from a user bug report
cannot leak their keys.

The redactor's prefix list is intentionally maintained next to provider
implementations — adding a new provider with a new key prefix is part of
the same checklist as adding the provider itself.

## Settings persistence

`SettingsStore` writes `settings.json` atomically on every change. The
`AppSettings` struct is the source of truth — UI panes bind to it via an
`@Observable` store wrapper.

API keys are stored in the macOS Keychain (`Keychain.swift`, generic-password
items keyed by provider), never in `settings.json` — `ProviderCredentials`
encodes to an empty object, and `SettingsStore` migrates any legacy plaintext
keys out of older settings files on first launch. `settings.json` itself sits
under `~/Library/Application Support/VOCA/` with user-only permissions, not in
any cloud-synced location.

The wrapper deliberately uses the legacy (non-data-protection) Keychain:
the data-protection keychain needs a real Apple Team ID or a
keychain-access-groups entitlement, which self-signed builds can't obtain
(launchd rejects it with error 163). The trade-off is a one-time "VOCA wants
to access the keychain" prompt per key on self-signed builds; a Developer ID +
notarised build removes it.

## Concurrency model

VoiceTypeEngine is a `@MainActor` class. Provider implementations are
`Sendable` value types. The audio recorder uses `AVAudioEngine`'s own
queue. Long-running work (`transcribe`, `refine`) is `async` — there is no
manual `Task.detached` or `DispatchQueue.global` anywhere in the engine.

Strict-concurrency warnings should be treated as errors when introducing
new code.

## UI layer (VOCA target)

| Component | File | Responsibility |
|---|---|---|
| `AppDelegate` | `AppDelegate.swift` | Status-bar item, hotkey manager lifetime, top-level engine wiring |
| `DashboardWindow` / `DashboardView` | `DashboardView.swift` | Recent transcripts, settings shortcut, version footer |
| `HUDWindow` / `HUDView` | `HUDView.swift` | Floating capsule: waveform → stage progress → retry on failure |
| `ToastWindow` | `ToastWindow.swift` | "X added to dictionary" with Undo |
| `Settings/*` | `Settings/*.swift` | Seven panes: General, Providers, Languages, Dictionary, Memory, Logs, About |
| `DesignTokens.swift` | — | Single source of truth for colours, type ramps, spacing, radius |

All windows are pinned to `NSAppearance(.aqua)` — VOCA's palette is
designed around the light "Professional Warmth" tokens, and forcing aqua
keeps it legible even when the user has macOS in Dark Mode.

## Build pipeline

The `scripts/` directory:

- `setup-signing.sh` — one-time per machine. Creates a project-local
  keychain at `build/voca-signing.keychain-db` with a self-signed dev
  cert called "VOCA Dev". Persistent state lives **only** inside `build/`;
  it does not touch the login keychain.
- `build-app.sh` — `swift build` → wrap into `dist/VOCA.app` → embed
  `Info.plist` + `.icns` → `codesign --keychain build/voca-signing.keychain-db`
  with hardened runtime entitlements. Modifies the user keychain search
  list **temporarily** during the codesign call (macOS requires it), and
  traps `EXIT`/`INT`/`TERM` to restore the original list afterwards.
- `uninstall-signing.sh` — reverses `setup-signing.sh` and cleans up any
  stale state from pre-2026-05 versions of the script that polluted the
  user-wide search list.
- `make-icon.sh` — `sips` pipeline for converting `logo.png` into the
  multi-resolution `VOCA.icns`.
- `reset-permissions.sh` — `tccutil reset` for the bundle ID, used during
  development when testing permission flows.

The same self-signed cert is used across rebuilds, so TCC remembers
Microphone and Accessibility grants between builds. **First run on
another machine still requires re-granting**, because the cert's identity
hash is generated locally.

## Testing strategy

`Tests/VOCACoreTests` covers the pure-Swift modules: language resolution,
correction diff, redaction, settings round-trip, retry classification.

The intentionally-not-tested parts:

- Provider HTTP clients (we don't mock the vendor APIs in CI; integration
  tests would need real keys)
- AppKit UI (no snapshot testing yet)
- The accessibility text-read path (depends on permission state)

Adding tests for new pure-Swift logic is required in the PR checklist.
