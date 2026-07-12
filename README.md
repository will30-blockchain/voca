<div align="center">

<img src="Resources/logo.png" alt="VOCA" width="116" height="116" />

# VOCA

**Bring-your-own-key voice dictation for macOS**

Speak, and clean typed text lands at your cursor — in any app.<br/>
Your speech, your API keys, your data.

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
[![Build](https://github.com/will30-blockchain/voca/actions/workflows/ci.yml/badge.svg)](https://github.com/will30-blockchain/voca/actions)

</div>

VOCA is a native macOS menu-bar dictation and translation tool inspired by
Typeless. You bring your own API keys and pick the fastest, cheapest model on
the market — pay only what you use, with nothing stored on someone else's
server.

---

## Why VOCA

- **Bring your own keys.** Groq, OpenAI, Anthropic, Deepgram — or fully
  offline via Apple Speech. The cheapest pairing costs a fraction of a cent
  per dictation.
- **Polish, not just transcription.** An LLM drops fillers, resolves
  self-corrections, shapes emails, and turns spoken lists into numbered
  lists — without inventing content.
- **A dictionary that learns.** Fix a typo right after dictation and VOCA
  quietly adds the term, Typeless-style, so it gets it right next time.
- **First-class Chinese.** Traditional / Simplified aware, code-switching
  preserved, and Pangu spacing between CJK and Latin (用VOCA → 用 VOCA).
- **Translate as you speak.** Dictate in one language, paste the translation
  in another.
- **Calm, native UI.** A real menu-bar app — no glass, no glow, no AI sheen.
  Just warm-white surfaces and SF Pro.

## Features

| Feature | What it does |
|---|---|
| 🎙 Hotkey | Tap **Right Option** to start/stop dictation |
| 🌐 Translate | Tap **Right Option**, add **Right Shift** before releasing |
| 🔊 Live meter | RMS-driven waveform tells you the mic is actually capturing |
| ⌥ Refine | LLM cleans punctuation, drops fillers, handles self-corrections |
| ✉️ Email shape | Auto-formats when it sees a greeting + sign-off |
| 1️⃣ Lists | 「第一點 / 第二點 / …」 → real numbered list |
| 📖 Dictionary | Glossary biases STT and LLM editor. Auto-adds proper nouns when you correct a typo after pasting |
| 🧠 Memory | Frequency-tracked phrases (≥ 2 uses), plus free-form personal facts |
| ✦ Pangu spacing | Half-width space between CJK and Latin / digits (default on) |
| ↻ Retry | Network blip mid-pipeline → audio stays buffered, retry on tap |
| ⎋ ESC | Press anywhere to cancel an in-progress recording |
| 📋 Logs | Settings → Logs shows every pipeline step + per-stage latency |

## Install

Download the ready-to-run `.dmg` from
[Releases](https://github.com/will30-blockchain/voca/releases) — no Xcode
required. (Prefer to build it yourself? See [Build from source](#build-from-source).)

VOCA is currently **self-signed** — there's no Apple Developer ID signature
yet, so macOS Gatekeeper won't open it on a normal double-click. The one-time
workaround is below; see [Distribution status](#distribution-status) for the
plan to remove it.

### First launch — bypass Gatekeeper

1. Open the `.dmg` and drag `VOCA.app` into `/Applications`.
2. In the Applications folder, **right-click (or Control-click)
   `VOCA.app` → Open**.
3. The dialog says *"macOS cannot verify the developer of VOCA."* Click
   **Open** anyway — the button only appears via this right-click path.
4. Done. VOCA opens with a normal double-click from now on; the right-click is
   a once-per-install step.

> **"App is damaged and can't be opened"?** The download's quarantine bit is
> set. Clear it once, then retry the right-click:
> ```bash
> xattr -dr com.apple.quarantine /Applications/VOCA.app
> ```
> This removes only the quarantine flag — not the signature, contents, or any
> permissions you've granted.

### Grant permissions & add your key

1. **Microphone** — macOS prompts the first time you press the hotkey.
2. **Accessibility** — *System Settings → Privacy & Security → Accessibility*,
   toggle VOCA on, then **quit and relaunch** (⌘Q, reopen). macOS only re-reads
   Accessibility trust at launch, so the toggle does nothing without a restart.
3. **API key** — Settings → Providers, paste your Groq key from
   <https://console.groq.com/keys>.

Then tap Right Option, speak, tap again — your text lands at the cursor.

### Distribution status

| Path | Status |
|---|---|
| Self-signed `.dmg` from GitHub Releases (right-click → Open) | ✅ Current |
| Apple Developer ID signature + notarisation (double-click opens cleanly) | 🚧 Planned, requires $99/year Apple Developer Program |
| Homebrew Cask | 🚧 Planned, after Developer ID lands |
| Mac App Store | ❌ Not planned — App Sandbox rules effectively forbid global hotkeys + Accessibility |

The right-click dance only exists because of the Developer ID gap. Once
notarised builds are available, double-clicking just works.

## Build from source

For contributors, or to run the latest `main`.

Prerequisites:
- macOS 14 Sonoma or later
- Xcode 15+ with the Swift toolchain
- A Groq, OpenAI, Anthropic, or Deepgram API key (or use Apple Speech offline)

```bash
git clone https://github.com/will30-blockchain/voca.git
cd voca
./scripts/setup-signing.sh   # one-time: create a stable local signing cert
./scripts/build-app.sh       # build + sign VOCA.app
open dist/VOCA.app
```

Then follow [Grant permissions & add your key](#grant-permissions--add-your-key) above.

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

## Architecture

Two Swift packages. **`VOCACore`** is pure, AppKit-free domain logic — audio
capture, STT/LLM provider clients, refinement, correction-learning, and
JSON persistence. **`VOCA`** is the AppKit + SwiftUI menu-bar app. The
pipeline — record → transcribe → refine → inject → learn — is orchestrated by
`VoiceTypeEngine`.

```
Sources/
  VOCACore/           Audio · Hotkeys · Transcription · LLM · Refinement ·
                      Learning · Memory · Dictionary · History · Logging ·
                      Settings · Util · Permissions · VoiceTypeEngine
  VOCA/               AppDelegate · MenuBar · Dashboard · HUD · Toast ·
                      Settings (7 panes) · DesignTokens
Tests/VOCACoreTests/  Pure-Swift unit tests
scripts/              setup-signing · build-app · uninstall-signing · make-icon
```

The visual language follows SuperCard's "Professional Warmth" (warm-white
surfaces, brand orange, SF Pro). For the full design notes see
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); for the auto-learn accuracy
roadmap see [`docs/AUTO_LEARN_PLAN.md`](docs/AUTO_LEARN_PLAN.md).

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

## Support development

VOCA is built and maintained in spare time. If it saves you time or
typing pain, consider chipping in — it pays for the occasional Apple
Developer Program fee, coffee, and the API credits used while testing.

**Ethereum / EVM** (works on Mainnet, Polygon, BSC, Arbitrum, Base, etc.):

```
0x081540Eb4c21B8Be8a652d408A4711bFaffeB5f4
```

For anything else, email **valley.mirror7602@eagereverest.com**.

## Acknowledgments

VOCA was built collaboratively with
[Claude Code](https://claude.com/claude-code) — architecture, design
decisions, and most of the implementation were iterated through
pair-programming sessions with Claude. The product itself is not an "AI
app" in any user-facing sense; it's a voice-typing utility that happens
to call AI APIs you choose.

The "Professional Warmth" visual language is shared with the
[SuperCard](https://github.com/will30-blockchain) family of apps, and the
write-then-fix-and-learn UX takes its cue from
[Typeless](https://typeless.io/).

## License

MIT — see [`LICENSE`](LICENSE).
