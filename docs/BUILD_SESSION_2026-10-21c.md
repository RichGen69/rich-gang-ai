# Build session addendum — 2026-10-21 (premium upgrades, main chat)

Richard: "Build the premium version with upgrades already wired in."
Acted on as: wire the remaining buildable build-order upgrades end-to-end.

## Wired this session (build order step 3 + step 7 flag)

### GBNF affect schema — now a real artifact, not just a validator
- `AFFECT_GRAMMAR_GBNF` in Rust `scene.rs`: a llama.cpp GBNF grammar
  for the AffectFrame JSON shape with INTENTS / BEATS / LIGHTS
  whitelists as literal alternatives. Layering documented in code:
  grammar enforces shape + vocabulary; finiteness/range and the
  beat-transition rule stay in `Scene::apply` (GBNF cannot express
  them). Hosted endpoints still have no verified grammar parameter —
  Dart providers keep throwing UnsupportedError there; the grammar
  serves the local-engine path and is the schema's canonical text.
- New additive FFI export `rga_affect_grammar` (ABI stays 2); the
  grammar is viewable in-app: Settings → "Affect grammar (GBNF)".

### Performance Director — wired end-to-end
- Rust `Scene` now retains the last ACCEPTED Delta; new additive
  export `rga_scene_state` returns a snapshot JSON (accepted count,
  last beat, escalated flag, last_delta or null).
- Dart `PerformanceDirector.direct()` (pure): maps the real Delta to
  Room presentation — light → base opacity (warm/bright 1.0, neutral
  0.95, cold 0.9, dim 0.7), shake after gating. Restraint outranks
  performance: kill switch → suspended at 0.6 static; quiet hours →
  dimmed to ≤0.6, shake 0; reduced motion → shake 0. No delta →
  baseline summary line, nothing invented.
- The Room reads the snapshot on entry, shows the director's factual
  summary line, and composes its opacity with the thermal dim (min).

### Crew Link flag (step 7)
- `AppSettings.crewLinkEnabled` (default false) + Settings toggle.
  Copy states plainly: paired devices only, no device paired, turning
  it on connects nothing yet. No transport built; none implied.

## Verification
- `cargo test` **21/21** (new: snapshot tracking, grammar coverage of
  every field + whitelist value).
- `libdaemon.so` rebuilt/restaged via `build_android.sh`:
  SHA-256 `68e2cdef717f3b475a822e9cbd5a594b405427ae5fb9d5b2ec82966aa06710e8`,
  17 `rga_*` exports (incl. `rga_scene_state`, `rga_affect_grammar`)
  + 4 JNI, LOAD Align 0x4000. (The script's step 4, the APK, still
  fails on the known `other_tcp` blocker — see below.)
- `flutter analyze`: no issues.

## NOT wired — and why (no-mock rule)
- **Step 2 (Rive seven-state + Kokoro voice casting):** the Rive Data
  Binding Flutter API shape is unverified and the Kokoro Flutter
  packages are immature (sherpa_onnx is the credible evaluation
  path). Coding against either now would be guessing; both stay
  gated until verified on a device or against real docs.
- **Step 6 (broadcast audio + images opt-in):** depends on the TTS
  path from step 2; not wired.
- **Step 4 (one interrogation scene):** still awaiting Richard's
  scene data for `assets/daemon_config.json`.
- **APK:** still blocked on `other_tcp` = Deny (Richard's one
  setting: Muse Settings → Permissions → Direct network protocols
  → Ask, then approve the card).
