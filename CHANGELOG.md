# Changelog

All notable changes to VOCA AI Typer are documented here. Format inspired by
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Auto-learn visibility (was practically invisible before)

- **Edit-time trigger (new)** — `CorrectionLearner` now starts a polling
  task right after each paste that re-reads the focused AX element at
  1 Hz. When the user stops typing for ~3 s and the text differs from
  what VOCA pasted, the review fires *immediately* so the toast appears
  in real time, not on the next dictation. Polls for up to 60 s, then
  gives up; the previous "review on next dictation" path is still active
  as a safety net.
- **Bottom-center toast (was top-right)** — when an edit triggers an
  auto-learn, the "X added to dictionary" strip now appears bottom-centre
  and stays for **12 seconds** (was 5). The previous placement was easy
  to miss when the user was looking at the field they just edited.
- **Dashboard → "Recently learned" card** — surfaces
  `CorrectionLearner.recent` as a scrollable list of recently auto-added
  terms. Each row has a one-click remove that also deletes the matching
  dictionary entry. Empty state explains the edit-then-redictate flow.
- **Dictionary settings → source filter** — segmented control "All /
  Auto / Manual" so the user can review only the terms VOCA learned on
  its own. New `Source` column shows a `sparkles` icon for auto-learned
  rows and a `pencil` for manual rows (mirrors Typeless's auto/manual
  distinction).
- `UserDictionary.Entry` gains a `source: Origin` field
  (`manual` / `autoLearned`). Backward-compatible decoder infers the
  source from legacy entries' note prefix.
- `CorrectionLearner.remove(id:)` deletes a learned entry *and* the
  paired dictionary row so removing from one place actually stops the
  term from biasing future dictations.

### Added

- `SECURITY.md` — vulnerability disclosure policy, in-scope vs out-of-scope
  list, response SLA.
- `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1.
- `.github/PULL_REQUEST_TEMPLATE.md` — matches the checklist in
  `CONTRIBUTING.md`.
- `docs/ARCHITECTURE.md` — long-form companion to README's architecture
  section: layering rules, pipeline state machine, provider abstraction,
  language resolution, hotkey + AX model, auto-learn flow, logging
  redaction, build pipeline notes.
- README: dedicated **First launch — bypassing Gatekeeper** section with
  step-by-step instructions for the right-click → Open dance, an
  `xattr -dr com.apple.quarantine` fallback for the "App is damaged"
  case, a **Distribution status** table, and a **Threat model** section
  describing what's in / out of scope.
- README: **Acknowledgments** crediting Claude Code as the
  pair-programming collaborator and the SuperCard design system /
  Typeless as inspirations.
- Defensive `.gitignore` patterns for `.env*`, `*.p12`, `*.cer`, `*.pem`,
  `*.key`, `*.keychain*`, `settings.json`, `log.jsonl`, `secrets/` so a
  stray real credentials file cannot be committed by accident.

### Changed

- Replaced placeholder `your-org/voca-ai-typer` with the real repo
  `will30-blockchain/voca` across README and CONTRIBUTING.

## [0.1.0] — 2026-05-15

Initial public release. Renamed from internal "VoiceType" → **VOCA**.

### Added

- Tap-toggle global hotkeys (Right Option / Right Option + Right Shift).
- STT providers: Groq Whisper, OpenAI Whisper, Deepgram Nova, Apple Speech.
- LLM providers: Groq Llama, OpenAI GPT, Anthropic Claude. "Disabled" mode
  pastes the raw transcript.
- Personal dictionary that biases both STT and LLM editor.
- Auto-learn from typo corrections via AX read-back of the focused text
  element + word-level LCS diff.
- Adaptive personal memory tracks proper-noun-like phrases you say often.
- Free-form personal facts injected as LLM system-prompt context.
- Translate mode (source → target language, configurable per-pair).
- Live RMS waveform meter in HUD and Dashboard.
- Determinate pipeline progress bar (encoding / transcribing / refining /
  translating / injecting).
- HUD retry button on transient pipeline failures — audio stays buffered.
- ESC anywhere cancels an in-progress recording.
- Whisper hallucination filter (drops "Thank you" / 謝謝觀看 on silent audio).
- Transient-network auto-retry with linear backoff for both STT and LLM.
- Structured event log persisted to `log.jsonl`, browsable in Settings → Logs.
- Toast notification when a new term is auto-added to the dictionary.
- Subtle Glass chime on recording start/stop (toggleable).

### Visual

- SuperCard "Professional Warmth" design language — warm-white surfaces,
  brand orange (#ea580c) accent, SF Pro at minimum 12pt for readability.
- Pinned to NSAppearance(.aqua) so the light palette works for users
  running macOS in Dark Mode.
- Custom 1024px app icon generated for the connected wave + caret mark.

### Infrastructure

- Stable self-signed code-signing identity in a dedicated no-password
  keychain — TCC (Microphone, Accessibility) survives rebuilds.
- Hardened-runtime entitlements for microphone / audio-input.
- One-time auto-migration of `~/Library/Application Support/VoiceType/` →
  `…/VOCA/` so existing data is preserved.
