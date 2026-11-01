# SALES LISTING DRAFT — Acquire.com-style (DRAFT — NOT LISTED)

**Status: SUBMITTED to Acquire.com 2026-10-22 (seller decision: push
as far as possible without ID verification). Listing badge:
"Submitted"; approval is hard-gated on Persona ID verification,
which the seller cannot complete — dialog closed unstarted.
Note: the live listing's headline/description are AI-composed by
Acquire's builder (fact-consistent with this draft), the website
URL is not displayed, and no editor is reachable pre-verification;
this file remains the verbatim source of truth.**
Prepared 2026-10-21 from the verified Tier-10 build record
(`docs/TIER10_BUILD_2026-10-21.md`, `docs/FULL_STACK_MATRIX.md`).
Every claim below is either a verified build fact, a clearly labelled
work-in-progress state, or Richard's asking position (marked
**Seller's ask**). Publishing this listing is subject to Richard's
explicit final approval under `docs/PUBLISH_GATE.md`.

Pricing/label conventions: **Seller's ask** = the seller's asking
position, not an appraisal. Technical counts are from the seller's
recorded test runs in the build documentation, re-runnable by the buyer.

---

## Deal structure (Richard, 2026-10-22)

Asset sale of the **IP and code alone**. Included: full source
code (Flutter/Dart app, Rust core, Kotlin service), the product IP
(characters, world, product names, 22-entry registry, project
artwork/portraits), the HTML companion build, and the full
documentation set. NOT included: the seller's companies/legal
entities, Stripe accounts or payment products, the storefront or
any sales operations, social/media accounts, and the founder's
employment or services (no acqui-hire).

## Headline

**Pre-revenue multi-agent AI character platform — Flutter + Rust
on-device core, provider failover to local Ollama, 9 fully configured
characters (22 in registry) — original codebase, test-verified**

("Tier-10" is the project's internal build designation for this
codebase's current milestone. It is a project label, not an industry
certification or a measured performance tier, and is not used as a
performance claim anywhere in this listing.)

## Summary

THE ROOM, by Rich Gang AI Productions (founder: Richard Lambeth,
developer call sign "Agent Yeller," Base44 Builder #664,854 — seller's
own identifiers), is a cinematic multi-agent AI character application:

- A **Flutter/Dart application** (Android-first) with a **custom Rust
  daemon core** (`libdaemon.so`, FFI ABI 2, JNI bridge to a Kotlin
  foreground service with 15-minute dream-consolidation cycles).
- A **character system, not nine chatbots**: each fully configured
  character carries a authored definition — personality, speech style,
  affect baseline (PAD model with 24-emotion engine), voice casting —
  plus a **persistent on-device mind**: affect state, a self-model
  (affinities, learned interests, reflections, open loops) and
  interaction history that are restored across sessions.
- **Agent-to-agent roundtable** with sequential context passing: later
  speakers receive earlier speakers' actual lines, with structured
  reasoning steps (draft / critique / revise) rather than isolated
  one-shot replies.
- **Provider failover architecture**: cloud providers (NVIDIA, OpenAI,
  Gemini — selectable in Settings) with a **circuit-breaker pattern**
  (3-state Closed/Open/HalfOpen; latency over 250 ms treated as a
  failure signal) falling back to a **local Ollama** path so the app
  keeps working when a cloud account is blocked, rate-limited, or
  unreachable. Note precisely what this is: the fallback is a routing
  decision to a local Ollama server — it is **not** in-app local LLM
  weights (see "What's not included").
- **Voice & video clients built** (not yet live-verified — see below):
  ElevenLabs TTS with a system-TTS fallback that is labelled as such in
  the UI, Deepgram client (Nova-3 STT + Aura-2 TTS), LiveAvatar
  streaming-video integration (the current production successor to
  HeyGen streaming; built from its official OpenAPI), LiveKit client
  with on-device JWT minting, hands-free speech input.
- A **self-contained HTML companion build** (~2.7 MB, regenerated from
  the same character registry as the app) presenting the cast,
  roundtable setup, a real 3D stage (demo model, labelled as a demo),
  and live Wikipedia-backed research lookup.

## What's verified (evidence in the repo)

- Rust core: **`cargo test` 43 passed, 0 failed** — including 8 circuit
  breaker tests, 6 ring-buffer tests, 5 watchdog heartbeat/stale-
  detection tests, and 3 tests asserting the edge-inference module
  returns explicit errors instead of fabricating responses.
- Flutter: **`flutter test` 43 passed, 0 failed**; **`flutter analyze`
  clean** under permanently enforced strict options
  (strict-casts/inference/raw-types).
- `libdaemon.so` built for aarch64-linux-android (NDK r27, API 24),
  exports verified against the Dart and Kotlin lookups that consume
  them.
- Registry integrity is test-asserted: the daemon's persona list in
  `daemon_config.json` matches `characters.json` exactly.
- A codebase-wide **no-mock audit** was performed and is documented:
  canned stub replies, invented telemetry numbers, and hash functions
  mislabelled as semantic embeddings were removed or relabelled.
  Remaining placeholders in the product are labelled as such in the UI.
- Full documentation set included: build records per session, a
  feature-by-feature completeness matrix with honest statuses
  (Built+Verified / Wired+Unverified / Registry-Only / Not-Built),
  and a publish-gate checklist — all in `docs/`.

## The roster — stated exactly

- **9 characters fully configured**: authored definitions, portraits,
  voice casting, affect baselines.
- **22 characters in the registry**: the 9 above plus 13 expansion
  characters present as registry entries (name, role, zodiac/celestial
  assignment, universe where the seller specified one). The 13 have
  **no portraits, no voice casting, and no affect tuning** — the app
  and website label them "REGISTRY ONLY — UNCONFIGURED." They are
  configuration work for the buyer or seller, not finished characters.
- Naming items, stated exactly: the Kelly character is **Crazy
  Kelly** — the seller renamed her on 2026-10-21 (Cougar Kelly →
  Crazy Kelly) and confirmed the decision on 2026-10-22, dropping
  Cougar Kelly from the roster entirely. Her final title is
  "The Neon Wildcard" and her zodiac is Taurus (both fixes
  applied and test-asserted in the shipped roster on 2026-10-22,
  so no character shares a zodiac or the "Wildcard" name). The
  second naming overlap was likewise resolved on 2026-10-22:
  Tammy (fully configured) keeps the title "The Oracle", and the
  registry-only Nocturna entry is named "The Oracle of Nocturna"
  — no two characters in the 22 share a name, and no
  registry-only name repeats a configured character's title
  (test-asserted). No naming items remain open.

## What's not included / what a buyer must do

Read this before valuing the asset — it is the honest other half of
the listing:

- **Pre-revenue.** No users, no subscriptions, no revenue, no analytics.
  This is a codebase/IP sale, not a business with a track record.
- **Not device-verified.** The current build has not run on a physical
  device. The APK build itself is currently blocked in the seller's
  build VM by a permissions setting (a one-step settings change by the
  seller, documented in the build record); the compiled Rust library
  builds and is staged, but the packaged APK and on-device behaviour
  are unverified.
- **Bring your own keys.** Every AI/voice/video provider (NVIDIA,
  OpenAI, Gemini, ElevenLabs, Deepgram, LiveAvatar/HeyGen) requires
  the buyer's own account and API keys, at the buyer's cost. Clients
  for these services are built and unit-tested where applicable;
  **no provider has been verified with a live call**, because no keys
  exist in the seller's build environment. Key presence in the app is
  never represented as verification.
- **No local LLM runtime.** There are no bundled/memory-mapped model
  weights and no GGML/ONNX/WebGPU inference in the app. The Rust
  edge-inference module is an explicit-error boundary today; the real
  offline path is Ollama on the user's own machine/device network.
- **Age assurance is confirmation-only.** 21+-flagged characters sit
  behind a user self-confirmation ("I am 21+") stored as a local flag.
  There is no ID verification, biometric, or JWT age assurance.
  Marketing or monetising 21+ features requires implementing real
  age assurance and checking app-store/payment-processor policy —
  app-store rules on sexual/companion content are a genuine channel
  risk for any store launch.
- **No backend, accounts, or billing.** There is no FastAPI/React
  stack (the seller's earlier speculative snippets describe a second,
  unbuilt stack — not part of this sale's codebase), no user accounts,
  no auth, no hosting, no subscription infrastructure, no SDK,
  marketplace, or enterprise product. Brand names for those exist as
  the seller's architecture documents only.
- **No availability/performance guarantees.** No uptime, failover
  latency benchmarks, or SLA figures exist for this codebase, and
  none are claimed in this listing.
- **No store presence.** No Play Store / App Store listings, developer
  accounts, or approvals are included.
- **Configuring the 13 registry-only agents** (portraits, voices,
  affect tuning), supplying any interrogation "scene" content, and
  resolving the two naming items above are buyer's (or pre-sale
  seller's) work, listed in the build documentation.
- **Third-party licences & assets:** the codebase builds on Flutter,
  Rust crates, and provider SDK/APIs under their own licences/terms;
  the bundled 3D demo model is a third-party demo asset, labelled as
  such, and is not a product character.

## Why the seller believes it's worth the ask (seller's position)

The seller's position — labelled as such — is that the replacement
cost is the anchor: a custom Rust daemon core, a circuit-breaker
provider-failover router, a persistent-mind character engine, a
multi-agent roundtable, and a 22-entry character registry with full
build documentation is, in the seller's estimate, months of specialist
engineering. That estimate is the seller's own (see the seller's
prospectus in the diligence pack), not an independent appraisal, and
buyers should price the asset against the verified state above —
in particular: green test suites and honest docs on one side; no
device verification, no live provider verification, and no revenue
on the other.

## Asking price (Seller's ask)

The seller's asking ladder, from his own prospectus, with the state
each rung assumes:

| Asset state | Seller's ask |
|---|---|
| **IP & codebase buyout — pre-revenue, as documented here (current state)** | **$50,000** |
| Live commercial launch at $2.5k MRR (50–100 users) — *future state, not current* | $110,000 |
| $5k+ MRR with active traction — *future state, not current* | $200,000+ |

Only the first rung describes this listing. The other two are the
seller's stated asks for future states that do not exist today, and
are included only so the seller's full position is on the table.

## Diligence pack (available on request, seller-approved)

- `docs/TIER10_BUILD_2026-10-21.md` — full build record: verified
  counts, failures found & fixed, gated items, verdict.
- `docs/FULL_STACK_MATRIX.md` — every feature/claim with an honest
  status.
- `docs/PUBLISH_GATE.md` — the seller's own pre-publish checklist
  (currently: gate closed).
- `docs/VERIFY.md`, `docs/STATUS_M1-M3.md`, `docs/CHARACTER_AI.md`,
  `docs/BUILD_*.md` — session-by-session verification history.
- `docs/MONETIZATION_PLAN.md` — revenue paths, proposed pricing
  labelled as proposals, and channel/compliance risks.

---

*Draft prepared with seller's standing rule applied: no mock claims,
no invented metrics, no projections presented as fact. Final listing
text requires the seller's explicit approval before any use.*
