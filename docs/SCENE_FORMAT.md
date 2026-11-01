# Interrogation Scene Format — supply your own scene data

The interrogation mode ships with **no built-in scene** (removed
2026-10-21: no mock data — scene content is yours). This document is
the exact format the Rust fact table parses. Give me your scene in
this shape — or describe it in plain words and I will transcribe your
words into this format without adding, inventing, or embellishing
anything.

## Where it goes

File: `flutter_app/assets/daemon_config.json` (bundled app asset,
loaded at startup and passed to the Rust daemon as its config).
Restart the app after changing it. The file may also carry a
`"personas"` array (the persona roster) alongside `"facts"`.

## Shape

```json
{
  "facts": {
    "witnesses": {
      "<witness name>": [
        {
          "id": "<fact_id>",
          "text": "<the TRUE statement, exactly as held on record>",
          "lie_permitted": false,
          "lie_text": "<the FALSE statement given in play — only when lie_permitted is true>"
        }
      ]
    }
  }
}
```

A blank, fill-in copy is in `docs/scene_template.json` (documentation
only — the app never loads that file).

## Field rules (from the real parser, `rich_gang_ai_core/src/facts.rs`)

- `witnesses` — object mapping a witness name to the list of facts
  THAT witness knows. A witness can only ever testify to facts listed
  under their own name; asked about anything else, the app renders
  "I don't know anything about that." Names are shown in the UI as-is.
- `id` — required, unique per witness. Short snake_case reads best:
  the UI turns it into the question button ("Ask about side door"
  from `side_door`).
- `text` — required. The true statement on record, in the witness's
  voice. This is what the validator holds as truth.
- `lie_permitted` — required boolean. When `true` AND a `lie_text`
  is present, the witness states the lie in play.
- `lie_text` — optional (omit it, or set `null`, for truthful facts).
  Never shown in the facts list the UI fetches; it only surfaces as
  the witness's spoken statement. The truth in `text` is never
  mutated by play.

## How contradictions work

There is no contradiction engine and the app detects nothing for the
player. Design them yourself: give two witnesses facts about the same
event whose `text` values cannot both be true (typically the same
topic under different fact ids, one per witness), optionally with one
witness's version being a permitted lie. The player catches it by
collecting both statements and cross-referencing the transcript.

## Validation

The config is parsed by serde at daemon start. A malformed `facts`
table is logged loudly (`facts: invalid fact table in config`) and
the daemon loads an EMPTY table — it never falls back to invented
content. Before any scene ships in the asset, I will run it through
the real parser and the FFI tests and show you the result.

## Minimal structural example

See `docs/scene_template.json` — two witnesses, two facts each, one
permitted lie — with every content field left blank for you to fill.
