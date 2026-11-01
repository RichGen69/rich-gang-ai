# Chain of command — written into the roster

Ordered by Richard in the 2026-10-25 exchange, in his own words across
four messages: the cast works for Agent Rich; Rich works for Richard;
all of them work for Richard directly too; Richard is the human
approval; Richard is the creator and founder of Rich Gang AI and of
Rich Gang AI Productions.

## Where it lives

`flutter_app/assets/characters.json`, top-level `chain_of_command`
block (written 2026-10-25):

- `ordered_by`: Richard
- `ordered`: 2026-10-25
- `founder`: Richard is the creator and founder of Rich Gang AI and of
  Rich Gang AI Productions.
- `human_approval`: Richard is the human approval — the final human
  sign-off for the gang's actions.
- `day_to_day_commander`: Chosen One Rich (Agent Rich), The Host and
  Swarm Commander, commands the cast day to day inside The Room.
- `reporting`: Richard is the ultimate boss of every agent. Rich works
  for Richard, and every agent works for Richard directly too — Rich
  does not stand between Richard and any agent.

Chosen One Rich (`id: rich`, "The Host", Aries) also carries the chain
in his `core` text, so the Room's host states it in character, not
only in metadata. The other 41 entries do not repeat it in their cores;
the top-level block is the single roster-level statement, and repeating
it 42 times would bloat the cores and invite drift.

## What it does NOT change

- The app code does not read the `chain_of_command` block: the roster
  loader parses only the `characters` list, so the block is inert
  metadata (verified: it parses and the loader ignores unknown
  top-level keys). Nothing in the Roundtable, Danny's chain, or the
  Lie Detector changes behaviour on the basis of this block.
- Danny's core still says Richard is "the Boss" who built them, with
  Danny's loyalty running to him first — consistent with this chain,
  not superseded by it.
- This is a roster record, not a permission change: it does not grant
  any agent new authority, and Richard's human-approval gates
  (publish gate, OS HumanApproval layers) are unchanged.

## Verification (resumed and test-locked 2026-11-01)

- Baseline before the lock: flutter test 126/126, analyze clean.
- New test in `flutter_app/test/roster_asset_test.dart`:
  "chain of command (ordered 2026-10-25) is written into the roster"
  — locks every field of the block and Rich's core text.
- After the lock: flutter test **127/127**, flutter analyze **no
  issues**.
- Still open, separate offers Richard has not tapped: installing the
  2026-10-25 Rich poster upload as Rich's shipped portrait (current
  portrait remains the 616×410 cast-grid crop at
  `assets/images/portraits/rich.jpg`).
