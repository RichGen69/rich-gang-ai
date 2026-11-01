# Acquisition package — Rich Gang AI — 2026-11-01

**Packaged, not posted, not submitted, not sent to any buyer.**
This is a diligence bundle Richard can review, adopt, and then
use — or not use. Nothing in this file is a listing, and nothing
here replaces Richard's explicit final approval of the exact
copy and the exact build before any listing is posted.

## VERDICT — read this first

**Sell-out pitch as a finished, flagship, Hollywood-grade
product? NO — not ready.**

**Honest pre-revenue IP-and-code asset pitch at $50,000, with
full disclosures? YES — ready to present, with the updated
state below, to channels that do not require ID to list.**
Acquire.com itself is NOT currently available to Richard
(see Identity gate), so "ready" does not mean "ready on
Acquire." It means ready on Little Exits / Flippa (neutral
copy, adult-content risk noted) / PreRevMarket / SideProjectors,
or direct to a buyer who closes via escrow / P2P per the
recorded protocol — and only after Richard adopts the updated
counts in §3 and gives final approval.

Why the split verdict, in one paragraph: the code is real,
test-green in the VM, and honestly documented; the product is
not device-verified, not provider-verified, not age-verified,
and has no users, revenue, or APK. A buyer who is told the
first half without the second half has been misled. A buyer
who is told both halves can price a $50k pre-revenue codebase
fairly. That is the only pitch this package makes.

## 1. Deal — locked terms (Richard, 2026-10-22)

- **Ask: $50,000, IP and code ALONE, pre-revenue.**
  Seller's ask, not an appraisal. Future ladder rungs from
  Richard's prospectus ($110,000 at $2.5k MRR, $200,000+ at
  $5k+ MRR) are **future states that do not exist today** and
  are NOT part of this offer.
- **Included:** full source (Flutter/Dart app, Rust core,
  Kotlin service), product IP (characters, world, product
  names, registry, project artwork/portraits), HTML companion
  build, full documentation set, plus — clearly separated
  below — the standalone Rich Gang OS tree (§5).
- **NOT included:** seller's companies/legal entities,
  Stripe accounts or payment products, storefront or sales
  operations, social/media accounts, founder employment or
  services (no acqui-hire).
- **Financials: $0 revenue, $0 users, $0 subscriptions.**
  Solo founder, bootstrapped, launched October 2026, Texas.
- **Payout / closing (recorded, not re-decided here):**
  Acquire buyers would close via Acquire escrow (currently
  blocked, §6); direct buyers may close via the recorded P2P
  protocol (PayPal is the only rail verified to move $50k in
  one transaction; Cash App/Venmo/Zelle only in weekly
  tranches; no P2P handle is on record, so a direct close is
  not executable until Richard supplies one).

## 2. Pitch base — approved copy, and what is stale in it

Richard's standing pitch rule: **the corrected copy in
`docs/SALES_LISTING_DRAFT.md` is the ONLY approved pitch/post
copy.** This package does NOT invent new pitch copy. It quotes
that draft's headline and deal structure as the base, and then
flags — in §3, separately — every fact in it that is now stale.

Approved headline (verbatim, 2026-10-21/22 draft):
> "Pre-revenue multi-agent AI character platform — Flutter +
> Rust on-device core, provider failover to local Ollama,
> 9 fully configured characters (22 in registry) — original
> codebase, test-verified"

**That headline is now factually stale and must NOT be posted
as-is.** It says 9 configured / 22 in registry and cargo
43 / flutter 43. The current registry is 42, and the current
VM suites are cargo 93 / flutter 126 (§3). The 2026-10-23
PROPOSED corrections (`docs/SALES_LISTING_DRAFT_PROPOSED_
2026-10-23.md`, 10 configured / 23 in registry, cargo 78 /
flutter 101) are **also stale now, and still NOT approved**.
Adopting any updated headline is Richard's act alone. Until
he adopts one, the honest pitch is this package itself —
approved base + dated update — not a polished headline.

## 3. Verified state — re-checked 2026-11-01 (VM only)

Run today, in this VM, not copied from October:

- **Rust core: cargo test 93 passed, 0 failed.**
- **Flutter: flutter test 126 passed, 0 failed;
  flutter analyze: No issues found.**
- **Release gate: PASS** — staged `libdaemon.so`
  SHA-256 `c4574d11…` (new since the October `a8c41581…`
  build — another workstream changed the core/NativeBridge
  since 2026-10-30), 39 dynamic exports, all 35 Dart
  NativeBridge lookups resolve, LOAD Align 0x4000, ABI 2 = 2.
  Gate PASS proves the staged binary matches the current
  sources; it does NOT prove on-device behaviour.
- **Registry, counted from `characters.json` today:
  42 entries = 10 configured + 32 registry-only.**
  The 10 are the original nine (Dan, Rich, Crazy Kelly
  "The Neon Wildcard," Taurus; Freddy; Tammy "The Oracle";
  Sally; Leo; Capricorn; Aquarius) plus Danny, flagship lead,
  status `configured_voice_uncast`. The 32 are explicitly
  `registry_only_unconfigured` — no portraits, no voice
  casting, no affect tuning. They are configuration work,
  not finished characters, and must not be marketed as such.
- **Danny:** flagship 8-stage chain wired into 1:1 chat and
  Roundtable, bounded self-upgrade, accountability log /
  ledger, discernment vs daemon witness facts (no scene facts
  → NO FACTS AVAILABLE). **Voice honestly UNCAST** — all
  documented ElevenLabs premade voices are cast to the nine;
  no ID invented; system-TTS fallback with his delivery
  profile. Remaining item: Richard picks a real voice in his
  own ElevenLabs account.
- **Age assurance, current:** fail-closed (shipped
  2026-10-23 sweep) — with no verified vendor, ALL 21+
  characters are locked at Room, picker, chat send, call,
  Stage, and Roundtable. This supersedes the approved draft's
  "confirmation-only" line. A buyer must still pick/open a
  verified age-assurance provider, or exclude the 21+ cast.
- **Single store decision, locked 2026-10-30:** Rust rusqlite
  is the single conversation store; Room FTS5 stays parked
  and unwired. On-device inference, when spiked, is LiteRT-LM,
  not MediaPipe, and only after the APK builds and is
  device-verified. No model file is chosen or downloaded.

## 4. What is NOT verified — buyer must price this in

- **No APK exists.** No output directory at
  `flutter_app/build/app/outputs/flutter-apk/` as of today.
  Last attempt 2026-10-30: release gate PASS, then Gradle
  `assembleRelease` failed in 8s, "Could not dispatch a
  message to the daemon" — the VM `other_tcp` permission is
  still Deny. Fix is Richard's one settings change in the
  Muse web app (muse.ai → Settings → Permissions → Direct
  network protocols → other_tcp → Ask) + approving the Gradle
  card. A 20-minute silent retry job is still running.
- **No release keystore exists.** `keystore.properties` is
  absent. Release builds are designed to fail fast
  `signing_not_configured` with no debug fallback. Keystore
  creation is Richard's hands only (steps in
  `docs/SIGNING.md`; record alias + fingerprint only, never
  passwords).
- **Not device-verified.** Never run on a physical device
  (paired Galaxy A16, no on-device run ever). Cold open,
  chat, roundtable, voice, dream cycle, HUD — all VM-only.
- **No live provider verification.** NVIDIA/OpenAI/Gemini,
  ElevenLabs, Deepgram (Nova-3/Aura-2), LiveAvatar, LiveKit —
  clients built, keys are the buyer's own cost, **no live call
  has ever been verified** in this environment. Key presence
  is never verification. LiveAvatar IDs do not carry over
  from HeyGen IDs.
- **No local LLM runtime.** No bundled weights, no
  GGML/ONNX/WebGPU inference; edge_inference is an explicit-
  error boundary. The real offline path is Ollama on the
  user's own machine/network.
- **Security, open:** SEC-01 High — LiveKit secret on-device
  minting 6h tokens (needs server minting or Crew Link
  exclusion; server-side minting is the direction in the
  Tier 15 gateway contract, not a deployed fix). Vault /
  contracts are UNAUDITED (see §5).
- **Store / channel risk:** Google Play bars sexually
  gratifying content — a genuine risk to store launches with
  21+ companions. No Play/App Store presence is included.
  Direct APK distribution via Richard's own storefront is
  the channel implied by policy facts, not Google Play.
- **Sales copy is stale twice over:** the live Vercel
  storefront still shows old counts, and the approved draft
  itself is stale (§2). No redeploy or repost without
  Richard's adopt/reject decision on updated copy.
- **Publish gate: CLOSED.** `docs/PUBLISH_GATE.md` items for
  device, provider, roster, age assurance, claims, website,
  and final approval are not all passed. The $50k IP/code
  listing is the carved exception to that gate; a flagship
  product launch is not.

## 5. What else is in the tree — separated, not bundled as product

Buyers must not be sold the following as if they were the
shipped app. They are separate trees / proposals, included
in diligence for completeness:

- **Rich Gang OS (standalone, `~/workspace/rich_gang_os/`):**
  Rust Room control plane over local NATS/JetStream, Solidity
  vault + expansion contracts, Python voice worker, workflows
  with human approval. Re-checked 2026-11-01, in this VM:
  room 24/24, vault 43/43, contracts 32/32 (after a
  2026-10-30 audit-readiness fix to ArbitrageExecutor).
  Older counts (room 21/21, vault 39/39 on 2026-10-30) are
  superseded by today's runs. Voice 26/26, D8 19/19,
  workflows 13/13, pipelines 8/8 are 2026-10-30 figures,
  not re-run today.
  **NOT merged into the app, NOT deployed, NO real funds,
  NO live provider calls, UNAUDITED, key custody unproven
  (Privy TEE is a diagram label, not a system).** Persona
  register resolved 2026-10-30 as DUAL REGISTER (OS Danny
  operator / app Danny unfiltered, reversible on Richard's
  word).
- **NOT part of this package — whole-company buyout:**
  A whole-company proposal addressed to Michael Becker,
  received 2026-11-01, is **HELD, NOT SENT**, and is NOT
  adopted here. It conflicts with the locked deal in §1
  (IP and code alone, NOT companies/entities), with the
  approved-pitch-copy rule, and with the record that no
  formed entity/equity structure is established for a
  whole-company buyout. Do not pitch this package as a
  whole-company sale unless Richard explicitly changes the
  locked deal terms himself.
- **Tier 15 / Tier 18 expansion
  (`rich_gang_os/expansion_tier15_18/`):** premium menu,
  frontier router, UE5 photoreal, TEE/audit, sovereign edge,
  unified session — **proposal + scaffolds only, 2026-10-30.**
  Frontier/video model IDs in that bundle are UNVERIFIED;
  UE5 stream is UNAVAILABLE (no GPU host, no artist, no
  editor build in this VM); unified session tests 9/9 on
  doubles only. Do not present any of it as a running system.
- **UE5 Room scaffold (`~/workspace/rich_gang_room_ue5/`):**
  UE 5.4 project scaffold + client contract reporting
  UNAVAILABLE (3/3 tests). Not a stream.

## 6. Identity gate — why Acquire is blocked, and the routes that are not

- Richard's government ID **expired 02/15/2024**, past
  Texas's 2-year limit — it **cannot be renewed** online, by
  phone, or at all. Only path: a **NEW Texas ID application
  in person at a DPS office, by appointment** (nearest on
  record: Humble, 7710 Will Clayton Pkwy).
- Acquire.com: draft saved (33richchosen@gmail.com, draft
  ID `KgMbngNm2NPXHE6lv1Fx`, $50,000 ask), badge
  "Submitted," **NOT live**. Acquire emailed 2026-10-25
  01:10 CDT that it could not verify his ID and is unable
  to list the startup. Retrying with the same expired ID
  would fail again. Acquire's buyer preview also deviates
  from the approved draft (AI-composed headline/description,
  customers "<10" and churn "0-1% Stable" against zero
  users, Replika added as a competitor, website URL not
  shown) and cannot be corrected pre-verification.
- **Routes that do not require ID to list** (researched
  2026-10-22, re-state only — no new listing created here):
  Little Exits ($15 + 9.5% success, welcomes pre-revenue);
  Flippa (pre-revenue category, $49–$699 + 10% success,
  ID only at payment stage — **bars adult/overly sexual
  content, neutral copy mandatory**); PreRevMarket (free,
  pre-revenue); SideProjectors (free board). Every viable
  channel gates ID at closing/payout, not at listing —
  list now, new ID in parallel, ID needed only when a buyer
  funds escrow. Do not route around identity verification
  itself.
- **Shark Tank / YC are NOT part of this package:**
  Shark Tank Season 19 application was filled, never
  submitted (eligibility checkbox, signature, reCAPTCHA,
  Submit are Richard's alone); YC Winter 2027 is undecided
  and in tension with the $50k-for-100% buyout ask. Neither
  is pitched here.

## 7. Diligence pack — files a buyer can actually re-run / read

App tree (`~/workspace/rich_gang_ai/`):
`docs/SALES_LISTING_DRAFT.md` (approved base),
`docs/SALES_LISTING_DRAFT_PROPOSED_2026-10-23.md`
(PROPOSED, NOT APPROVED — stale, see §2),
`docs/CLAIMS_LEDGER_2026-10-23.md`,
`docs/PUBLISH_GATE.md`, `docs/SIGNING.md`,
`docs/FLAGSHIP_PROGRAM_2026-10-23.md`,
`docs/FLAGSHIP_SWEEP_2026-10-23.md`,
`docs/DANNY_FLAGSHIP_MODEL_2026-10-23.md`,
`docs/ROSTER_DISPOSITION_2026-10-23.md`,
`docs/SECURITY_REVIEW_2026-10-23.md`,
`docs/AGE_ASSURANCE_DESIGN_2026-10-23.md`,
`docs/ACQUISITION_CHANNELS.md`,
`tools/release_gate.sh` (run it after any core change,
before calling a build ready).

OS tree: `rich_gang_os/README.md`,
`rich_gang_os/RESUME_2026-10-30.md`,
`rich_gang_os/EXPANSION_REPORT.md`,
`rich_gang_os/contracts/AUDIT_READINESS.md`
(audit-readiness, NOT a professional audit),
`rich_gang_os/expansion_tier15_18/INTAKE_AND_AUDIT_2026-10-30.md`,
`rich_gang_os/expansion_tier15_18/all_four/README.md`,
`rich_gang_os/expansion_tier15_18/unified/UNIFIED_ARCHITECTURE.md`.

Re-run commands a buyer can use (VM, no keys needed):
`cargo test` in `rich_gang_ai_core` (93/93 on 2026-11-01),
`flutter test` + `flutter analyze` in `flutter_app`
(126/126 + clean on 2026-11-01),
`./tools/release_gate.sh` in `rich_gang_ai` (PASS on
2026-11-01, .so `c4574d11…`).

## 8. Next steps — in order, Richard's decisions only

1. **Adopt or reject updated copy.** Pick a headline that
   says 10 configured / 42 in registry, cargo 93 / flutter
   126, fail-closed age assurance, and no device/provider
   verification — or edit it yourself. Until then, do not
   post this package as a listing.
2. **Choose the channel.** Acquire is blocked until the new
   Texas ID exists. The ready-now routes are Little Exits /
   Flippa / PreRevMarket / SideProjectors, or a direct buyer
   — each stops at any fee or identity gate to report back.
3. **In parallel (does not block listing on a no-ID channel):
   new Texas ID application + DPS appointment; other_tcp →
   Ask + Gradle approval; keystore creation (alias +
   fingerprint only).** Any one of those succeeding makes
   the asset materially stronger and re-opens Acquire / a
   device-verified APK — but none is claimed here.
4. **Final approval.** Richard's explicit approval of the
   exact build hash (`.so c4574d11…` today — re-check on the
   day of listing, it changed between 2026-10-30 and
   2026-11-01), the exact roster, the exact provider set,
   and the exact copy, before anything is posted or sent.

---
*Package prepared 2026-11-01 from the approved draft, the
2026-10-23 claims ledger, and test runs actually executed
today. No buyer was contacted, no listing was submitted, no
fee was paid, and no claim in §4 was softened or dropped to
make the asset look ready.*
