# Lie Detector — integrated 2026-10-23

Built at Richard's direct order ("Integrate a lie detector").
The Lie Detector is an app-level statement-checking instrument
(`flutter_app/lib/core/lie_detector.dart`) that generalizes
Danny's discernment engine (`danny_discernment.dart`) from a
per-message prompt pass into a standing service with statement
intake, a persistent record, and a per-speaker credibility
ledger. It runs entirely on machinery that already existed:
the daemon's witness fact table (Rust `facts.rs`, FFI
`rga_witnesses` / `rga_witness_facts`), the discernment lexical
engine, and the SharedPreferences persistence pattern of the
mind store / DannyLedger. No new native code, no new FFI.

## The labelling line (shown on every surface)

> Detects contradictions against recorded facts and the
> speaker's own prior statements. It cannot detect lies that
> leave no contradiction, and it reads no body signals.

That line is the feature's honest scope, and it is printed in
the interrogation view, in the prompt block Danny's critique
stage receives, and in the service's own code documentation.

## Mechanism

**Intake + record.** A statement enters with a speaker name
and a timestamp and is split into claims — sentences of 8+
characters, the exact split discernment uses
(`Discernment.splitClaims`, shared so a "claim" means the same
thing in both engines). Every checked statement is kept, with
the verdicts it earned, in a persistent per-app record
(SharedPreferences key `lie_detector_v1`, the DannyLedger
boot/save/acquire pattern; booted inside `MindStore.boot`,
acquired lazily by surfaces so it is never silently absent).
Retention is capped at the most recent 200 statements; older
ones roll off and stop contributing to checks and ledgers.

**Three checks per claim**, all deterministic and lexical —
the detector reuses discernment's one tokenizer, negation set,
and number extractor (exposed as `Discernment.tokensOf /
numbersOf / isNegated`) rather than running a second engine:

1. **Fact check** vs the daemon witness fact table. A claim
   the record backs is **SUPPORTED**; a claim that clashes
   with a content-matching fact (negation present on one side
   only, or numbers that disagree) is **CONTRADICTED**. The
   specific fact (witness, fact id, text) and the signal are
   cited either way. The FFI facts view never serializes lie
   text, so checks always run against on-record truth.
2. **Self-contradiction check** vs the same speaker's own
   prior recorded claims — plus claims earlier in the same
   statement, which are on record by the time a later claim is
   checked (sequential intake). Among prior claims sharing
   enough content tokens (≥2, or ≥1 when the claim is that
   small — the fact check's coverage rule), the largest
   overlap decides, ties keep the most recent; it fires only
   on the two signals a lexical check can see: a negation
   mismatch, or numbers on both sides that do not intersect.
   A firing is **CONTRADICTED** with the earlier claim and its
   date cited. **This check is a heuristic** — it compares
   words and numbers, not meaning — and is named one wherever
   it fires.
3. Anything neither check covers is **UNVERIFIABLE**. The
   detector never guesses a verdict.

**Verdict composition.** A claim is CONTRADICTED if either
check fired; SUPPORTED only when the record backs it and no
self-clash fired; otherwise UNVERIFIABLE. A statement's
readout is composed only of its claim verdicts, e.g.
"2 supported · 1 contradicted · 3 unverifiable".

**Credibility ledger.** Per speaker, a fold over the retained
record: statements checked, and supported / contradicted /
unverifiable claim counts. It is a consistency history —
**not a lie probability, not a trust score**. The only ratio
anywhere is plain arithmetic shown with its counts beside it
("of the N claims the record could decide, K were
contradicted"). Stored verdicts are kept as earned and never
re-derived, so history does not rewrite itself as the record
grows.

**Verdict vocabulary.** SUPPORTED / CONTRADICTED /
UNVERIFIABLE — the detector never infers "LIE". That word
belongs only to the daemon's scene data itself (a statement
the config marks with `lie_text`, surfaced by the
interrogation's witness-statement path), never to a detector
inference.

## Surfaces

- **Danny's discern stage (Second Sight).** The flagship
  chain now takes each user message in as a statement from
  Richard, runs it through the detector (fact checks use the
  chain's own discernment table, passed explicitly so the two
  can never disagree about the record), records it on the
  shared detector, and reports the detector's full readout —
  headline counts in the stage trace, and the prompt block
  (labelling line + readout + Richard's credibility line)
  in front of the mandatory critique pass. The think-step
  memory claim is still cross-checked against the fact table
  and appended when it finds coverage. `DannyChainResult`
  carries the `StatementReport` alongside the fact checks.
- **Interrogation view.** A Lie Detector section under the
  interrogation: the labelling line verbatim, a manual check
  form (speaker + statement), and the credibility ledger for
  every speaker on record. Statements collected in play are
  run through the detector automatically as that witness's
  statements. No gauges, needles, or physiological graphics —
  per-claim verdict lines with their citations, as text.

## The empty fact base

The shipped `daemon_config.json` supplies **no scene facts**
(Richard's standing choice: he supplies his own scene data;
the authored sample scene was deleted 2026-10-21). So today:

- Fact checks are **idle** — every report says NO FACTS
  AVAILABLE for them, exactly as Danny's discernment does.
- The self-contradiction check **works from the first
  recorded statement onward**, because its record is the
  detector's own. Statements are recorded and accumulate a
  real consistency history with zero scene data.
- The detector's fact table resolves **lazily** from the
  daemon at check time (MindStore boots before the daemon in
  main.dart, so a boot-time snapshot would be permanently
  empty), and surfaces call `refreshFacts()` when they open.
  The day Richard supplies scene data, fact checks start
  against it with no code change.

## Tests

`flutter_app/test/lie_detector_test.dart` (12 tests) +
one chain integration test in `danny_flagship_test.dart`.
Fixtures are written in the daemon config's "facts" shape
(SCENE_FORMAT.md) and parsed without ever reading `lie_text`,
mirroring the FFI facts view. Covered: supported claim with
the backing fact cited; contradicted claim with the clashing
fact and signal cited; self-contradiction by negation and by
changed numbers, with the earlier claim cited; another
speaker's record never incriminating; intra-statement
sequential contradiction; unverifiable claims honestly
reported; empty fact base (NO FACTS AVAILABLE, fact checks
idle, self-check still firing); credibility counts
accumulating per speaker; persistence round-trip (ledger and
self-check history intact after a re-boot, stored verdicts
kept not re-derived); `record: false` checking without
keeping. Danny's pre-existing discernment tests pass
unchanged (his readout now comes from the service).

Full verification at integration: cargo test 78/78,
flutter analyze clean (strict), flutter test 92/92,
`tools/release_gate.sh --suites` PASS.

## What this does NOT prove

- **It is not a polygraph and detects no deception
  directly.** A statement that contradicts nothing on record
  reads UNVERIFIABLE whether it is honest or not. It reads
  no body signals — no voice stress, micro-expression, or
  pulse analysis exists in this app or is implied anywhere.
- **The fact base is empty in the shipped configuration**
  (above). Until Richard supplies scene data, "SUPPORTED /
  CONTRADICTED vs the record" verdicts cannot occur in the
  shipped app; only self-contradiction verdicts and honest
  UNVERIFIABLEs can.
- **The self-contradiction check is a lexical heuristic.**
  It will miss contradictions phrased with different words,
  and can flag pairs that merely reuse numbers/negations in
  different senses. A flag is a pointer to inspect, not a
  finding of intent.
- **The credibility ledger covers the retained record**
  (most recent 200 statements), not a speaker's whole
  history, and it counts claim verdicts — nothing about a
  person beyond what those counts plainly say.
- **Not device-verified.** All results are VM test results;
  the APK remains blocked on the `other_tcp` permission, as
  with everything else in this project. Nothing published.
