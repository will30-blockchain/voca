# Contributing to VOCA

Thanks for being here. A few quick notes so your first PR lands smoothly.

## Local setup

```bash
git clone https://github.com/will30-blockchain/voca.git
cd voca-ai-typer
./scripts/setup-signing.sh   # one-time, creates a local code-signing cert
swift build
swift test
./scripts/build-app.sh       # produces dist/VOCA.app
```

Requires macOS 14+, Xcode 15+, and Swift 5.10+.

## Project layout

See the **Architecture** section in the [README](README.md).

Rule of thumb: anything that doesn't need AppKit goes in `VOCACore`. Anything
that touches windows, menus, status items, or system event taps goes in
`VOCA`.

## Pull-request checklist

Before opening a PR:

- [ ] `swift build` passes locally
- [ ] `swift test` passes locally (and you added tests for new pure-Swift
      logic — see `Tests/VOCACoreTests`)
- [ ] You ran the app and verified the change behaves as described
- [ ] You updated user-facing copy and `README.md` if behaviour changed
- [ ] You added an entry to `CHANGELOG.md` under `## Unreleased`
- [ ] No secrets, API keys, or audio recordings committed

## Commit style

Conventional-Commits-flavoured but informal:

```
feat: short imperative description

A longer paragraph if necessary, explaining the *why* — never restate
what the diff already shows.
```

Common prefixes: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `build`.

## Reporting bugs

Settings → Logs has a **Copy all** button. Attach that output (or the
`~/Library/Application Support/VOCA/log.jsonl` file) when filing an issue —
it shows every pipeline step and per-stage latency, which is usually enough
to diagnose without back-and-forth.

Please redact any API keys and personal data before sharing logs.

## Adding a new STT or LLM provider

1. Create `Sources/VOCACore/<Transcription|LLM>/<Name>Provider.swift`
   conforming to `STTProvider` or `LLMProvider`.
2. Add a case to `STTProviderID` / `LLMProviderID`.
3. Wire it in the corresponding `Factory.make(...)`.
4. Add credential storage to `ProviderCredentials` if it needs one.
5. Surface it in the Providers settings pane.
6. Add a known-good models list under the enum's `knownModels`.

## Code of conduct

Be kind. We're all here in our spare time.

## License

By contributing you agree to license your contributions under the MIT
license (see [LICENSE](LICENSE)).
