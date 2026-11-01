# SALES COPY REFRESH — PROPOSED DELTA (2026-10-27)

**PROPOSED — NOT APPROVED. This file is NOT the approved pitch
copy and must not be posted, pitched, or sent anywhere. The
approved copy remains `docs/SALES_LISTING_DRAFT.md` (Richard's
standing pitch rule). Adopting any of this into the approved copy
or redeploying the live site is Richard's act alone.**

This delta supersedes the 2026-10-23 proposal
(`docs/SALES_LISTING_DRAFT_PROPOSED_2026-10-23.md`), which is
itself now stale: it still says a 23-entry registry and
101 Flutter tests, both overtaken by the 2026-10-25 WTF Zone
merge and Danny's Roundtable wiring.

## What the live site still says (checked 2026-10-27)

From `site/index.html` (the live Vercel page's source in this repo):

- Rust core tests: **43 passed, 0 failed**
- Flutter tests: **43 passed, 0 failed**
- Characters: **9 fully configured — 22 in the registry**
- Age assurance for 21+ characters: **self-confirmation only today**

Crazy Kelly does read "The Neon Wildcard" live — that scrub
landed. Only the counts, test numbers, and age-assurance line
below are stale.

## Verified replacement numbers

- **Registry: 42 entries** — verified 2026-10-27 by reading
  `flutter_app/assets/characters.json` directly: 42 entries in
  the `characters` array.
- **Configured: 10** — the same file shows 10 entries carrying
  a portrait and an affect baseline; the other 32 carry status
  `registry_only_unconfigured`. So: **10 configured — 42 in
  the registry** (10 + 32 = 42).
- **Danny still voice-uncast** — one of the 10 configured
  carries status `configured_voice_uncast`; the other nine
  carry voice casting. This matches the 2026-10-23 proposal's
  wording and has not changed.
- **Test counts (last verified run, NOT re-run 2026-10-27):**
  cargo **78/78** and Flutter **112/112**, per the 2026-10-25
  records (`docs/DANNY_ROUNDTABLE_INTEGRATION_2026-10-25.md`
  and `docs/WTF_ZONE_MULTIVERSE_ROSTER_2026-10-25.md`).
  **Re-run both suites and confirm these numbers in front of
  Richard before any redeploy** — do not publish them on the
  strength of this delta alone.
- **Age assurance (unchanged since the 2026-10-23 proposal):**
  21+ characters are locked behind a fail-closed age-assurance
  boundary with no verification vendor configured, so they are
  inaccessible until a real method is implemented — replacing
  the live site's "self-confirmation only" line.

## Additional roster fact since the 2026-10-23 proposal

`characters.json` now carries a `chain_of_command` section
(6 entries): Richard as creator, founder, and human approval;
Agent Rich commanding the cast day to day; every agent also
working for Richard directly. If the sales copy mentions
governance at all, that is the accurate form — not a
hierarchy that routes approval through Rich.

## What still needs Richard, and only Richard

1. Adopt, reject, or edit this delta (counts + age-assurance
   line only; nothing else in the approved copy changes).
2. If adopted, a redeploy of the live site — with the test
   suites re-run and the numbers re-verified in front of him.
3. The Acquire listing cannot be edited pre-verification, so
   this touches the live site and future pitch copy only.
