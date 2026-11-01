# PAYOUT OPTIONS — Decision Record (2026-10-22)

Richard asked for alternatives to get paid out — crypto, P2P, or Wix —
and to pick the best option. Researched 2026-10-22; sources noted.
Standing rule applies: no invented terms; third-party summaries are
labelled as such and must be re-checked in the provider dashboard
before relying on them.

## The honest frame first

Every legitimate payout rail verifies identity before money moves to a
bank. Crypto does not remove that except in pure wallet-to-wallet
self-custody — which also removes escrow and buyer protection, the two
things that make a $50,000 stranger-deal closable. So the question is
not "how to skip verification" but "which verified rail is already
open, cheapest, and safest per deal size."

## What Richard already has (the asset most options would rebuild)

- **Stripe is already connected** (individual account, "Rich gang ai
  productions") with **payouts enabled**, both editions created and
  live payment links verified 2026-10-21: Cast Edition $19, Founder
  Edition $49. This rail already pays out to his bank.
- A public website on his Vercel account (built 2026-10-22).
- The Acquire.com listing in progress for the $50,000 IP sale.

## Options assessed

### 1. Stripe + optional USDC stablecoin payments — CHOSEN for product sales
- Stripe supports stablecoin (USDC) payments for US businesses:
  reported 1.5% fee, settles into the Stripe balance in local currency
  (no crypto on his books, no wallet to secure), no chargebacks.
  Source: stablecoininsider.org summary of Stripe's own docs/pricing,
  searched 2026-10-22 — **verify in his Stripe Dashboard before
  relying on it.**
- Reported limit: **$10,000 per transaction** — fine for the $19/$49
  editions and proposed subscriptions; NOT usable for the $50,000 IP
  sale in one payment.
- Enablement (Richard's click): Stripe Dashboard → Settings →
  Payments → enable stablecoin / USDC payments on the existing
  account and payment links.
- Verdict: **best option for everything except the IP closing** —
  already set up, buyer can pay by card or USDC, seller receives USD.

### 2. Acquire escrow — CHOSEN for the $50,000 IP closing (Acquire-sourced buyer)
- Acquire closings run through their escrow flow; identity
  verification at payout is part of it and is what makes a buyer
  willing to send $50,000. There is no legitimate way to keep
  Acquire's buyers and skip Acquire's closing rules, and taking an
  Acquire-sourced buyer off-platform to dodge platform terms/fees is
  not advised.
- Verdict: keep the listing; do the one-time verification when a
  buyer is actually at the table, not before.

### 3. Direct sale (buyers from Richard's own outreach/site, not Acquire)
- Structure: signed Asset Purchase Agreement + licensed escrow or
  attorney-held closing; payment by wire, or by **USDC to Richard's
  own wallet** if the buyer prefers crypto.
- Crypto safety rules if used: USDC only (no volatile coins at this
  size); wallet address delivered inside the signed documents, never
  published on the website (public addresses invite substitution
  scams); small test transaction first; agreed confirmation count
  before code handover; sale is taxable income — keep the invoice,
  agreement, and transaction hash for records.
- Needs from Richard, only when a direct buyer exists: his receiving
  wallet address (for the crypto variant) and his signature on the
  agreement. Nothing to set up in advance.
- Verdict: **the correct "alternative payout" for the IP** — ready on
  demand, no standing accounts or fees.

### 4. Coinbase Commerce / Coinbase Business — rejected as a workaround
- Coinbase Commerce was transitioned into **Coinbase Business**
  (merchant migration deadline March 31, 2026, per Coinbase Help):
  custodial, US + Singapore only, and it requires **full Coinbase
  Business account verification** — i.e., the same identity
  verification, plus a new account, for a 1% fee. It solves nothing
  that Stripe's USDC option doesn't already solve on an account he
  already has. (Sources: Coinbase Help migration page and 2026
  comparisons, searched 2026-10-22.)

### 5. P2P marketplaces / raw P2P crypto — REJECTED for the IP sale
- Irreversible payments, no escrow discipline, high scam exposure on
  both sides, and no serious buyer pays $50,000 for code P2P without
  protection. Fine for small trusted deals; wrong instrument here.

### 6. Wix — rejected
- Wix Payments requires its own full identity/business verification
  and payout setup, and a Wix store would duplicate what he already
  has live (Stripe payment links + his own website). More accounts,
  same verification, no advantage.

## Decision (implemented 2026-10-22)

1. **Product money** (editions now, subscriptions later): Stripe —
   already live. Optional Richard action: enable USDC in the Stripe
   Dashboard so crypto-paying buyers settle as USD.
2. **IP money via Acquire**: platform escrow, verification at closing.
3. **IP money direct**: APA + escrow closing, wire or USDC-to-wallet
   under the safety rules above.
4. Website updated with a "Payment & closing" section stating these
   routes publicly (no wallet address published).

## Richard's remaining actions (only when relevant)

- [ ] Optional, any time: Stripe Dashboard → Settings → Payments →
      turn on stablecoin (USDC) payments.
- [ ] When an Acquire buyer reaches closing: complete Acquire's
      identity/payout verification (one-time).
- [ ] When a direct buyer exists: provide a receiving wallet address
      if he wants the USDC variant, and sign the purchase agreement.

## OVERRIDE — 2026-10-22 (Richard, explicit, supersedes the P2P rejection above)

Richard directed: "Use P2P for the $50k IP sale too — override the
earlier call." P2P is therefore an ACCEPTED payment route for the
$50,000 IP & code sale **from direct buyers** (his own outreach,
site, social — any buyer who did not come through Acquire).

What the override does NOT change:
- **Acquire-sourced buyers still close through Acquire's escrow.**
  Moving an Acquire buyer off-platform would breach Acquire's terms;
  this is a platform rule, not a preference, so it stands.
- **Stripe remains the product-sales rail** for the $19/$49 editions
  (Cash App Pay is already enabled inside it).
- The original risk findings (irreversibility, no buyer protection,
  scam exposure) remain factually true; the closing protocol in
  `docs/P2P_CLOSING.md` is how they are managed, not denied.

Rail reality for a $50,000 P2P closing (researched 2026-10-22;
third-party reporting except where PayPal's own help page is the
source — confirm the exact figure inside the app before relying on
it):
- **PayPal — the only single-transaction route.** PayPal's own help
  page: a verified account can send up to $60,000 in ONE transaction,
  though PayPal may cap a given transaction at $10,000 and may hold
  large payments for review. Both sides should be verified.
- **Cash App — receiving is fine, sending is the bottleneck.**
  Verified accounts: receiving unlimited, sending ~$7,500/week
  (some sources report higher tiers). Unverified receiving is
  capped at $1,000 per 30 days — an unverified account cannot take
  this payment at all.
- **Venmo — weekly chunks.** Person-to-person moves at roughly
  $4,999.99 per transaction/week for verified accounts (sources
  conflict on a higher combined weekly spending figure); transfers
  out to a bank cap at $19,999.99/week. $50k = many weeks.
- **Zelle — not a closing rail at this size.** Bank-set limits,
  typically $500–$3,500/day and $10,000–$20,000/month.
- Verification note: the higher tiers on Cash App/Venmo are gated on
  identity verification inside those apps — separate from Acquire's
  Persona check, but Richard's expired ID may still bite there.

## Crypto activation — status check 2026-10-22 (Richard: "Get paid in crypto")

Checked live via the Stripe connector on the individual account
(acct_1U697PL9PUQAvOYg), all three payment method configurations:
**crypto `available: false`, display preference `off`** on every
configuration (card, Link, and Cash App are available and on). This
is an eligibility state set by Stripe — it cannot be switched on
through the API from here. The unblock is Richard's own action in
the Stripe Dashboard (Settings → Payments → stablecoin payments),
where eligibility is granted or requested. Reported terms (third-
party summary of Stripe docs, verify in Dashboard): 1.5% fee,
settles to the Stripe balance as USD, ~$10,000 per-transaction cap —
editions yes, single-shot $50k closing no.

The other crypto leg needs no Stripe: USDC to Richard's own
self-custody wallet for a direct $50k closing, under the safety
rules in the direct-sale section above (USDC only, address only
inside signed documents, never published, test transaction first).
That leg is blocked on Richard having a wallet and supplying the
receive ADDRESS only — a seed phrase or private key is never to be
shared with anyone, including Muse.
