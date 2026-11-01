# AGE ASSURANCE DESIGN — Rich Gang AI 21+ characters

Date: 2026-10-23 (Flagship Tranche 1, P7 preparation).
Status: **DESIGN ONLY.** No vendor was selected, no account was
opened, no code was changed. Richard chooses the method/provider
(or the exclusion alternative in §7); that choice is a named
Richard-only blocker in the flagship program.

## 1. Current state — what exists today, exactly

Age-gated characters: **Crazy Kelly** (configured), **Shawna** and
**Ruby** (registry-only). The gate flag is `CharacterDef.ageGated`
from `characters.json`.

The current mechanism (`AgeGate` in
`flutter_app/lib/views/character_ui.dart`):

- a dialog asks the user to tap **“I am 21+ — continue”**;
- success writes one global boolean, `age_21_confirmed`, to
  SharedPreferences;
- `AgeGate.isConfirmed()` reads that boolean. No date of birth is
  collected, no document is checked, no third party verifies
  anything, and the boolean is not bound to a person, account, or
  character.

**This is a confirmation notice, not verified age assurance.**
The publish gate says so explicitly, and this design exists to
replace it as the assurance mechanism. (It may remain afterwards
only as an additional content notice.)

### Current enforcement points — and the gaps between them

| Surface | Code path | Behaviour today | Gap |
|---|---|---|---|
| Room cast card | `the_room.dart` → `CharacterChatView` | Card shows a “21+” label; tapping opens chat, which checks asynchronously | The character's name/title/portrait are visible before any check |
| Character picker | `character_picker.dart` → `CharacterChatView` | Trailing “21+” label only; tap opens chat | Same as above |
| Chat | `character_chat_view.dart` `initState` → `AgeGate.confirm`; denied → view pops | Check runs **after** the view is created; `_send` has **no explicit granted-state guard** — sending depends on the view having popped | A retained/rebuilt view or a race must never be able to send unconfirmed |
| Roundtable | `roundtable_view.dart` `_start` | If the cast contains a gated character and confirmation is absent, it asks; on denial the gated character is removed from the cast | Strongest current pattern — keep this shape |
| Video call | `AvatarCallView` (opened from chat app bar) | **No `AgeGate` call at all** | Direct gap: reachability depends entirely on having passed through chat first |
| 3D Stage | `AvatarStageView` (Room action, or chat with `initialCharacterId`) | **No `AgeGate` call at all** | Direct gap, including the chat→stage route for a gated character |
| Deep link / future routes | none exist yet | No central authorisation object exists to consult | Any new route must go through the §3 boundary, not a new ad-hoc check |

One wording defect found during this design pass:
`character_agent.dart`'s system prompt describes a gated character
as “behind a verified 21+ age gate.” That is **not true today**
and the wording must be corrected when this design is implemented
(or sooner): until §6's matrix passes, the prompt copy may say at
most “behind a 21+ age gate.”

## 2. Design goals (from Flagship Program P7.1)

1. Use a **real verification method** from a named provider or a
   platform mechanism Richard selects.
2. **Minimum data:** state exactly what the vendor receives, what
   the app receives back (a verification result/token — not a copy
   of a date of birth or document unless the chosen method truly
   requires it), what is stored, where, and for how long.
3. **Binding:** clearing ordinary preferences must not silently
   mint a verified adult; reinstall / app-data-clear behaviour is
   designed and tested, never accidental.
4. **Gate before exposure** on every surface in §3.
5. **Fail closed:** denial, vendor outage, and offline state all
   leave gated characters blocked, with the state shown honestly
   and a retry path.
6. **No identity logging:** verification events may be recorded
   (timestamp, character/surface, outcome) without logging identity
   documents, images, or secrets.

## 3. Target architecture — one authorisation boundary

Replace the scattered `AgeGate` calls with a single
`AgeAssurance` service that every surface consults **before** a
gated character is rendered interactively or messaged:

```
enum AgeAssuranceState {
  unknown,          // never verified on this install
  verificationRequired,
  pending,          // vendor flow in progress
  verifiedAdult,    // vendor result: 21+ confirmed
  denied,           // vendor result: not confirmed 21+
  unavailable,      // vendor unreachable / offline — fail closed
}

abstract class AgeAssurance {
  Future<AgeAssuranceState> state();
  Future<AgeAssuranceState> verify();       // runs the vendor flow
  Future<bool> isAuthorised(String characterId); // false unless verifiedAdult
  Future<void> reset();                     // user/vendor-driven revocation
}
```

Enforcement contract:

- **Character-level check, not global-flag check.** Surfaces call
  `isAuthorised(characterId)` for any `ageGated` character before:
  opening chat (and the chat composer stays disabled until it
  returns true), adding the character to a Roundtable cast,
  opening the call view, opening Stage with that character, and
  following any future route/deep link that names a character.
- **Metadata minimalism before verification:** until authorised,
  Room/picker surfaces may show at most the gated character's
  existence in the registry sense the product chooses (name +
  “21+ — verification required”), and must not open chat, voice,
  call, or stage. Whether even the portrait is shown pre-verification
  is a Richard policy choice recorded at implementation.
- **Denial is sticky and honest:** `denied` shows the denial state
  and the vendor's own retry/appeal route if one exists; the app
  never offers “tap to confirm instead” as a bypass.
- **Outage ≠ open:** `unavailable` renders a “verification
  unavailable — 21+ characters are locked” state with Retry.
- **No silent downgrade:** if the vendor SDK/flow errors, the
  state is `unavailable`, never `verifiedAdult`.

## 4. Token / state storage design (vendor-neutral)

What the app stores after a successful verification — and nothing
more:

- `verification_state`: the enum value above;
- `verified_at`: timestamp of the vendor's positive result;
- `vendor_id`: which method/provider produced the result;
- `vendor_reference`: an opaque vendor token/reference the vendor
  itself defines for re-validation, **if** the vendor issues one.
  This is the only vendor artefact the app keeps.

Storage and binding rules:

- Store the record in the app's private storage with the same
  discipline as other sensitive local state; **exclude it from
  Android Auto Backup / device-transfer rules** (see the security
  review, SEC-07) so a verification cannot silently travel to a
  different device/person. If the chosen vendor binds verification
  to an account instead, the account binding — not a copied local
  flag — is the source of truth, and restore behaviour follows the
  vendor's re-authentication.
- **App-data clear / uninstall:** the local record is gone; the
  user re-verifies on the new install. This behaviour is stated in
  the UI copy and tested in §6.
- **Ordinary preference clears** (for example a future “reset
  preferences” action) must not delete or create a verification;
  reset-my-data (security review SEC-07) treats verification as
  its own class: it is revoked only by the explicit `reset()` path
  or by data clear, and the UI says which happened.
- **Expiry / re-check:** if the vendor issues time-limited
  results, `isAuthorised` re-validates after expiry and returns to
  `verificationRequired`. If the vendor's result is non-expiring,
  that fact is recorded in the implementation note — not assumed.
- **Never stored:** date of birth, document numbers, document or
  selfie images, or any vendor secret/API key beyond the existing
  `SecureKeys` discipline. Vendor API credentials, if the method
  needs them, follow SEC-01's lesson: no server-class secret ships
  in the client; the vendor flow must be designed so the client
  holds at most a publishable client identifier, with verification
  results delivered through the vendor's signed/tokenised channel.

## 5. Vendor flow (generic — no provider chosen)

1. User selects a gated character → surface calls
   `isAuthorised` → state is not `verifiedAdult`.
2. Surface renders the locked state and a **Verify age** action
   naming the method in plain language (for example, “Verify with
   <provider> — you'll be taken to their secure flow”).
3. The vendor flow runs (hosted page / SDK — per the chosen
   vendor's documented integration, verified against the vendor's
   own docs at implementation time, never from memory).
4. The app receives the vendor's result through the vendor's
   documented callback/token mechanism and records §4's record.
   A result the app cannot validate is treated as `unavailable`,
   not as success.
5. On `verifiedAdult`, the surface re-checks `isAuthorised` and
   unlocks. On `denied` / `unavailable`, it stays locked with the
   honest state shown.

What the vendor receives is **method-specific and must be filled
in at selection time** — this design deliberately does not guess
a provider's data terms. The P7 evidence bundle cannot close
until that row exists for the chosen method: data sent, data
returned, retention (vendor-side and app-side), cost/account
owner, and the denial/appeal behaviour.

## 6. Acceptance test matrix (all on the A16, frozen candidate)

From Flagship Program P7.1, restated against the §3 boundary:

- **Unverified:** every surface (Room card action, picker, chat
  incl. composer, Roundtable cast, call, Stage, any route/deep
  link) blocks the gated character **before** gated interaction.
- **Denied verification:** still blocked everywhere; denial state
  shown; no confirmation-dialog bypass exists.
- **Verified:** gated character unlocks on every in-scope surface.
- **Vendor unreachable / offline:** still blocked (fail closed),
  with the unavailable state shown.
- **App-data clear / reinstall:** behaviour matches §4 exactly
  (local record gone → re-verify).
- **Backup/restore:** a restored install does **not** arrive
  verified (per §4's exclusion), and the run sheet proves it.
- **Registry-only gated entries (Shawna, Ruby):** remain
  unpromoted and unmarketed regardless of verification state.
- **Prompt wording:** no surface or prompt claims a “verified”
  gate before this matrix passes (fixes the §1 wording defect).

## 7. The exclusion alternative (Richard's decision)

If Richard does not adopt a verified method:

- all 21+ characters (Crazy Kelly; Shawna; Ruby) are **excluded
  from flagship access and marketing**: not merely unlabelled —
  inaccessible in the flagship build, with the exclusion recorded
  as their P3/P7 disposition; **or the flagship does not ship.**
- The current confirmation dialog may survive only as an
  additional content notice inside a build that has real
  verification — never as the assurance mechanism, and never as a
  way to keep a 21+ character in a flagship build without one.

## 8. Implementation sequence (when Richard chooses)

1. Richard selects the method/provider (or chooses §7) and opens
   the vendor account — his step; data terms recorded into §5's
   row before code is written.
2. Implement `AgeAssurance` + the §4 record; rewire every §1
   surface to the boundary; delete the global-boolean path (the
   dialog copy may be reused as a notice, the flag may not).
3. Correct the `character_agent.dart` “verified” wording to match
   reality at each step.
4. Unit/widget tests for the state machine and for denied /
   unavailable / direct-navigation cases per surface.
5. A16 matrix run (§6) on the frozen candidate; evidence into the
   P7 bundle; security review §7 item 10 closes only then.

**Nothing in this document is implemented yet.** It is the design
the implementation will be judged against.
