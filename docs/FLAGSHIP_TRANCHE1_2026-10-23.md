# FLAGSHIP TRANCHE 1 — 2026-10-23

Order: Richard — “Do it” / “Do it now.”
Scope: Flagship Program P0 production signing, the code-fixable first
P4 tranche, and P7 preparation documents. No publishing. No edits to
`docs/SALES_LISTING_DRAFT.md`.

This file is checkpointed as each work item completes so the record
survives interruption.

---

## Work item 1 — Freeze + verify

### Snapshot boundary

- Freeze run began: **2026-10-23 16:31:30 UTC**.
- Repository state: **not a Git repository** (`git status` unavailable;
  no VCS snapshot exists).
- Staged native library:
  `flutter_app/android/app/src/main/jniLibs/arm64-v8a/libdaemon.so`
  - SHA-256: `a8c4158137348a0304858b885978212fa4eda65cc27807889872fa8947ab5d76`
  - Size: 2,745,488 bytes.
- Selected pre-edit file hashes recorded at the snapshot boundary:
  - `flutter_app/android/app/build.gradle.kts` —
    `558694af3abcaa6eb138b4cd3be3b30a201bbb520a7dc7c044a8d85c1c8242`
  - `flutter_app/android/app/src/main/AndroidManifest.xml` —
    `bb4a0f57971c7dac0edb6ed0aa00621ea09fca44baa8f31b1bf6daecd8754871`
  - `flutter_app/lib/views/the_room.dart` —
    `fdfde74fafbd04ab01368a900621d37d7ce3d7bc06b6648c343467fe04d848af`
  - `flutter_app/lib/views/tier10_hud.dart` —
    `5f3a58b8c053baafce7bbbc5fc7ae1817988d008572ff9b99c571f3be3a01e2a`
  - `flutter_app/lib/main.dart` —
    `f0d483e5a81b14f9f5911c7cce47057ba48afab93c88079e572825912d1e71bf`
  - `flutter_app/lib/core/native_bridge.dart` —
    `0b45ea2798ccf34437d0be6452f7a5881e8a103aa8993428b3f9beadfda7c86a`
  - `flutter_app/assets/characters.json` —
    `1d239bff4b878f851e21bfe79d39f931a910ea2a3df0507bfc54ad24d58ca973`
  - `flutter_app/assets/daemon_config.json` —
    `b0c21338e28c37e636df87d2c14b667ec94ab88db73c8ede77af98e5712ccbb3`
  - `flutter_app/pubspec.yaml` —
    `2c0e5d6baaf4b43e3b4b09f2e4a258f05e0cf5090e5d01c53f93fa7ee41c561b`

### Moving-tree finding during the freeze

The snapshot was **not clean**. A parallel Danny flagship-promotion
workstream modified roster/parser files at the freeze boundary:

- `flutter_app/assets/characters.json` — 16:30:53 UTC;
- `flutter_app/assets/daemon_config.json` — 16:30:59 UTC;
- `flutter_app/lib/core/character.dart` — 16:31:30 UTC.

Those files were therefore not edited by this tranche. The current
asset/parser state introduces Danny's new
`configured_voice_uncast` tier (portrait and baselines configured,
ElevenLabs voice honestly uncast), while two older roster tests
still require Danny to be `registry_only_unconfigured`.

### Verification on the snapshot (serialized)

| Command | Result |
|---|---|
| `cargo test` in `rich_gang_ai_core` | **PASS — 78 passed, 0 failed** |
| `flutter analyze` in `flutter_app` | **PASS — “No issues found!”** |
| `flutter test` in `flutter_app` | **FAIL — 41 passed, 2 failed** |
| `tools/release_gate.sh --suites` | **FAIL — only the Flutter-test leg failed; cargo 78 passed, analyze clean, structural gate checks PASS** |

The two Flutter failures were reproduced exactly on one immediate
re-run:

1. `roster_asset_test.dart`: configured characters expected length 9,
   actual length 10 after Danny's parallel promotion.
2. `tier10_system_controller_test.dart`: expansion entries expected
   `registry_only_unconfigured`; Danny's actual status is
   `configured_voice_uncast`.

**Disposition:** moving-tree / parallel-workstream mismatch, not a
defect introduced by this tranche and not silently absorbed here.
The owning Danny-promotion work must update its tests/docs to the
new tier truth, or revert the promotion consistently. This tranche
does not overwrite files changed inside the collision window.

**Work item 1 status: COMPLETE as a freeze + diagnosis; the frozen
candidate itself is RED on Flutter tests for the reason above.**

---

## Work item 2 — Production signing (P0 / F-01)

### Change made

- `flutter_app/android/app/build.gradle.kts`
  - Removed the template TODO and the release build's
    `signingConfig = signingConfigs.getByName("debug")`.
  - Release signing is now created only from real production
    material, read in priority order from:
    1. `flutter_app/android/keystore.properties` (local, git-ignored); or
    2. `RGAI_KEYSTORE_PATH`, `RGAI_KEYSTORE_PASSWORD`,
       `RGAI_KEY_ALIAS`, `RGAI_KEY_PASSWORD` environment variables.
  - If a task name requesting a release build is evaluated while
    the material is missing/incomplete (including a named keystore
    file that does not exist), the Gradle task graph is designed to
    throw:
    `signing_not_configured: Production release signing is not configured. Missing: …`
    with the missing fields named. There is no debug-key fallback.
  - Debug signing is untouched; no production keystore is required
    for debug builds.
- `flutter_app/android/.gitignore`
  - Added the explicit `keystore.properties` ignore entry (the file
    already ignored `key.properties`, `**/*.keystore`, `**/*.jks`).
- `docs/SIGNING.md` (new)
  - Richard-facing instructions: create the keystore himself with
    JDK `keytool`, keep it backed up under his own control, put
    passwords only in local `keystore.properties` or secret
    environment variables (never chat/docs/repo), and record only
    alias + certificate SHA-256 fingerprint in an approval package.
  - No keystore was created by the agent. No password was invented
    or handled.

### Verification and its limits

- No `flutter_app/android/keystore.properties` exists in this
  workspace, and no `RGAI_*` signing environment variables are set.
- `flutter analyze` after the change: **PASS — “No issues found!”**
- One Gradle release invocation was attempted:
  `cd flutter_app/android && ./gradlew :app:assembleRelease --offline`
  - Exit 1 before project configuration:
    **“Could not dispatch a message to the daemon.”**
  - This is the known `other_tcp` daemon block. It prevented Gradle
    from evaluating the new Kotlin DSL at all, so the
    `signing_not_configured` path is **verified by inspection, not
    by a Gradle run**. No standalone `kotlinc` exists in this VM;
    the Gradle-embedded Kotlin compiler cannot usefully compile a
    Gradle Kotlin DSL script outside Gradle's own script context.
  - Required re-proof after Richard sets `other_tcp` to Ask: with
    no keystore configured, a release build must stop with the
    explicit `signing_not_configured` message and produce no APK;
    with Richard's keystore configured, `apksigner verify
    --print-certs` must show the production certificate.

**Work item 2 status: COMPLETE as code + instructions, with the
Gradle-runtime proof explicitly blocked by `other_tcp`.**

---

## Work item 3 — P4 first tranche

Collision discipline applied: files changed by the parallel Danny
workstream inside the preceding 10 minutes were not edited. In
particular, `flutter_app/lib/main.dart`,
`flutter_app/lib/views/character_chat_view.dart`,
`flutter_app/lib/views/character_ui.dart`, and
`flutter_app/test/roster_asset_test.dart` were all moving during
this tranche.

### Done at code level

#### P4-04 — Production “Test thermal severe” control removed

- File: `flutter_app/lib/views/the_room.dart`.
- Before: Room Controls rendered an `OutlinedButton` labelled
  “Test thermal severe”; it called `_thermal(ThermalState.severe)`,
  dimmed the Room, and forced the frame-rate setting to 30.
- After: the button, the manual `_thermal` handler, and the Room's
  manual thermal-dim state are removed. The frame-rate chips now
  reflect only the user's actual frame-rate setting, and body
  opacity comes only from `PerformanceDirector`.
- Evidence: source search for `Test thermal severe`, `NEXUS`,
  `_thermalDim`, and `_thermal(` in `the_room.dart` is clean;
  new regression locks in
  `flutter_app/test/flagship_p4_test.dart` pass.
- Not yet phase-closing evidence: a release-build Room screenshot
  still requires P0/APK/device access.

#### P4-03 — Static NEXUS strip removed

- File: `flutter_app/lib/views/the_room.dart`.
- Before: a “NEXUS — SYSTEM NODES” section rendered ten static
  chips (`DAN•CORE`, `QUANTUM`, `MARKET`, `VIDEO•GEN`, `VOICE`,
  `SIGNAL`, `ORACLE`, `AGENT•Δ`, `NEXUS`) with no navigation or
  measured state.
- After: the whole strip is removed. No replacement labels or fake
  live states were invented.
- Evidence: the P4 source locks assert the section heading and the
  representative static chips are absent.

#### P4-11 — HUD stale-comment and count-label sub-fix (partial)

- File: `flutter_app/lib/views/tier10_hud.dart`.
- Before: the header said the HUD was “Deliberately NOT wired into
  the_room.dart's navigation,” contradicting The Room, which
  imports and mounts it; the count read “Active agents
  (registry),” which could be misread as a ready count.
- After: the header states the HUD is mounted by The Room below
  SETUP & HEALTH; the count reads “Registry entries (total, not a
  ready count).” The latency line already read “Latency (last
  measured)” and was left unchanged.
- **P4-11 remains open:** ready-vs-registry counts and route/
  provider sample context require Tier-10 controller plumbing and
  a real routed-call evidence run.

### P4 verification for this tranche

- New targeted test file:
  `flutter_app/test/flagship_p4_test.dart` — **2 passed, 0 failed**.
- `flutter analyze` immediately after the P4 edits:
  **PASS — “No issues found!”**
- Full-suite status is handled at close-out; the freeze already
  established two unrelated roster failures from the parallel Danny
  tier change.

### Skipped, with reasons

- **P4-01 (ready-vs-registry Room truth): SKIPPED this tranche.**
  Danny's status model changed during the freeze to the new
  `configured_voice_uncast` tier and the owning workstream was
  still editing parser/UI/test files. Rewriting cast sections now
  would either collide or risk calling Danny “ready” before the
  P3 promotion/exclusion disposition is settled.
- **Two-daemon-handles divergence (F-02): SKIPPED — not a small
  fix.** `main.dart` boots the Dart handle with the bundled asset
  config; `DreamCycleService` boots a second handle with `"{}"`.
  Merely copying the config into the Kotlin service could create
  two independent writers once file-backed store/ring paths are
  configured. P6 must first choose and prove one canonical
  owner/state model; `main.dart` was also edited by the parallel
  workstream at 16:36 UTC, inside the collision window.
- **P4-02, P4-05–P4-10, P4-12, P4-13: NOT attempted.** They are
  larger UI/state-model rework, depend on device screenshots,
  provider verification, Richard-approved dispositions (Stage,
  Interrogation), or files/flows under active parallel work.
  None was half-fixed.

**Work item 3 status: COMPLETE for the safe first tranche —
P4-03 and P4-04 code-complete, P4-11 partially advanced, the rest
explicitly skipped above.**

---

## Work item 4 — P7 preparation (docs only)

### `docs/SECURITY_REVIEW_2026-10-23.md`

Source-level attack/privacy review with file evidence. Headline
results:

- **SEC-01 (High, OPEN):** the LiveKit API secret is stored
  on-device and mints 6-hour HS256 tokens with publish/subscribe/
  data grants (`livekit_service.dart`). Disposition must be
  server-side minting or Crew Link exclusion. No production view
  calls `connect()` in the reviewed tree, so the risk activates
  when Crew Link is wired/marketed.
- **SEC-02 (Medium, OPEN):** `SecureKeys.clear*` deletion methods
  exist for every key, but Settings renders save-only fields — no
  in-app per-key removal path exists.
- **SEC-04 (Medium, OPEN):** no in-app privacy surface states the
  real provider data flows (cloud prompts include persona +
  recalled memories + search blocks; LiveAvatar receives a
  server-side persona Context; search queries go to DuckDuckGo /
  Wikipedia).
- **SEC-07 (Medium, OPEN):** Android backup behaviour is
  unspecified in code (no `allowBackup` / backup-rules artefacts),
  and no reset-my-data / remove-all-keys UI exists.
- **SEC-09 (Medium, OPEN):** the manifest carries Bluetooth,
  multicast, and Wi-Fi-state permissions with no shipped workflow
  named for them — first removal candidates at freeze.
- Also recorded: the FFI/JNI inventory and its in-process trust
  model (panic-wrapped, handle-validated, serde-built JSON), the
  shipped-config rule for future `store_path`/`ring_path`, the
  Ollama cleartext wall (loopback/localhost/emulator only — keep
  it that way), credential fields for consumer-less workflows
  (Deepgram, HeyGen video, LiveKit), and a clean source log sweep
  (no key/token/prompt logging found; device Logcat sweep still
  required).
- Fixed-in-tranche items credited there: production signing
  fail-fast (Work item 2) and the P4 test-surface removals.

### `docs/AGE_ASSURANCE_DESIGN_2026-10-23.md`

Vendor-neutral design, no signup, no code change:

- Documents today's gate precisely: a global SharedPreferences
  boolean (`age_21_confirmed`) set by tapping “I am 21+” — a
  confirmation notice, not verification.
- Maps enforcement surface-by-surface and names the gaps: chat
  checks after view creation and `_send` carries no explicit
  granted-state guard; `AvatarCallView` and `AvatarStageView`
  never call `AgeGate`; Roundtable's cast-time check is the
  strongest current pattern.
- Finds a wording defect: `character_agent.dart` calls the gate
  “verified” in the gated character's system prompt. It is not.
- Specifies the replacement: one `AgeAssurance` boundary with
  explicit states (unknown / required / pending / verified /
  denied / unavailable-fail-closed), character-level checks before
  exposure on every surface, a minimal stored record (state,
  timestamp, vendor id, opaque vendor reference — never a DOB or
  document), backup exclusion, and defined data-clear behaviour.
- Restates the P7 acceptance matrix and the exclusion
  alternative: no verified method → all 21+ characters excluded
  from flagship access/marketing, or the flagship does not ship.

**Work item 4 status: COMPLETE — both documents written; every
finding in them is OPEN unless explicitly marked fixed.**

---

## Work item 5 — Close-out

### Final verification (serialized, after all tranche edits)

By close-out, the parallel Danny workstream had completed its own
test updates, so the tree evaluated here is the settled tree, not
the contaminated freeze snapshot:

| Command | Result |
|---|---|
| `cargo test` | **PASS — 78 passed, 0 failed** |
| `flutter analyze` | **PASS — “No issues found!”** |
| `flutter test` | **PASS — 69 passed, 0 failed** (includes the Danny flagship tests added by the owning workstream and this tranche's 2 P4 locks) |
| `tools/release_gate.sh --suites` | **PASS — all checks green** (staged .so SHA `a8c41581…` unchanged, 30 exports, all 26 Dart lookups resolve, LOAD Align 0x4000, ABI 2 == 2) |

This closes Work item 1's freeze finding: the two roster failures
were the parallel workstream's mid-flight state, resolved by that
workstream's own completion — not by this tranche overwriting it.

### Status updates written

- `docs/FLAGSHIP_PROGRAM_2026-10-23.md`
  - §0 verdict item 4 and F-01: signing code fix recorded with its
    remaining Richard-side/proof-side limits.
  - P4-03 and P4-04: code-removal evidence recorded; items remain
    open only for device screenshot evidence.
  - P4-11: partial sub-fix recorded.
  - P7 status and phase map: **Not started → In progress** (formal
    review + age design exist; all findings open).
  - Blocker 3: pointer to `docs/SIGNING.md` added.
  - P0 remains **Blocked** (`other_tcp`); no other phase status
    changed, because no other phase gained closing evidence.
- `docs/BUILD_FINISH_2026-10-23.md`
  - The cargo divergence note now carries a **RESOLVED** addendum
    citing this tranche's cargo 78/78 and gate `--suites` PASS, and
    the “final cargo test green” blocker bullet is marked resolved.

### Files changed by this tranche

- `flutter_app/android/app/build.gradle.kts` — production signing.
- `flutter_app/android/.gitignore` — `keystore.properties` ignored.
- `flutter_app/lib/views/the_room.dart` — P4-03, P4-04 removals.
- `flutter_app/lib/views/tier10_hud.dart` — P4-11 sub-fix.
- `flutter_app/test/flagship_p4_test.dart` — new P4 regression locks.
- `docs/SIGNING.md` — new.
- `docs/SECURITY_REVIEW_2026-10-23.md` — new.
- `docs/AGE_ASSURANCE_DESIGN_2026-10-23.md` — new.
- `docs/FLAGSHIP_PROGRAM_2026-10-23.md` — status updates above.
- `docs/BUILD_FINISH_2026-10-23.md` — resolution addendum.
- `docs/FLAGSHIP_TRANCHE1_2026-10-23.md` — this record.

No Rust was changed by this tranche; the staged `.so` is untouched
and the release gate still passes against it. Nothing was
published. `docs/SALES_LISTING_DRAFT.md` was not edited.

### Remaining Richard-only blockers (unchanged in kind)

1. **`other_tcp` → Ask** in the Muse web app, then approve the
   Gradle daemon card. This still blocks: the APK build, the
   Gradle-runtime proof of the new signing fail-fast, and all
   device verification.
2. **A16 access** for P0/P1 sessions and its on-device prompts.
3. **Production keystore:** create/control it per
   `docs/SIGNING.md`; passwords only through the secure local flow.
4. **Provider scope + credentials** on the A16, incl. confirming
   the nine ElevenLabs voice IDs in his own account.
5. **LiveAvatar avatar IDs** for every marketed video-call
   character.
6. **Danny's voice:** pick a real ElevenLabs voice — or approve
   Danny as excluded from flagship marketing. (His code tier moved
   to `configured_voice_uncast` in the parallel workstream; the
   voice itself is still uncast.)
7. **21+ method:** choose a verified age-assurance provider/method
   — or approve excluding Crazy Kelly, Shawna, and Ruby.
8. **Final approval** of the exact P8 package.

**Tranche 1 status: COMPLETE.** The flagship itself is not done:
P0 remains blocked on Richard's `other_tcp` change, and P7's
findings are documented, not fixed.
