# Danny's flagship chain, wired into the Roundtable — 2026-10-25

Order (Richard, 2026-10-25): "Integrate Danny AI" → clarified as wiring
his chain into the Roundtable, then executed on his tap.

## What was already true

Danny led the roster (index 0, `configured_voice_uncast`) and his
8-stage chain (perceive → appraise → discern → draft → critique →
revise → respond → reflect, critique/revise never skipped) ran on every
one-to-one chat reply. At the table he took the generic path: a
roundtable prompt + one think step + one inference call. He was
flagship in chat, ordinary at the table.

## What changed

`flutter_app/lib/core/roundtable.dart` — `RoundtableSession.step()`:

- When the picked speaker is Danny, a mind is booted, and there is a
  real stimulus (a previous line, or a topic Richard supplied), the
  turn runs `DannyChain` instead of the generic path. The chain's
  think step replaces the generic think step (never both), its
  perceive search replaces the turn's pre-search, and its reflect
  stage replaces the generic self-model recording for that turn.
  Only table-specific bookkeeping stays in the generic block:
  `recordRoundtableSpeech()` and the affinity adjustment.
- The chain's own decay/appraisal are not doubled: the step's
  pre-decay and the speaker's self-appraisal are skipped for chain
  turns (the chain's perceive/reflect stages do both, once).
- Fallbacks, honest: no booted mind → generic path; no stimulus at
  all (no previous line, empty topic) → generic path. A chain with
  nothing to answer would be fabrication, not a flagship turn.

`flutter_app/lib/core/danny_chain.dart` — `run()` gained two optional
parameters, defaults preserving one-to-one chat behaviour exactly:

- `contextLabel` — the think-step context (Roundtable turns pass
  `Roundtable (<mode>) with <cast>`).
- `stimulusSpeaker` (default `'richard'`) — who the discernment
  record and the ledger credit the stimulus to. Roundtable turns
  pass the previous speaker's id, or `'richard'` when the topic
  itself is the stimulus. Recording another agent's line as
  Richard's statement would have corrupted both records; this is
  the fix that made the wiring safe, not just possible.

`flutter_app/lib/core/voice_engine.dart` — audio/TTS players are now
created lazily on first use instead of at construction. No behaviour
change for real use; construction previously threw in test
environments without the platform plugins, which blocked testing
the table at all.

## Tests

New: `flutter_app/test/danny_roundtable_test.dart` — drives a real
`RoundtableSession` with a scripted router until a Danny turn
appears (speaker pick has jitter, so no assumption about turn
order). It locks: the turn's text is the revision (never the
draft), a draft prompt AND a critique prompt reached the router
(the generic path sends neither), the turn carries a thought
summary, and the Lie Detector record carries the stimulus's real
speaker (previous agent, or Richard for a topic-first turn) —
never a defaulted Richard for another agent's line.

## Verification (2026-10-25, this build)

- `flutter analyze`: 1 pre-existing info only
  (`pixel_stream_client.dart`, parallel work — not this change).
- `flutter test`: **112/112** (includes the new roundtable test).
- `cargo test`: **78/78** (Rust core untouched by this change).
- `tools/release_gate.sh`: **PASS** — staged `.so` a8c41581… fresh,
  30 exports, all 26 Dart lookups resolve, ABI 2 = 2.

## Still NOT done (unchanged by this work)

- Danny's voice is still UNCAST — needs Richard's ElevenLabs pick;
  no ID invented.
- Nothing is device-verified — APK build still blocked on
  `other_tcp`; the retry job keeps checking every 20 minutes.
- Sales-listing roster counts (22) are still stale vs the real 23;
  the approved copy is Richard's to update, untouched here.
