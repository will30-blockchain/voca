# Changelog

All notable changes to VOCA AI Typer are documented here. Format inspired by
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
