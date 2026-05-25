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
[![Build](https://github.com/will30-blockchain/voca/actions/workflows/ci.yml/badge.svg)](https://github.com/will30-blockchain/voca/actions)

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
git clone https://github.com/will30-blockchain/voca.git
cd voca-ai-typer
./scripts/setup-signing.sh   # one-time: create a stable local signing cert
./scripts/build-app.sh       # build + sign VOCA.app
open dist/VOCA.app
```

### What the build scripts touch on your machine

We take a hard line: **VOCA's build pipeline must not break unrelated apps on
your Mac.** Concretely the scripts here:

- Persistent files written **only** inside the project's `build/` directory.
- **Do not** touch your login keychain or any password it holds.
- **Do not** install anything in `~/Library/`.
- The user keychain search list is *temporarily* modified during the
  `codesign` call (macOS requires it — `--keychain` alone is not enough).
  `build-app.sh` traps `EXIT`, `INT`, and `TERM` to **guarantee the original
  search list is restored** before the script returns, even on failure or
  Ctrl-C. Net effect: zero persistent change.

`setup-signing.sh` creates a project-local keychain at
`build/voca-signing.keychain-db` containing one self-signed dev certificate.
To wipe every trace, run `./scripts/uninstall-signing.sh`. (It also detects
and cleans up a known bug in pre-2026-05 versions of `setup-signing.sh` that
*permanently* polluted the user-wide keychain search list — that bug is
fixed now.)

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

Visit [Releases](https://github.com/will30-blockchain/voca/releases) for a
ready-to-run `.dmg` of the latest version. No Xcode required.

VOCA is currently **self-signed** — there is no Apple Developer ID
signature yet (see the [Distribution status](#distribution-status) section
below for the plan). Because of that, macOS Gatekeeper does **not**
recognise the signature and will refuse to open the app on a normal
double-click. This is expected. Here is what you do once.

### First launch — bypassing Gatekeeper

1. Download the `.dmg` from the latest release.
2. Open the `.dmg` and drag `VOCA.app` into `/Applications`.
3. Open Finder, go to the Applications folder.
4. **Right-click (or Control-click) `VOCA.app` → Open.**
5. A dialog says *"macOS cannot verify the developer of `VOCA`."* Click
   **Open** anyway. (The button only appears via the right-click path,
   not on a normal double-click.)
6. From this point on, VOCA opens normally with a double-click. You only
   need the right-click dance once per install.

### "App is damaged and can't be opened"

If macOS shows the *"damaged and can't be opened"* error instead of the
right-click prompt, it means the app's quarantine bit was set during
download and Gatekeeper is being extra strict. Run this once in Terminal,
then try the right-click step again:

```bash
xattr -dr com.apple.quarantine /Applications/VOCA.app
```

This removes only the quarantine flag — it doesn't change the app's
signature, contents, or any permissions you've granted.

### Permissions on first run

After the Gatekeeper bypass succeeds, VOCA will ask for two permissions:

1. **Microphone** — required. macOS prompts you the first time you press
   the hotkey.
2. **Accessibility** — required so the global hotkey works in every app.
   Open *System Settings → Privacy & Security → Accessibility*, toggle
   VOCA on, then **quit and relaunch VOCA** (⌘Q then reopen). macOS only
   re-reads Accessibility trust at process start, so the toggle does
   nothing without a restart.

### Distribution status

| Path | Status |
|---|---|
| Self-signed `.dmg` from GitHub Releases (right-click → Open) | ✅ Current |
| Apple Developer ID signature + notarisation (double-click opens cleanly) | 🚧 Planned, requires $99/year Apple Developer Program |
| Homebrew Cask | 🚧 Planned, after Developer ID lands |
| Mac App Store | ❌ Not planned — App Sandbox rules effectively forbid global hotkeys + Accessibility |

The right-click dance only exists because of the Developer ID gap. Once
notarised builds are available, normal double-clicking will just work.

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
  setup-signing.sh          — Generates a stable self-signed cert in a
                              project-local keychain (build/) so TCC
                              remembers permissions across rebuilds
  build-app.sh              — swift build + bundle + sign + .icns
  uninstall-signing.sh      — Reverses setup-signing.sh; cleans up legacy
                              state from older versions of the script
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

## Threat model

What VOCA is and isn't designed to protect against, so you can decide
whether it fits your use case:

**In scope (we care):**
- Your API keys staying on your machine. Logs are redacted by prefix
  (`sk-`, `sk-ant-`, `gsk_`, `AIza`) before being written to disk so a
  pasted log excerpt in a bug report cannot leak them.
- Audio not being persisted. Recordings live in memory only and are
  released after the response comes back.
- Pasted output going only to the app you were focused on when you tapped
  the hotkey — VOCA doesn't refocus or background-switch.
- No outbound traffic except to the provider endpoint you selected. No
  telemetry, no crash reporter, no analytics SDK in the binary.

**Out of scope (we don't try to protect against):**
- A malicious app already running on your Mac with the same user
  privileges. If something hostile has Accessibility permission, it can
  read what you type with or without VOCA.
- Your chosen provider (Groq, OpenAI, Anthropic, Deepgram) seeing the
  text you dictate — that's an inherent consequence of using a remote
  STT/LLM. Use the Apple Speech provider for fully offline mode.
- Disk encryption at rest. We assume your Mac is using FileVault.

For vulnerability disclosure see [SECURITY.md](SECURITY.md).

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
open an issue first to discuss the approach. By participating you agree to
our [Code of Conduct](CODE_OF_CONDUCT.md).

## Acknowledgments

VOCA was built collaboratively with
[Claude Code](https://claude.com/claude-code) — architecture, design
decisions, and most of the implementation were iterated through
pair-programming sessions with Claude. The product itself is not an "AI
app" in any user-facing sense; it's a voice-typing utility that happens
to call AI APIs you choose.

The visual language ("Professional Warmth" — warm-white surfaces, brand
orange accent, SF Pro) is shared with the
[SuperCard](https://github.com/will30-blockchain) family of apps.

Original inspiration: [Typeless](https://typeless.io/), whose
write-then-fix-and-learn UX shaped the dictionary auto-learn flow.

## License

MIT — see [`LICENSE`](LICENSE).
