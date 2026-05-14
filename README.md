# VOCA — bring-your-own-key voice dictation for macOS

VOCA is a native macOS menu-bar dictation and translation tool inspired by
Typeless, but built around the principle that **your speech, your API keys,
your data**. Pick the fastest, cheapest model on the market; pay only what you
use; nothing is stored on someone else's server.

```
   ▎▎█▎▎  ⌶
   speech → typed text
```

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
[![Build](https://github.com/your-org/voca-ai-typer/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/voca-ai-typer/actions)

---

## Why VOCA

- **Bring your own keys.** Groq, OpenAI, Anthropic, Deepgram, or fully offline
  via Apple Speech. The cheapest pairing (Groq Whisper + Llama 3.3) costs a
  fraction of a cent per dictation.
- **LLM polish.** Drops filler words, adds punctuation, honours voice commands
  ("new line", "period"), respects your glossary — without inventing content.
- **Personal dictionary that learns.** Names, acronyms, and jargon you say
  often get added automatically when you fix a typo right after dictation,
  Typeless-style. You always see what was learned, with one-tap Undo.
- **Translate mode.** Hold Right Shift while tapping Right Option to dictate
  in one language and paste the translation in another.
- **Flat, paper-like UI.** No glass effects, no glow, no AI sheen. Just
  warm-white surfaces and SF Pro.

## Features

| | |
|---|---|
| 🎙 Hotkey | Tap **Right Option** to start/stop dictation |
| 🌐 Translate | Tap **Right Option + Right Shift** for translation |
| 🔊 Live meter | RMS-driven waveform tells you the mic is actually capturing |
| ⌥ Refine | LLM cleans punctuation, fixes Whisper hallucinations, applies tone |
| 📖 Dictionary | Glossary of proper nouns biases STT *and* LLM editor |
| 🧠 Memory | Phrases you use often, plus free-form personal facts |
| ↻ Retry | Network blip mid-pipeline → audio stays buffered, retry on tap |
| ⎋ ESC | Press anywhere to cancel an in-progress recording |
| 📋 Logs | Settings → Logs shows every pipeline step + per-stage latency |

## Quickstart

Prerequisites:
- macOS 14 Sonoma or later
- Xcode 15+ with Swift toolchain
- A Groq, OpenAI, Anthropic, or Deepgram API key (or use Apple Speech offline)

```bash
git clone https://github.com/your-org/voca-ai-typer.git
cd voca-ai-typer
./scripts/setup-signing.sh   # one-time: create a stable local signing cert
./scripts/build-app.sh       # build + sign VOCA.app
open dist/VOCA.app
```

On first launch:

1. Grant **Microphone** access when prompted.
2. Open System Settings → Privacy & Security → Accessibility, toggle VOCA on.
3. Quit VOCA (⌘Q) and relaunch — macOS only refreshes Accessibility trust at
   process start.
4. Open VOCA's Settings → Providers, paste your Groq API key from
   <https://console.groq.com/keys>.
5. Tap Right Option, speak, tap again — your transcript is pasted at the
   cursor.

## Pre-built downloads

Visit [Releases](https://github.com/your-org/voca-ai-typer/releases) for a
signed `.dmg` of the latest version.

Until a Developer ID signature is available, you may need to right-click the
app and choose **Open** the first time to bypass Gatekeeper.

## Architecture

```
Sources/
  VOCACore/                 — Pure-Swift, AppKit-free domain logic
    Audio/                  — AVAudioEngine recorder + RMS meter + SoundPlayer
    Hotkeys/                — CGEvent-tap based global tap-toggle hotkeys
    Transcription/          — STT provider clients: Groq, OpenAI, Deepgram, Apple
    LLM/                    — LLM provider clients: Groq, OpenAI, Anthropic
    Refinement/             — Prompts, HallucinationFilter
    Learning/               — CorrectionDiff, AXTextReader, CorrectionLearner
    Memory/ Dictionary/     — File-backed JSON stores
    History/ Logging/       — Transcript log + event log
    Settings/ Util/         — Persistence helpers, SupportDirectory
    Permissions/            — Mic + AX permission helpers
    VOCAEngine.swift        — Top-level pipeline orchestrator

  VOCA/                     — macOS app (menu-bar, windows, HUD, toast)
    AppDelegate · main · MenuBarController
    DashboardWindow + DashboardView
    HUDWindow + HUDView (floating pill with waveform / progress / retry)
    ToastWindow             — "X added to dictionary" notification
    Settings/               — 7 panes (General, Providers, Languages,
                              Dictionary, Memory, Logs, About)
    DesignTokens.swift      — Single source of truth for colours, type,
                              spacing, radius. Inspired by SuperCard's
                              "Professional Warmth".

Tests/VOCACoreTests/        — Pure-Swift unit tests

scripts/
  setup-signing.sh          — Generates a stable self-signed cert so TCC
                              remembers permissions across rebuilds
  build-app.sh              — swift build + bundle + sign + .icns
  make-icon.sh              — sips logo.png → VOCA.icns
  reset-permissions.sh      — tccutil reset for the bundle ID
```

Read [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full design notes.

## Privacy

- Audio never touches disk. The recorded WAV lives in memory and is shipped
  directly to the provider you configured.
- API keys live plain-text in `~/Library/Application Support/VOCA/settings.json`
  for v1. **Keychain integration is on the roadmap.** Treat that file as
  sensitive.
- Everything else (dictionary, memory, history, logs) is local to your Mac.
- VOCA never phones home. The only outbound HTTP requests are to the
  provider endpoints you select.

## Roadmap

- [ ] Keychain-backed API key storage
- [ ] Customisable hotkeys
- [ ] Streaming partial transcripts (Deepgram, OpenAI Realtime)
- [ ] Local Whisper via `whisper.cpp` for full offline mode
- [ ] Homebrew Cask submission
- [ ] Sparkle-based auto-update
- [ ] Windows companion (`voca-windows`)

## Contributing

PRs welcome. See [`CONTRIBUTING.md`](CONTRIBUTING.md). For non-trivial changes,
open an issue first to discuss the approach.

## License

MIT — see [`LICENSE`](LICENSE).
