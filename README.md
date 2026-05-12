# VoiceType

A native macOS dictation and translation app inspired by **Typeless**, but
runs on **your own API keys** so you can pick the cheapest, fastest
transcription model — Groq Whisper-large is the recommended default.

## Features

- **Push-to-talk dictation** — hold **Right Option** to record, release to paste.
- **Push-to-talk translation** — hold **Right Option + Right Shift** to dictate
  in your source language and paste the translated text in your target.
- **LLM refinement** — raw transcripts are polished by an LLM that removes
  filler words, fixes punctuation, honours voice commands ("new line",
  "new paragraph", "comma", "period"…), and respects your glossary.
- **Personal dictionary** — store proper nouns and jargon that should always
  be spelled a specific way.
- **Adaptive memory** — phrases you use often are tracked and fed back to the
  transcription model as bias prompts.
- **Bring your own model**
  - **STT**: Groq Whisper (recommended), OpenAI Whisper, Deepgram Nova, or
    Apple Speech (on-device, free, offline).
  - **LLM**: Groq Llama 3.3 70B (recommended), OpenAI GPT, Anthropic Claude,
    or *disabled* if you want raw transcripts.
- **Menu-bar only** — no dock icon, no window unless you open Settings.

## Quickstart

```bash
git clone <this repo>
cd VoiceType
./scripts/build-app.sh
open dist/VoiceType.app
```

On first launch:
1. Grant **Microphone** access when prompted.
2. Grant **Accessibility** access (System Settings → Privacy & Security →
   Accessibility). Without it, the global hotkey won't work and the app
   can't paste.
3. Open **Settings → Providers** and paste your **Groq API key**
   (https://console.groq.com/keys). That's enough for full functionality —
   Groq handles both transcription (Whisper) and refinement (Llama).

## Hotkeys

| Action | Hotkey |
|---|---|
| Dictate (transcribe in same language) | Hold **Right Option** |
| Translate (dictate, paste translated) | Hold **Right Option + Right Shift** |
| Open Settings | Menu-bar icon → Settings |

To avoid clashing with Option+vowel accent input, hotkeys engage after a
**180 ms hold**.

## Storage

User data lives in `~/Library/Application Support/VoiceType/`:

- `settings.json` — provider choices and API keys.
- `dictionary.json` — your glossary.
- `memory.json` — auto-learned phrases and personal facts.

> ⚠ API keys are currently stored plain-text. Keychain integration is on the
> roadmap.

## Development

```bash
swift build           # compile
swift test            # run unit tests
./scripts/build-app.sh   # build the .app bundle and ad-hoc sign it
```

Targets:
- `VoiceTypeCore` — audio, hotkeys, STT/LLM providers, persistence.
- `VoiceTypeApp`  — menu-bar app, HUD, Settings UI.

## Roadmap (post-v1)

- Custom hotkeys + per-app tone presets.
- Move API keys to Keychain.
- Streaming partial transcripts (Deepgram WebSocket).
- Local Whisper via `whisper.cpp` for fully-offline mode.
