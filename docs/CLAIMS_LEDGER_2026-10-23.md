# CLAIMS LEDGER — commercial artefacts vs evidence (2026-10-23)

Every claim found in the current commercial artefacts, mapped to
its evidence or marked **DELETE** / **CORRECT**. Artefacts swept:
`docs/SALES_LISTING_DRAFT.md` (approved copy — this ledger does
NOT edit it; corrections are proposed in
`docs/SALES_LISTING_DRAFT_PROPOSED_2026-10-23.md`),
`docs/SALES_ONEPAGER.md`, `html_build/store.html` (the live
storefront page), `docs/PROSPECTUS_RICHARD_SUPPLIED.md` (Richard's
supplied marketing position — claims there are his position, not
verified fact, and must never be quoted as verified).

## Stale facts — CORRECT (facts moved; framing unchanged)

| Claim as written | Where | Truth today |
|---|---|---|
| "22-entry registry" / "22 characters in the registry" / "22 in registry" | Listing draft (several), one-pager, store.html | **23 entries** (Danny promoted to the roster lead 2026-10-23) |
| "9 fully configured characters" as the whole configured story | Listing draft, one-pager | **10 configured**: the nine voice-cast + Danny `configured_voice_uncast` (portrait + baselines wired, voice UNCAST — must be stated plainly wherever Danny is counted) |
| "13 registry-only / expansion" as the remainder of 22 | Listing draft, one-pager | 13 registry-only — of **23** |
| `cargo test` 43 passed | Listing draft, one-pager | **78 passed** (pre-sweep settled state; re-measured at sweep close-out) |
| `flutter test` 43 passed | Listing draft, one-pager | **101 passed** at sweep close-out 2026-10-23 (69 settled pre-sweep + 13 lie-detector integration + 19 sweep tests), measured in `docs/FLAGSHIP_SWEEP_2026-10-23.md` |
| "Every future portrait drop for the extended 22-character registry" (Founder Edition perk) | store.html | Registry is 23; also a forward promise about unbuilt work — correct the count, and the perk must not promise drops for characters whose promotion is undecided (see Roster Disposition) |
| "the 9 above plus 13 expansion" arithmetic | Listing draft | 10 + 13 = 23 |

## False / unverifiable claims — DELETE wherever they appear

These originate in the user-supplied Tier-10 prospectus and
pasted specs. Each was audited against the code and found not
built, not measured, or contradicted (`docs/PUBLISH_GATE.md`,
`docs/FULL_STACK_MATRIX.md`, `docs/TIER10_BUILD_2026-10-21.md`).
None may appear in any listing, store, or pitch copy:

| Claim | Why it goes |
|---|---|
| "sub-5 ms failover" (any latency benchmark) | No such measurement exists. The real breaker trips on a >250 ms latency *signal*; no failover latency has ever been benchmarked. |
| "99.9999% availability" / "zero downtime" | No monitoring, SLA, or uptime measurement exists. |
| "Memory-mapped GGML/ONNX/WebGPU weights" / local frontier weights in-app | No local LLM runtime is linked; `edge_inference` returns explicit errors. Offline = Ollama, stated in the honest copy. |
| "Hardware JWT age assurance" / any "verified 21+ age gate" wording | Not built. The shipped gate was a self-confirmation boolean; as of this sweep the app locks 21+ characters behind a fail-closed boundary with **no vendor configured** — the honest claim is the lock, not a verification. (The listing draft's own disclosure — "There is no ID verification, biometric, or JWT age assurance" — is correct and stays.) |
| "22 fully-configured agents" (and any "N fully-configured" variant above the true configured count) | False at every count: 9 configured when written; 10 now, one of them voice-uncast. |
| Deepgram "Nova-2" (prospectus: "Deepgram Nova-2 (STT)") | The built client is **Nova-3 STT + Aura-2 TTS**; it also has **no production caller** in this build — any copy implying live Deepgram speech pipelines is doubly wrong. |
| "Ultra-low latency WebRTC streaming pipelines" (prospectus) | LiveAvatar/LiveKit clients are built but never live-verified; no latency figure exists. |
| Tier-10 valuations as fact ($110k / $200k+ rungs) | Richard's asking position in his prospectus, not appraisals; the only verified ask is the $50,000 IP-and-code sale on his instruction. |

## Claims verified — KEEP (evidence named)

| Claim | Evidence |
|---|---|
| $50,000 ask, IP + code alone (asset sale; not companies/accounts/operations) | Richard's locked instruction, mirrored on Acquire + Shark Tank packet |
| Pre-revenue, $0 financials, 0 users | Stated in the approved draft's disclosures; nothing contradicts it |
| Flutter/Dart + Rust single stack; no FastAPI/React in the sale | Codebase itself; pitch rule record |
| Character system: affect (PAD + 24 emotions), self-models, roundtable, dream cycles | VM test suites (cargo/flutter) + `docs/CHARACTER_AI.md` |
| Providers wired, none verified live; keys are the buyer's/operator's | Draft disclosure; no live call has been made in this environment |
| Storefront editions Cast $19 / Founder $49, Stripe links live | Verified live 2026-10-22 (storefront + both buy links HTTP 200) |
| "86 tests passed" (Acquire's AI-polished variant, 43+43 at submission) | Was arithmetically true at submission; superseded by current counts above |

## Sweep note

The approved draft was NOT edited (standing rule). All
corrections above are carried in the separate PROPOSED draft;
adopting any of them into the approved copy is Richard's act.
The live storefront still shows the stale "22-character
registry" line until he approves a redeploy with corrected copy.
