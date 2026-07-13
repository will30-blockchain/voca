# Auto-learn optimization plan & status

VOCA learns from corrections: after it pastes a dictation, it watches the
focused field, and when you edit the text it diffs pasted-vs-edited and adds
new terms to your glossary. That glossary then biases both the STT prompt and
the LLM refinement. This document records the plan to raise its accuracy
toward best-in-class dictation correction, and what has shipped.

The plan was revised after an adversarial cross-review (two independent
engineers). The original plan front-loaded a deterministic post-LLM
string-replacement pass and Chinese pinyin homophone modeling; the review
showed that ordering built the most dangerous, least-reversible piece first,
on top of an alignment the diff didn't produce and a phonetic key that
mis-keys the very names it targets. The revised plan below **measures and
secures first, then learns** — and deliberately does **not** ship blind
deterministic replacement.

## Why "learn a word list" wasn't enough

- **Learning happens on POST-LLM text.** The learner diffs the *refined*
  paste, so a learned "correction" may reflect an LLM rewrite, not an STT
  mishearing — and only STT errors are fixable by STT biasing.
- **A single edit is a weak signal.** One in-place fix (own typo, unrelated
  edit, app reflow) permanently polluted the glossary; for CJK it learned
  common words on any correction.
- **The STT bias was broken.** Uncapped (could blow Whisper's ~224-token
  window), terms placed where Whisper doesn't attend, Deepgram keywords
  polluted by label/joiner text, and Apple Speech bias was a no-op.
- **No measurement.** No way to tell whether learning helped, or how often
  the edited field was even readable (the real bottleneck).

## Status

| Stage | Item | Status |
|---|---|---|
| 0 | Structured, capped, provider-aware STT biasing (`STTBias`) | ✅ Shipped |
| 0 | `FieldReader` test seam (inject AX reader) | ✅ Shipped |
| 0 | Measurement: capture-rate + promotion metrics (`LearningMetrics`) | ✅ Shipped |
| 1 | Confidence gating — ≥ 2 sightings before persisting (`LearningGate`) | ✅ Shipped |
| 1 | Expansion guard (don't mine newly-typed content as corrections) | ✅ Shipped |
| 1 | Privacy: redact secret-shaped tokens from stored context hint | ✅ Shipped |
| 2 | Robustness: bound the word-level diff; capture-rate observability | ✅ Shipped |
| 3 | STT-vs-LLM attribution of each learned fix (measurement-only) | ✅ Shipped |
| 3 | Correction *pairs* (wrong→right) via real alignment | ⏸ Deferred |
| 4 | Chinese homophone modeling (phrase-aware pinyin) | ⏸ Deferred |

## Deferred, and why (not skipped)

**Deterministic post-LLM string replacement — dropped, not deferred.** Blind
`wrong→right` replacement causes false corrections: in Chinese, single/double
-char substrings poison unrelated words (learn `在→再` and `現在→現再`); it
overrides the LLM's context judgment and can undo code-switching protection.
The review's conclusion — and ours — is to keep learning feeding the *soft*
glossary bias, where the model can decline a bad term.

**Correction pairs + Chinese homophone keying — deferred pending data.**
Both need signal we now collect but don't yet have:

1. The STT-vs-LLM attribution metric (Stage 3) tells us how much of the error
   is STT-side (where biasing/pairs help) vs LLM-side (where they don't).
2. Homophone keying needs a phrase-aware pinyin source (e.g. CC-CEDICT);
   `CFStringTransform`'s Mandarin transliteration mis-keys 多音字/破音字 —
   exactly the names and places it would target — so shipping it alone would
   be net-negative. It also must be validated on a Traditional-Chinese set.

The groundwork (metrics) is in place to make that call with data instead of
assumption.

## Design notes

- `STTBias` ranks glossary sources by confidence (manual → memory →
  auto-learned), de-dupes case-insensitively, caps the list, and emits the
  most important terms **last** for Whisper's tail-weighted attention. Each
  provider formats the structured term list itself.
- `LearningGate` is pure, `Codable`, and unit-tested; `CorrectionGate` wraps
  it with disk persistence and a bounded pending map.
- `LearningMetrics` exposes `captureRate` and promotion attribution; persisted
  to `learn_metrics.json` and logged on capture failure.
- The auto-learn feature remains user-toggleable (`learnFromCorrections`), and
  every learned term is removable from the dashboard.
