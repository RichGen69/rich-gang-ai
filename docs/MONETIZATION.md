# Rich Gang AI — Monetization plan (2026-10-21)

Richard's order: monetize BEFORE publishing. The public publish is
held until a payment rail is live. Everything below that does not
need Richard's accounts is DONE; the rail choice + account step is
his (one tap + a sign-in).

## What's sellable TODAY (honest inventory)

- The interactive HTML edition (The Room, cast dossiers, Roundtable
  planner, real 3D stage demo, live Deep Seek) — one self-contained
  file, works in any modern browser.
- The Hollywood art pack: cast poster + 9 character portraits.
- Founder status: first in line for Android early access WHEN the
  verified app ships (in final build verification; no date
  promised — the APK is still gated on the `other_tcp` permission
  fix + device verification, see BUILD_FULL_2026-10-21.md).
- NOT sellable yet: the Android app itself, live agent conversation
  as a service, LiveAvatar/ElevenLabs-powered features (need keys
  and per-unit costs — a subscription product later, not now).

## Editions and pricing

| Edition | Price | Includes |
|---|---|---|
| Cast Edition | $19 one-time | HTML edition + art pack, personal license |
| Founder Edition | $49 one-time | Cast + Android early-access priority + all future registry portrait drops + founder status |

Product bundle (built, ready to upload):
`release/rich-gang-ai-founder-edition.zip` (2.8 MB, 13 files:
the HTML edition, art_pack/ with poster + 9 portraits, README,
LICENSE). Storefront draft: `html_build/store.html` — checkout
buttons ship DISABLED ("CHECKOUT OPENS AT LAUNCH") until a real
payment link is pasted into its CHECKOUT CONFIG comment; no fake
checkout, per Richard's no-mock rule.

## The rails (fees retrieved from 2026 pricing sources)

| Rail | Fee per sale | You net on $19 | You net on $49 | Tax/VAT | File delivery |
|---|---|---|---|---|---|
| Stripe Payment Links | 2.9% + $0.30 | $18.15 | $47.28 | You handle it | You handle it |
| Lemon Squeezy (MoR) | 5% + $0.50, processing incl. | $17.55 | $46.05 | Handled | Built in |
| Gumroad direct (MoR) | 10% + $0.50 + ~2.9% + $0.30 | ≈$15.75 | ≈$41.88 | Handled | Built in |
| Gumroad Discover | 30% flat | ≈$13.30 | ≈$34.30 | Handled | Built in + their audience |

Recommendation: **Lemon Squeezy** for this product (near-Stripe
margin, merchant-of-record tax handling, native file delivery).
**Gumroad** if Discover traffic matters more than margin (note:
$100 minimum payout reported in 2026 sources). **Stripe** as the
long-term Rich Gang AI Productions rail (invoicing, bigger deals,
the acquisition track) — connect it either way; use it for
Payment Links once delivery is arranged.

Stripe status (2026-10-21, updated late): CONNECTED. Two live
accounts existed; at Richard's direction the INDIVIDUAL account
("Rich gang ai productions") is the selling account — it is the
only one with payouts enabled. The Inc./Atlas account can charge
but payouts are DISABLED until its Atlas onboarding is finished
(company tax_id/EIN, CEO/president + secretary persons, company
physical address, TOS acceptance) — migrate products there once
complete. Created on the individual account (all live):
- Cast Edition: product prod_VUCt4oiW6iyIZO, price
  price_1UTEU9L9PUQAvOYg8LbKKjWo ($19), payment link
  plink_1UTEVEL9PUQAvOYgmOWVD8q2 —
  https://buy.stripe.com/cNi8wQ2FC8uxajL732bbG08
- Founder Edition: product prod_VUCtao3HmQEVXf, price
  price_1UTEUFL9PUQAvOYg4yRoF2zC ($49), payment link
  plink_1UTEVKL9PUQAvOYgoX7HpQgx —
  https://buy.stripe.com/bJe8wQeokbGJdvXafebbG09
Both products carry tax code txcd_10202000 (Downloadable Software
— personal use); Managed Payments is on, so Stripe is the tax
liability holder (automatic_tax enabled on the links) — that
removes the earlier "you handle tax" downside of this rail.
Delivery on this rail is MANUAL: after each Stripe sale email,
Richard emails the buyer the ZIP (the links' confirmation messages
promise exactly that). Storefront PUBLISHED 2026-10-21 (wired with
the Stripe buttons): https://muse.ai/files/1344595072074533/1137525258841468/n9hpiokt83f71gx7328a6n4h/store.html
— Muse file links expire (this one 2026-10-24 ~00:25 CDT); the
Stripe buy links do not expire. PERMANENT STOREFRONT HOME DONE
2026-10-22: the store page now also lives on Richard's Vercel
project at
https://rich-gang-ai-33richchosen-6537s-projects.vercel.app/store.html
(deployment dpl_C3UxyYNmew9XmrqdvuddjiKouE3r, READY/production,
verified live: HTTP 200, both Stripe buy links present, Kelly's
final title "The Neon Wildcard" on the page). Mirror source:
`site/store.html` + `site/assets/store_*.jpg`, generated from the
canonical `html_build/store.html` by `site/build_store_mirror.py`
(images externalized/recompressed — the connector's argument-size
limit cannot carry the 1.16 MB single file; copy is identical).
The Muse link remains as a backup until it expires. Lemon
Squeezy + Gumroad: kits ready, accounts still Richard's to open.

## Listing copy (ready to paste)

**Title:** Rich Gang AI — THE ROOM: Founder Edition

**Tagline:** Different minds. Same room.

**Description:** Nine configured AI agents. One boardroom. The
Freak Show AI cast — Dan the Universal Operator, Chosen One Rich,
Crazy Kelly the Neon Wildcard, Freddy, Tammy the Oracle, Sally the
Unhinged Tech, Leo, Capricorn, Aquarius — in a cinematic
interactive edition that runs in your browser: full dossiers, the
Roundtable planner, a working 3D stage, live Deep Seek, and the
Hollywood portrait pack. Created by Richard Perry Lambeth Jr.,
Rich Gang AI Productions.

**Bullets:**
- One file, any modern browser — no install, no account
- 9 configured agents with full character files + 13-entry registry
- Real 3D stage (glTF) with real animation clips
- Live Deep Seek (real Wikipedia lookups)
- Print-quality cast poster + 9 Hollywood portraits
- Founder Edition: Android early-access priority when the verified
  app ships + all future registry portrait drops

**Refund policy (suggested):** 14 days, email us, made right.

**FAQ:** use the storefront's Straight Answers section verbatim —
it already discloses the app's status honestly.

## Decision (2026-10-21, Richard): ALL THREE RAILS

Richard chose all of the above. Paste-ready listing kits are built
in `release/listing_kits/` (lemonsqueezy.md, gumroad.md, stripe.md
+ cover art). Status at decision time: Stripe still not connected;
Lemon Squeezy and Gumroad accounts not yet created — all three are
Richard's-hands steps (business/payout/identity). The moment any
rail is live, its links get wired into the storefront; publish
follows once the rails he activates are wired.

## Launch checklist

1. [x] Richard picks a rail — ALL THREE (2026-10-21).
2. [ ] Account step: connect Stripe (link above) or sign up at the
       chosen platform (his business + payout info — his hands only).
3. [ ] Create the two products ($19 / $49) on the rail; upload
       `release/rich-gang-ai-founder-edition.zip` as the deliverable
       (Gumroad/Lemon Squeezy) or set the Stripe Payment Link
       success flow.
4. [ ] Paste the payment links into `html_build/store.html`
       CHECKOUT CONFIG, enable the buttons, regenerate.
5. [ ] THEN publish: upload the wired storefront to the public
       link and announce. (The full HTML edition is NEVER the
       public free link — it's the paid deliverable.)
6. [ ] Announce where his audience is; log the launch in
       docs/CHARACTER_AI.md and MEMORY.md.

## Later money (not now, noted so it isn't promised early)

- Android app paid launch / Play Store — after APK + device
  verification.
- Subscription tier once LiveAvatar/ElevenLabs keys exist (real
  per-minute costs need a recurring price to cover them).
- Licensing/acquisition via Rich Gang AI Productions (Richard's
  existing outreach track).
