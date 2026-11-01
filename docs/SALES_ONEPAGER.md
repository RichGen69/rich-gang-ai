# RICH GANG AI — THE ROOM · Buyer / Investor One-Pager

**Rich Gang AI Productions** · Founder: Richard Lambeth ("Agent Yeller,"
Base44 Builder #664,854 — seller's identifiers) · Prepared 2026-10-21
**Status: pre-revenue. Not published. This brief makes only verified claims.**

---

## What it is

A cinematic **multi-agent AI character platform**: a Flutter/Dart app with a
custom **Rust daemon core** (`libdaemon.so`, FFI/JNI), where a cast of
authored characters — each with personality, voice casting, an affect
engine, and a **persistent on-device mind** — hold one-to-one conversations
and agent-to-agent **roundtables with sequential context passing**.
Cloud AI providers (NVIDIA / OpenAI / Gemini, selectable) sit behind a
**circuit-breaker failover to a local Ollama path**, so a blocked or
rate-limited cloud account degrades the show to local instead of ending it.
A self-contained **HTML companion build** mirrors the cast and research
tools from the same character registry.

## What's verified (numbers, not adjectives)

| Fact | Evidence |
|---|---|
| Rust core test suite | **43 passed, 0 failed** (`cargo test`) |
| Flutter test suite | **43 passed, 0 failed** (`flutter test`) |
| Static analysis | **Clean** under strict casts/inference/raw-types |
| Fully configured characters | **9** (definition, portrait, voice, affect baseline) |
| Registry size | **22** characters (13 registry-only, labelled unconfigured in-app) |
| Rust library build | `libdaemon.so` aarch64/API 24 built, exports verified vs Dart/Kotlin lookups |
| Codebase honesty audit | Performed & documented — stubs and invented metrics removed or relabelled |

## The moat that IS real

- **On-device Rust core owns state** — daemon, dream-cycle memory
  consolidation, and character minds live on the device, not in a
  cloud wrapper. Rebuilding it is specialist work, not prompt assembly.
- **Provider-failover architecture** — circuit breaker (Closed/Open/
  HalfOpen, >250 ms latency = failure signal) across three cloud
  providers with a local Ollama fallback: the app is not hostage to
  any single AI vendor's credits, rate limits, or outages.
- **Character system with persistent minds** — affect (PAD + 24
  emotions), self-models (affinities, learned interests, reflections,
  open loops), roundtable relationships that evolve from actual
  exchanges, and registry-driven data so the cast expands by
  configuration, not rewrites.

## The honest gaps (priced into the conversation, not hidden)

- **Not device-verified; APK not yet packaged** — blocked on a
  one-step permissions fix in the seller's build VM, documented.
- **No provider verified live** — ElevenLabs, Deepgram (Nova-3/Aura-2),
  LiveAvatar, LiveKit clients are built; all need the operator's own
  keys and a live-call pass.
- **13 of 22 agents are registry-only** — no portraits, voices, or
  tuning yet. The Kelly character was renamed by the seller's decision
  on 2026-10-21 (Cougar Kelly → Crazy Kelly), confirmed final on
  2026-10-22 with Cougar dropped entirely; her title is now
  "The Neon Wildcard", zodiac Taurus — resolved. The Oracle
  overlap was resolved the same day: Tammy keeps "The Oracle";
  the registry-only entry is "The Oracle of Nocturna". No naming
  items remain open.
- **No local LLM weights** (offline = Ollama, not in-app inference),
  **no verified age assurance** (21+ gate is self-confirmation only),
  **no backend/accounts/billing/hosting** — SaaS, SDK, and Marketplace
  exist only as brand architecture documents.
- **No users, no revenue, no store presence.**

## The ask (seller's asking position — not an appraisal)

| State | Ask |
|---|---|
| **IP & codebase buyout, pre-revenue — current state** | **$50,000** |
| At $2.5k MRR (50–100 users) — future state | $110,000 |
| At $5k+ MRR — future state | $200,000+ |

Proposed consumer pricing to test (nobody has paid yet): Insider
$29/mo, Pro $59/mo, Crew $149/mo — arithmetically consistent with the
seller's own $2.5k-MRR-at-50–100-users scenario ($25–$50/user implied).
Full pricing logic and revenue paths: `docs/MONETIZATION_PLAN.md`.

## Diligence-ready file list

- `docs/TIER10_BUILD_2026-10-21.md` — build record & verdict (not ready to publish)
- `docs/FULL_STACK_MATRIX.md` — every feature, honestly statused
- `docs/PUBLISH_GATE.md` — pre-publish checklist (gate currently closed)
- `docs/VERIFY.md` · `docs/STATUS_M1-M3.md` · `docs/CHARACTER_AI.md` ·
  `docs/BUILD_*.md` — verification history, session by session
- `docs/SALES_LISTING_DRAFT.md` — full listing draft incl. "what's not included"

*Seller's standing rule for this asset: no mock data, no invented metrics,
no projections presented as fact. Anything in this brief can be re-run,
re-read, or pointed to in the repository.*
