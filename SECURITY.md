# Security Policy

VOCA is a single-binary macOS app that holds your API keys, listens to your
mic, and pastes into other apps. We take vulnerability reports seriously.

## Reporting a vulnerability

**Do not** open a public GitHub issue for security reports.

Email **valley.mirror7602@eagereverest.com** with:
- A short description of the issue.
- Steps to reproduce (or a proof-of-concept).
- Your assessment of impact.
- VOCA version (`Dashboard → footer` or `dist/VOCA.app/Contents/Info.plist`).

You will get an acknowledgement within **5 business days**. If the issue is
confirmed, expect a fix or mitigation within **30 days** for high-severity
issues. We coordinate disclosure timing with you.

This is a hobby-scale project — there is no bug bounty.

## In scope

- Code execution, privilege escalation, or sandbox escapes triggered by VOCA.
- API key exfiltration via the network or to disk outside the macOS Keychain.
- Microphone capture or paste injection performed without the user's intent.
- Bypassing the log redaction rules (i.e. an API key landing in `log.jsonl`).
- Supply-chain attacks against the build pipeline or release artefacts.

## Out of scope

- Bugs that require an already-compromised macOS account.
- Prompt-injection of an LLM endpoint you control by virtue of supplying its
  API key. You are the operator of that endpoint.
- Issues only reachable with a physically-present attacker who already has
  Accessibility permission to your Mac.
- Social-engineering ("I tricked the user into pasting their key").
- The self-signed dev certificate in `build/voca-signing.keychain-db` — it
  is a known-trust-only-locally artefact, see `scripts/setup-signing.sh`.

## Hall of fame

People who responsibly disclosed are credited in `CHANGELOG.md` (with their
permission). No exceptions for public-issue first.
