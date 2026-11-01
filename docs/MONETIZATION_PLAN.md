# MONETIZATION PLAN — Rich Gang AI / THE ROOM

Created 2026-10-21, from the Tier-10 build record (`docs/TIER10_BUILD_2026-10-21.md`,
`docs/PUBLISH_GATE.md`, `docs/FULL_STACK_MATRIX.md`).

**Status this plan is built on: pre-revenue. Zero users, zero revenue, zero live
provider verification. Verdict of the Tier-10 build: NOT READY TO PUBLISH.**

## Number-labelling rule (Richard's standing rule, applied to money)

Every number in this document is one of three kinds, and is labelled as such:

- **(A) Richard's supplied asking position** — figures from
  `docs/PROSPECTUS_RICHARD_SUPPLIED.md`. These are Richard's ask, not an
  appraisal, not a valuation opinion, and not verified market data.
- **(B) Proposed price to test** — a price nobody has paid yet. It is a
  hypothesis to validate with real buyers, not a fact about demand.
- **(C) Arithmetic from stated assumptions** — `users × price` multiplication.
  Arithmetic is exact; the assumptions behind it are not forecasts.

No market-size figures, conversion rates, churn rates, or revenue projections
are presented anywhere in this plan, because none have been measured.

---

## 1. Revenue paths, ranked by realistic time-to-first-dollar from the current state

Ranking logic: fewest unmet blockers between today and a first legitimate
payment, given the verified state (tests green in the VM, APK not built, app
not device-verified, no keys verified live, publish gate closed).

### Path 1 — IP / codebase sale (fastest plausible first dollar)

**Channels:** Acquire.com, Flippa, or private outreach to micro-PE firms and
indie acquirers.

**Why first:** a code-asset sale does not require the APK to build, the app to
be published, users to exist, or payments infrastructure to exist. The buyer
buys the codebase, the character system, the architecture, and the build
documentation as they are — sold honestly as pre-revenue.

**Blockers (all currently open):**
- No listing account exists (Richard must create and identity-verify it — see §4).
- The publish gate (`docs/PUBLISH_GATE.md`) governs *marketing claims*, and
  Richard's standing instruction is elite-grade before publish. A listing that
  uses only verified claims (see `docs/SALES_LISTING_DRAFT.md`) is the honest
  route; whether to list before the full gate passes is **Richard's explicit
  decision**, not assumed here.
- Buyer diligence will test the codebase (see §2.3). Anything in the listing
  that diligence contradicts damages the sale; the draft listing is written
  to survive diligence.
- The unresolved Kelly naming conflict and the Tammy / "The Oracle" title
  overlap (see `docs/TIER10_BUILD_2026-10-21.md`) should be resolved or
  disclosed; a buyer will find them in the registry.

### Path 2 — Paid private beta / founder's licensing cohort

**Shape:** a small, manually onboarded cohort. Richard delivers the build
personally (direct APK distribution to the buyer's own devices, or the HTML
companion package), the buyer supplies their own provider API keys, onboarding
is done by hand. No app store, no automated payments backend, no hosting
required — payment can be a Stripe Payment Link once Richard connects Stripe
(see §4).

**Why second:** it produces real users and real willingness-to-pay evidence —
the single thing that most changes what Path 1 or Path 4 can honestly claim —
without needing store approval.

**Blockers (currently open):**
- The APK does not build in this VM until Richard changes the `other_tcp`
  permission (his setting, Muse Settings → Permissions → Direct network
  protocols) and the build is device-verified on his A16. Direct distribution
  of an unverified APK to paying users is not a product, it's a liability.
- Buyers need their own provider keys (NVIDIA/OpenAI/Gemini, ElevenLabs, etc.)
  or their own Ollama install — this must be in the offer in plain language.
- 21+ characters must stay behind an honest disclosure: the age gate is
  confirmation-only (see §5). Do not sell 21+ access as "verified."
- No support/refund process exists yet; for a handful of founder users that
  can be Richard personally, stated up front.

### Path 3 — Direct-license desktop/web package

**Shape:** licence the self-contained HTML build (regenerated from the final
registry, ~2.7 MB local file today) and/or a packaged desktop distribution,
sold directly (Stripe Payment Link / Gumroad-style storefront under Richard's
own accounts).

**Why third:** the HTML build exists and is verified as a local file, but it
is a companion surface — its doc states honestly that live agent brains run
in the Android app. Selling it as "the full app" would be a false claim.
It becomes sellable as a standalone package only when what it actually does
standalone is the offer, or when it ships alongside the verified APK.

**Blockers:** final-registry regeneration + verification per the publish
gate's Website section; a licence text (none exists); a delivery/refund
mechanism under Richard's accounts; same provider-key disclosure as Path 2.

### Path 4 — SaaS subscriptions (later — infrastructure does not exist yet)

**Shape:** hosted accounts, subscriptions at proposed tiers (§2.1).

**Why later:** none of the required machinery exists. Per
`docs/FULL_STACK_MATRIX.md`: no user accounts, no auth, no ACCOUNT console,
no billing, no hosting, no FastAPI/React backend (a second stack Richard has
not decided to commission). Building SaaS means building all of that first,
plus real age assurance before any paid tier touches 21+ features (§5).

**Blockers:** hosting + backend decision, auth, Stripe subscription setup
(Richard's account), verified age assurance, provider-key economics (if
Richard hosts inference, the provider bills are his — no cost figures are
claimed in this plan because no usage has been measured).

### Path 5 — Enterprise private-deployment licensing (later)

**Shape:** a business pays to deploy the system privately (their environment,
their keys, their perimeter).

**Why later:** enterprise buyers run security review. The honest current
answers — no security/privacy review completed, no tamper-evident audit
chain, no hardware attestation, no verified age assurance, nothing
device-verified — are disqualifying until the publish gate's security item
passes and device verification exists. The publish gate lists exactly the
items an enterprise reviewer will ask about.

**Blockers:** publish gate Security/privacy review item; device verification;
a support/SLA story (none exists; no availability claim may be made — there
is no measurement behind any uptime number).

### Path 6 — SDK / Marketplace (last — brand architecture only)

Per the matrix, Rich Gang AI SDK, Studio, Cloud, Marketplace, and Enterprise
are **brand architecture only**: no SDK package, no marketplace, no listings
infrastructure exists. There is nothing to sell on this path today. It is
kept in the plan only so it is not silently forgotten; it becomes a real path
only after Paths 1–4 produce something an SDK would wrap.

---

## 2. Proposed pricing (all (B) — proposals to test, unless marked (A) or (C))

### 2.1 Consumer subscription tiers (for Path 4, and as the cohort's post-beta price test in Path 2)

| Tier | Proposed price (B) | Intended scope (proposal) |
|---|---|---|
| Insider | $29 / user / month | Core Room: chat + roundtable with the fully configured cast, on the buyer's own provider keys |
| Pro | $59 / user / month | Insider + voice (ElevenLabs, buyer's key), priority feature access |
| Crew | $149 / user / month | Pro + multi-seat / whole-cast sessions, earliest access to newly configured agents |

**Consistency check against Richard's own prospectus math (C):** the
prospectus's SaaS scenario is $2,500 MRR at 50–100 users, which implies
$2,500 ÷ 100 = $25/user/month at 100 users and $2,500 ÷ 50 = $50/user/month
at 50 users. The proposed Insider/Pro prices ($29 / $59) bracket that
implied range, so the tiers are arithmetically consistent with Richard's own
scenario — they are still untested prices, not validated demand.

**Founder lifetime deal (B):** a one-time **$499** founder licence,
Insider-equivalent scope, offered to a capped founding cohort. Cap proposed
at 25 seats. Maximum gross if the cap sold out (C): 25 × $499 = **$12,475** —
that is multiplication, not a projection that 25 buyers exist.

**Paid private-beta licence (B, for Path 2):** **$299 one-time per seat** for
the founder's cohort, manual onboarding included. A 10-seat cohort at that
price (C): 10 × $299 = **$2,990**.

### 2.2 IP sale ask ladder (A) — Richard's supplied asking position

From `docs/PROSPECTUS_RICHARD_SUPPLIED.md`, labelled as the ask:

| Asset state (Richard's framing) | Asking price (A) |
|---|---|
| IP & codebase buyout, pre-revenue / raw technical asset | **$50,000** (stated range $35,000–$75,000) |
| Live commercial launch at $2.5k MRR (50–100 users) | **$110,000** (stated range $90,000–$135,000) |
| Scaled, $5k+ MRR with active traction | **$200,000+** (stated range $180,000–$250,000+) |

The second and third rungs are conditional on MRR that **does not exist
today**. Today's honest rung is the first: a pre-revenue asset at Richard's
$50,000 ask. The prospectus's R&D-replacement justification ($100,000+ /
6–9 months) is also Richard's supplied position, not an independent estimate,
and is labelled that way in all sales copy.

### 2.3 What a buyer's diligence check will test (so the ask survives it)

Expect a buyer (or their technical reviewer) to, at minimum:

- Run `cargo test` and `flutter test` — today: **43/43 and 43/43, analyze
  clean** (Tier-10 build record). This is the strongest verified fact in
  the sale.
- Read the code for stubs/mocks — the codebase was audited under Richard's
  no-mock rule; the Tier-10 modules return explicit errors instead of fake
  responses, and the build doc says so. Diligence-friendly.
- Try to build the APK — **will fail in this VM** until Richard's `other_tcp`
  permission change; disclose it, with the one-step fix, before they find it.
- Ask which agents are finished — honest answer: **9 fully configured,
  13 registry-only**. Any copy implying 22 finished agents fails diligence.
- Ask what runs without Richard's accounts — answer: buyers need **their
  own** provider keys; no key has been verified live yet.
- Ask about the 21+ features — honest answer: confirmation-only age gate,
  not verified age assurance (see §5). A buyer acquiring adult-adjacent
  features acquires that gap too; disclose, don't bury.
- Ask for users/revenue — honest answer: **none; pre-revenue**. The sale is
  an asset sale, not a revenue multiple, at today's rung.

### 2.4 Scenario table — scenarios from stated assumptions, not forecasts

**(C) Arithmetic only.** Each cell is `paying users × tier price`. No cell is
a prediction; there are currently **0 users**. ARR = MRR × 12, shown for
framing only.

| Paying users | Insider $29/mo → MRR (ARR) | Pro $59/mo → MRR (ARR) | Crew $149/mo → MRR (ARR) |
|---|---|---|---|
| 10 | $290 ($3,480) | $590 ($7,080) | $1,490 ($17,880) |
| 50 | $1,450 ($17,400) | $2,950 ($35,400) | $7,450 ($89,400) |
| 100 | $2,900 ($34,800) | $5,900 ($70,800) | $14,900 ($178,800) |
| 500 | $14,500 ($174,000) | $29,500 ($354,000) | $74,500 ($894,000) |

Reading note: the prospectus's $2.5k-MRR scenario (A) sits between the
50-user Pro cell ($2,950) and the 100-user Insider cell ($2,900) in this
table — the proposed tiers reproduce Richard's scenario arithmetic at
roughly the user counts he stated. That is consistency, not validation.

---

## 3–4. Payments & accounts: what Richard must supply

### Stripe — checked 2026-10-21

- The Stripe connector doc (`/opt/hatch/connectors/stripe/CONNECTOR.md`)
  describes an OAuth connection to **Richard's own Stripe merchant
  account**; no API keys are ever collected in chat.
- **Status check run 2026-10-21 (`/opt/hatch/bin/stripe status`, read-only):
  `not_connected` — Stripe is NOT connected.** No products, prices, payment
  links, or charges were created, and none may be created until Richard
  connects his account.
- **What Richard must do to enable payments:**
  1. Have (or create) a Stripe account in his own name/business, with his
     own tax and banking details — Muse cannot supply or enter these.
  2. Connect it via the connector's authorize flow when prompted (Muse
     can provide the connect link; the sign-in is Richard's).
  3. After connection, Muse can help create Products/Prices/Payment Links
     for the §2 tiers **with Richard's approval per action** (connector
     writes ask for approval operation by operation).
- Until Stripe is connected, Paths 2–4 can only be *priced*, not *charged*.
  Path 1 (marketplace sale) settles through the marketplace's own escrow/
  payment rails, not Richard's Stripe.

### Acquire.com / Flippa — what Richard must supply

- An account in Richard's name, identity/KYC verification by Richard,
  and his own payout/banking details with the platform.
- Final approval of the exact listing text (the publish gate's Final
  Approval item applies to any listing based on
  `docs/SALES_LISTING_DRAFT.md`).
- A decision on whether to list before the remaining publish-gate items
  (APK build + device verification) pass — listing early with the corrected,
  verified-claims-only copy is possible on some marketplaces, but it is
  Richard's call against his own elite-grade-before-publish rule, and this
  plan does not make it for him.

### Store accounts (only when Paths 4–5 or a store launch are pursued)

- Google Play / Apple developer accounts in Richard's name, his fees,
  his identity verification. None exist via Muse; none were created.

---

## 5. Compliance & channel risks that affect money

These are risks to verify before taking money, not legal advice and not
cleared items.

1. **App-store policy vs 21+ companion content.** The app includes a
   21+-gated companion character (the Kelly character — naming conflict
   unresolved — plus Shawna and Ruby flagged 21+ in the registry).
   - Google Play's Inappropriate Content policy states it does not allow
     apps that "contain or promote sexual content or profanity," including
     content "intended to be sexually gratifying"
     (Google Play Developer Policy, Inappropriate Content — Sexual content
     and profanity: https://support.google.com/googleplay/android-developer/answer/9878810?hl=en-GB).
     A romantic-companion feature marketed to stores is squarely in the
     territory this policy governs. **Channel consequence:** the 21+
     companion positioning may make a Play Store consumer launch
     unviable regardless of age rating; direct distribution (Path 2/3)
     avoids store review but not law, and store copy must never market
     what the store build can't contain.
   - Apple publishes age ratings where the top band covers apps with
     "sexual content, nudity" among other frequent/intense content
     (Apple, Age Ratings: https://apps.apple.com/cv/story/id1440847896),
     and its App Review Guidelines separately govern sexual/objectionable
     content and user-generated/AI content — **to be verified in full
     against the current guidelines before any iOS submission is costed
     or promised.** No iOS build exists today in any case.
2. **Confirmation-only age gate is insufficient for paid 21+ features.**
   The current gate is a user tapping "I am 21+", stored as a local flag
   (Tier-10 build record). It is not ID verification, not biometric, not
   any recognised age-assurance method. Charging money for access gated
   this way creates regulatory and payment-processor risk in multiple
   jurisdictions and would not survive an enterprise or marketplace
   diligence question. Until real age assurance exists, sales copy must
   describe the gate exactly as it is, and paid positioning should lead
   with the non-21+ cast and capabilities.
3. **Third-party API dependency = the buyer's costs and keys.** The product
   routes to NVIDIA/OpenAI/Gemini and (unverified live) ElevenLabs,
   Deepgram, LiveAvatar, plus local Ollama. A buyer or licensee needs
   their own accounts and keys and bears their own usage costs. Any
   licence/sale must state this; "it just works" is false. No provider
   cost figures are quoted in this plan — none have been measured.
4. **Pre-revenue honesty.** There are no users and no revenue. The asset
   must be sold as pre-revenue (Path 1, first rung). Presenting scenario
   arithmetic (§2.4) as a track record, or the prospectus's higher rungs
   as current value, would be misrepresentation and is prohibited by
   Richard's standing rule.
5. **Unresolved roster IP/identity items.** The Kelly naming conflict,
   the Tammy / "The Oracle" title overlap, and 13 unconfigured agents are
   product-truth issues that become money issues the moment copy is
   written. Resolve or disclose (see §1, Path 1) — §2 copy in the listing
   draft already discloses them.
6. **Processor policy risk.** Payment processors (including Stripe) have
   their own restricted-business rules covering adult content. Whether a
   21+-companion-positioned business can process consumer subscriptions
   is **to be verified with the processor before Path 4 pricing is
   promised to anyone.** Another reason Path 1 (asset sale via marketplace
   rails) ranks first: it does not depend on Richard's processor account
   accepting this category.

---

## 6. 30 / 60 / 90-day action sequence

"Someday" is not in this table; every item has an owner.

### Days 0–30 — unblock and prepare to sell the asset

**Muse can do:**
- Keep `docs/SALES_LISTING_DRAFT.md` and `docs/SALES_ONEPAGER.md` in sync
  with the build docs after any new verification (e.g. after device tests).
- Draft private-outreach variants of the listing for micro-PE / indie
  acquirers (same verified claims, shorter form) — drafts only, nothing sent.
- Prepare the diligence pack index (build doc, matrix, VERIFY docs,
  publish gate) as a single shareable bundle when Richard approves sharing.
- Draft founder-cohort offer copy for Path 2 using only verified claims.

**Richard must do:**
- Change the VM `other_tcp` permission to Ask (Muse Settings →
  Permissions → Direct network protocols) and approve the Gradle card, so
  the APK can build at all.
- Resolve the Kelly naming conflict and the Tammy / "The Oracle" overlap,
  or explicitly accept disclosing both.
- Decide: list the IP now with corrected copy, or hold until device
  verification (his publish-gate rule — his call, recorded either way).
- Decide the stack question (Flutter/Rust single stack vs commissioning a
  separate FastAPI/React backend) — it affects what a buyer is buying.

**External accounts needed:**
- Acquire.com and/or Flippa seller account (Richard, with KYC + payout
  details) — required before Path 1 can receive a dollar.

### Days 31–60 — first revenue attempt

**Muse can do:**
- After the APK builds: run the device-verification checklist with Richard
  (publish gate, Build & device section) and update the listing/one-pager
  with the results — pass or fail, as measured.
- Verify provider keys live (Richard pastes keys in-app; Muse guides the
  live-call checks and records which providers actually answered).
- Once Stripe is connected *by Richard*, draft (not publish without
  approval) the Products/Prices/Payment Links for the §2.1/§2.4 prices.

**Richard must do:**
- Install and exercise the APK on his A16 (device verification is his
  device, his hands).
- Connect Stripe (his account, his tax/banking, OAuth sign-in).
- Paste his provider keys in Settings and confirm ElevenLabs voice IDs in
  his own account; supply LiveAvatar key + per-character avatar IDs if
  video is to be part of any paid offer.
- Approve the final listing text and press "list" himself, or approve
  Muse preparing everything up to that step.

**External accounts needed:**
- Stripe (Richard's merchant account, connected per above).
- Provider accounts (NVIDIA/OpenAI/Gemini/ElevenLabs/Deepgram/LiveAvatar)
  in Richard's name for live verification.

### Days 61–90 — cohort or closing

**Muse can do:**
- Support Path 2 onboarding materials: buyer key-setup guide, honest
  capability sheet (from the matrix), cohort licence draft text for
  Richard's review (not legal advice — Richard should have counsel
  review any licence before use).
- If an IP buyer engages: assemble diligence answers strictly from the
  build docs, and draft responses to buyer questions for Richard's
  approval before anything is sent.
- Re-run the publish-gate checklist and report the updated gate status.

**Richard must do:**
- Decide founder-cohort size and who is invited; personally onboard the
  first users.
- Casting decisions for any of the 13 registry-only agents he wants in a
  paid offer (portraits, voice casting, or keep them excluded from copy).
- Supply scene data if interrogation content is part of a paid offer.
- Give (or withhold) final approval for any public listing, store
  submission, or licence signature.

**External accounts needed:**
- Only if Richard chooses Path 4 groundwork in this window: store
  developer accounts and any hosting account — all in his name.

---

## Bottom line

The fastest honest dollar is **Path 1 (asset sale at Richard's (A) $50,000
pre-revenue ask, with the corrected listing)** or **Path 2 (a small founder
cohort at the (B) proposed prices)** once the APK builds and is
device-verified. Subscriptions, enterprise, and SDK/marketplace revenue are
real paths only after infrastructure and verification that do not exist
yet. Nothing in this plan is published, listed, or charged — every external
step above is gated on Richard's accounts and Richard's explicit approval,
per `docs/PUBLISH_GATE.md`.
